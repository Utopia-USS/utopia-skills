# ship bundle

Command-only bundle. Installs `.claude/commands/<prefix>-ship.md` and nothing
else - orchestrating commits and ticketing-sync is the whole content; there
is no body of background knowledge to extract into a skill.

## When to open

Open this bundle when the team has external ticketing with required
commit-message conventions:

- **Linear**, **`<ticketing-tool>`**, or **Jira** (or equivalent) is the source of
  truth for work items, and
- Commits or branches carry a ticket reference in a required format (e.g.
  `<TICKET-ID> | description` or `feat(LIN-1234): description` or
  `branch-name = TICKET-slug`).

**Not auto-inspectable.** Phase 0.4 must surface this with a user prompt:

> *"Do you use a ticketing tool with commit-message or branch-naming
> conventions? Which one - Linear / `<ticketing-tool>` / Jira / other?"*

If the answer is no (commits are free-form and the team doesn't sync state
back to a ticket tracker), reject this bundle.

## Reversal - when **not** to open

- No external ticketing tool, or the team doesn't reference tickets in
  commits.
- The team uses GitHub Issues only and the linkage is via PR description,
  not commit message - handle in PR templates, not in this command.
- Commits are batched and shipped via release automation that doesn't read
  ticket IDs.

## What this bundle ships

- `command/<prefix>-ship.md` (ships as [`command/REPO-ship.md`](command/REPO-ship.md)) - commit-breakdown + ticketing-sync + branch
  + push orchestration. Read-only Phase 1 → plan-only Phase 4 → execute
  Phase 5 with a mandatory user-approval STOP between plan and execute.

No skill - there is no general body of knowledge here. The command body
*is* the workflow.

## Substitution checklist

- `<prefix>` - repo command prefix (e.g. `aap`).
- `<ticketing-tool>` - Linear / Jira / ClickUp-class tools. Appears in:
  - frontmatter `allowed-tools` (`mcp__<ticketing-tool>` stays a placeholder until substitution, e.g. `mcp__linear`)
  - one-time setup snippet (the MCP add command)
  - "Custom Task IDs" / ticket-ID format note
  - all Phase 3-5 references to "`<ticketing-tool>`"
- Ticket-ID format example - `<TICKET-ID>` is `<ticketing-tool>`'s custom-task-ID format.
  Swap for the team's format:
  - **Linear**: `LIN-1234` (or whatever the team prefix is - `ENG-`,
    `WEB-`, …).
  - **Jira**: `PROJ-1234`.
  - **`<ticketing-tool>`**: `<TICKET-ID>` or whatever custom-task-ID prefix the workspace
    uses.
- Status names in Phase 5 - "testing" is the source-repo column. Swap for the
  team's "in review", "ready for QA", or similar.
- Commit-message format - `<TICKET> | <desc>` is the source-repo. Some teams use
  `[TICKET] desc`, `feat(TICKET): desc`, or `TICKET: desc`. Match the
  team's `git log`.

## Production precedent

repo-B is the only production repo currently shipping this bundle; its
ticketing tool drives the commit format described above.

## Load-bearing pieces - keep when adapting

- **Mandatory STOP between Phase 4 (plan) and Phase 5 (execute).** Never
  commit or push without explicit user approval. The user must say "ok" /
  "go" / "ship" to proceed.
- **One umbrella, N subtasks, ONE branch.** All commits on this run go to
  one branch. Subtasks live as children of the umbrella in the ticketing
  tool, not separate branches.
- **Small fixes get batched.** Trivial typos / lints / formatting / 1-3
  line drive-by fixes do NOT get their own ticket - fold into the nearest
  meaningful chunk.
- **No `git add -A` and no `git add .`** - always stage exact files per
  chunk.
- **Never skip hooks** (`--no-verify`) and never `--amend`.
- **Honor `.claude/never-ship.local.txt`** - per-developer gitignored file
  listing paths/globs to exclude from staging.
- **Base detection is dynamic.** Don't assume `staging` / `main` is the
  base. Detect from upstream tracking - the user may be on a long-lived
  feature branch far ahead of trunk.
- **Branch rule:** if the command *created* the umbrella ticket → create a
  new branch (`<TICKET>-<slug>`) from current HEAD. If the umbrella
  already existed (user passed an ID or matched one) → stay on the
  current branch.

## Strip-the-banner reminder

The command file ships with a `<!-- BLUEPRINT -->` banner. Remove it once
substitution is complete.
