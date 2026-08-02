---
description: Break uncommitted changes into feature-based commits, sync <ticketing-tool> (umbrella + subtasks), branch by ticket, push.
argument-hint: "[optional context, e.g. '<TICKET-ID>' or 'migrate settings page']"
allowed-tools: Bash, Read, mcp__<ticketing-tool>
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Open only if Phase 0.4 confirmed ticketing-tool integration. Substitute <prefix> and <ticketing-tool> placeholders. Strip this banner after substitution. -->

# /<prefix>-ship - commit breakdown + <ticketing-tool> sync + branch + push

> **One-time setup (per dev):**
> ```
> claude mcp add -s user --transport http <ticketing-tool> <mcp-endpoint-url>
> ```
> Then run `/mcp` in any session and finish OAuth in the browser.
> Without this, Phase 3 onward fails - stop and tell the user to run setup.

User-provided context: `$ARGUMENTS`

## Hard rules

- **Never commit or push without explicit user approval** - there is a mandatory STOP between Phase 4 (plan) and Phase 5 (execute). User must say "ok" / "go" / "ship" to proceed.
- **Ticket-ID format** (e.g. `<TICKET-ID>` for <ticketing-tool> custom task IDs, `LIN-1234` for Linear, `PROJ-1234` for Jira). Workspace uses one format - use that in commit messages and branches, never the long internal ID.
- **Commit format:** `<TICKET> | <human description>` - match what `git log` already shows. Swap for `[TICKET] desc` or `feat(TICKET): desc` if that's the repo convention.
- **One umbrella, N subtasks, ONE branch.** All commits on this run go to one branch named after the umbrella ticket. Subtasks live as children of the umbrella in `<ticketing-tool>`, not separate branches.
- **Small fixes get batched.** Trivial typos, lints, formatting, or 1-3 line drive-by fixes do NOT get their own `<ticketing-tool>` task - fold them into the nearest meaningful chunk.
- **Branch rule:** If the agent *created* the umbrella ticket → create a new branch (`<TICKET>-<slug>`) from the current HEAD. If the umbrella already existed (user passed an ID or agent matched one) → stay on the current branch.
- **Don't assume `staging` / `main` is the base.** The user may be on a long-lived feature branch that's far ahead of trunk. The branch to ship FROM is whatever the user is currently on; the diff to ship is uncommitted changes (+ optionally already-on-branch commits ahead of *upstream*, not ahead of trunk). Detect the base in Phase 1 - never hardcode it.
- **No `git add -A` and no `git add .`** - always stage exact files per chunk.
- **Never skip hooks** (`--no-verify`) and never `--amend`.
- **Honor `.claude/never-ship.local.txt`.** Per-developer file (gitignored) listing paths/globs to never stage or commit. Read it in Phase 1, exclude matches from all chunks in Phase 2, and surface them in Phase 4 as a "Skipped (never-ship)" block. If the file doesn't exist, treat the list as empty.

## Phase 1 - Inspect (read-only)

Run these in parallel via Bash:
- `git status`
- `git diff` and (if anything staged) `git diff --staged`
- `git log -8 --oneline` - commit-style reference
- `git branch --show-current`
- `git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null` - does the current branch track a remote?
- Read `.claude/never-ship.local.txt` if present - parse non-comment, non-empty lines as path/glob exclusions.

**Base detection (do not skip):**
- If current branch is `staging` or `main` → base = current branch itself; any new branch will fork from HEAD.
- Else if upstream exists → base = `@{upstream}`. Use `git log --oneline @{upstream}..HEAD` to see commits already on this branch.
- Else (no upstream) → base = HEAD itself. Don't try to compute a diff against trunk - the user is on a feature branch that hasn't been pushed and may be far ahead of trunk in unrelated ways. Show only `git log -5 --oneline` for context.
- **Never** run `git log --oneline staging..HEAD` (or `main..HEAD`) blindly. It will dump dozens of irrelevant commits if the current branch is a long-lived feature branch.

If the working tree is clean and there are no commits ahead of base → tell user "nothing to ship" and stop.

## Phase 2 - Plan breakdown (no writes)

**First: filter out never-ship paths.** Drop any file matching a pattern from `.claude/never-ship.local.txt` from the working set. Keep the dropped list - it's surfaced in Phase 4.

Group remaining uncommitted + already-on-branch changes into logical, feature-based chunks. Each chunk should map to ONE meaningful unit of work worth its own `<ticketing-tool>` (sub)task.

Folding rules:
- Tiny fixes (1-3 line typos, lints, formatting) → fold into nearest big chunk.
- Generated files (`.pb.dart`, `.gr.dart`, `.freezed.dart`, `.g.dart`, generated TS, etc.) → fold into the chunk whose source generated them.
- Pure dependency bumps without behavior change → standalone commit allowed, no `<ticketing-tool>` task needed unless user asks.

Don't show the plan yet - Phase 4 prints the full integrated plan once umbrella is chosen.

## Phase 3 - Identify umbrella ticket

Use `$ARGUMENTS` first:
- Looks like a ticket ID (e.g. `<TICKET-ID>`, `LIN-1234`, `PROJ-1234`)? → fetch it via `<ticketing-tool>` MCP, confirm it exists, grab its title + parent context.
- Free-text description? → keep as a hint for searching/creating.
- Empty? → ask the user: *"What's this work about? Existing ticket ID, or describe so I can create an umbrella?"*

If no existing umbrella:
- Search `<ticketing-tool>` MCP for likely matches based on diff content + user hint.
- If a strong match exists → propose it, confirm with user.
- Otherwise → propose creating an umbrella task. Need: title, target list / project. Ask user which list / project (and remember the answer for this session). Title should describe the feature, not the diff.

The umbrella ticket determines:
- **Branch name:** `<TICKET>-<slug-of-title>` (e.g. `<TICKET-ID>-migrate-settings-page`).
- **Commit ticket prefix** (when a chunk doesn't have its own subtask, it falls back to the umbrella's ID).

## Phase 4 - Map chunks → `<ticketing-tool>` (PLAN ONLY)

For each significant chunk from Phase 2:
1. Search `<ticketing-tool>` MCP for an existing subtask under the umbrella, then by keyword across workspace if no match.
2. Match → mark **"update existing"** with that subtask's ticket ID.
3. No match → mark **"create subtask under umbrella"**. Pick a clear title.

Print the full plan in this exact shape:

```
Umbrella: <TICKET-ID> | Migrate settings page
Branch:   <TICKET-ID>-migrate-settings-page           (new - agent created umbrella)
                                                  (or: stay on <current> - umbrella already existed)
Base:     <current branch HEAD>                   (or: origin/staging only if user asked for clean cut)

Commits (in order):
  1. DEV-214 | UI: refactor SettingsPage to hooks                [update existing subtask]
     files: <repo-web-target>/lib/ui/settings/*.dart (5 files)
  2. DEV-NEW-A | CMS: wire CMS-fed page titles                   [will create subtask]
     files: <repo-web-target>/lib/services/cms_*.dart (2 files)
  3. (folded into #1) small typo fix in SettingsState
     files: <repo-web-target>/lib/ui/settings/state.dart (1 line)

Push:     origin/<TICKET-ID>-migrate-settings-page
<ticketing-tool>:  per (sub)task → comment with commit hash + branch URL; status → "<in-review-column-name>"; assign → me

Skipped (never-ship):
  - <repo-web-target>/ios/Runner.xcodeproj/project.pbxproj  (matched by .claude/never-ship.local.txt)
```

Omit the "Skipped (never-ship)" block if no files were filtered.

**STOP. Wait for user approval.**
- User says "ok" / "go" / "ship" / equivalent → continue to Phase 5.
- User edits plan → iterate, re-print, STOP again.
- Anything else → treat as discussion, do not write.

## Phase 5 - Execute (only after explicit approval)

Sequentially:

1. **Create missing `<ticketing-tool>` subtasks** via MCP under the umbrella. Capture their real ticket IDs (e.g. `DEV-NEW-A` placeholder → `DEV-457`). Replace placeholders in commit messages with real IDs.
2. **Branch:**
   - Umbrella ticket already existed (user-provided or matched) → stay on the current branch, no checkout.
   - Umbrella ticket was created by the agent → `git checkout -b <TICKET>-<slug>` from HEAD. Uncommitted changes carry over automatically. The new branch forks from whatever the user has been working on - never from trunk unless the user explicitly asked for a clean cut.
3. **For each chunk, in order:**
   - `git add <exact files for this chunk>` - list files explicitly, no globs unless they target only the chunk's files.
   - `git commit -m "<TICKET> | <desc>"` via HEREDOC. Append the standard `Co-Authored-By` trailer per repo convention.
   - If a pre-commit hook fails → fix the underlying issue, re-stage, NEW commit (never `--amend`).
4. `git push -u origin <branch>`.
5. **Update `<ticketing-tool>` via MCP** - for each (sub)task touched:
   - Post a comment: commit hash(es), short message, branch URL on GitHub, "pushed".
   - If the list has a status field and the task is in a "todo"-like or "in progress"-like status → move to the team's "in review" / "testing" / "ready for QA" column (code is shipped = ready for review).
   - Assign the current `<ticketing-tool>` user (me) to each created/updated (sub)task.
   - Do NOT change priorities or due dates.

If any step fails - STOP, report exactly what failed and what state the repo + `<ticketing-tool>` are in. Do not auto-recover.

## Phase 6 - Summary

Print:
- Branch name + GitHub URL (resolve via `gh repo view --json url -q .url` + branch).
- Each commit: short hash + subject line.
- `<ticketing-tool>` task URLs (umbrella + subtasks) as markdown links so the user can click through.
- One line: "Open a PR?" - offer but do not auto-create.
