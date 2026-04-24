---
description: Orchestrate BLoC → utopia_hooks migration for the current Flutter project
argument-hint: "[--budget N] [--screens a,b,c] [--status]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite
model: sonnet
---

# BLoC → utopia_hooks Migration Orchestrator

You are orchestrating a BLoC → utopia_hooks migration. You do NOT migrate code yourself — you coordinate four specialized sub-agents and commit their work per screen.

Raw arguments: `$ARGUMENTS`

## Step 1 — Parse arguments

Parse from `$ARGUMENTS`:
- `--status` → status-only mode: run Inventory, print `MIGRATION.md`, stop. No changes.
- `--budget N` → cap migrated screens this session at N (counted post-commit, skipped don't count)
- `--screens a,b,c` → only consider listed screens (by filename stem), rest treated as skipped for this session

If no args → unlimited budget, all screens in scope.

## Step 1.5 — Verify Dart MCP server is configured

Migration agents (`foundation`, `screen`, `global-state`) and this orchestrator all prefer Dart MCP over bash for `dart_fix`, `dart_format`, `analyze_files`, and `pub`. If it's not configured, the whole flow silently falls back to bash — slower, no structured diagnostics, and output-hygiene / baseline-analyze become inconsistent across agents.

**Check once at startup:**

1. Probe for a Dart MCP tool (e.g. `analyze_files` or `pub`). If unavailable in this session → Dart MCP is not configured.
2. If missing → **stop and ask the user to set it up before continuing.** Do not proceed with bash fallback silently. Print the block below verbatim so the user has a copy-pasteable config:

   ---
   > **Dart MCP server is not configured.** This migration flow prefers Dart MCP for structured diagnostics and FVM-aware SDK resolution.
   >
   > **Add a `.mcp.json` at the repo root** (same dir as `pubspec.yaml`):
   >
   > If the project uses **FVM** (has `.fvmrc` or `.fvm/`):
   >
   > ```json
   > {
   >   "mcpServers": {
   >     "dart": {
   >       "type": "stdio",
   >       "command": "fvm",
   >       "args": ["dart", "mcp-server"]
   >     }
   >   }
   > }
   > ```
   >
   > Otherwise (system Dart SDK on PATH):
   >
   > ```json
   > {
   >   "mcpServers": {
   >     "dart": {
   >       "type": "stdio",
   >       "command": "dart",
   >       "args": ["mcp-server"],
   >       "env": {}
   >     }
   >   }
   > }
   > ```
   >
   > **Then restart the Claude Code session** — MCP servers are loaded only at session start; adding to `.mcp.json` mid-session has no effect. After restart, re-run `/utopia-hooks-migrate-bloc:migrate` with the same args. The orchestrator reads `MIGRATION.md` and resumes from where it stopped — no screens re-migrated.
   >
   > If you intentionally want bash-only, re-run with `--allow-bash-fallback` — expect brittler reviews.
   ---

   Detect FVM by checking for `.fvmrc` or a `.fvm/` directory in repo root before suggesting which variant.

3. Honour `--allow-bash-fallback` in `$ARGUMENTS` — warn once and proceed with bash.

## Step 2 — Load context

Read `plugins/utopia-hooks-migrate-bloc/skills/migrate-bloc-to-utopia-hooks/SKILL.md` so you know the target architecture and rules. Sub-agents will be told to load relevant references themselves.

## Step 3 — Run Inventory agent

Invoke via Agent tool:
- `subagent_type`: `utopia-hooks-migrate-bloc:inventory`
- Prompt: pass repo root (current working directory) and args from step 1. Tell it to read any existing `MIGRATION.md` to preserve the Skipped section.

Expected structured output:
```
done: [{screen, commit}]
remaining: [{screen, deps, complexity, files_expected}]
skipped: [{screen, reason}]
blocked: [{screen, reason}]
dependencies_to_migrate_first:
  - {cubit_class, cubit_path, target_state_name, target_state_path, target_hook_name, complexity, depends_on}
next_wave: [screen_ids]   # ready AFTER Phase A completes (max 3)
foundation_needed: bool
notes: [str]
```

The agent writes/overwrites `MIGRATION.md` in repo root (preserving Skipped).

If `--status` → print summary to user and stop.

## Step 4 — Capture `dart analyze` baseline

**Per utopia-hooks convention: prefer Dart MCP (`analyze_files`) over bash.** Fall back to `${CLAUDE_PLUGIN_ROOT}/../utopia-hooks/scripts/dart_analyze.sh` (or this plugin's equivalent if shipped) only when Dart MCP is unavailable in the session.

Why baseline: real codebases have pre-existing analyzer errors/warnings outside the migration's blast radius. Reviewer's exit gate must be **"zero NEW issues in touched files vs baseline"**, not "zero absolute issues" — the latter would fail every commit on a repo with unrelated pre-existing issues.

1. Run analyze on the whole repo once. With Dart MCP: `analyze_files` with no path filter, or the full repo root. With bash: `dart_analyze.sh` at repo root.
2. Store the structured result in-memory (per-file issue counts keyed by path, split by severity: error/warning/info) or in `.migration-baseline.json` in repo root. Git-ignore it if it's a file.
3. Hand the baseline to the Review agent on every invocation — reviewer compares delta, not absolute.

If the analyze command fails catastrophically (SDK not found, invalid pubspec) → stop orchestration, report. Migration cannot proceed without a working analyzer.

If baseline already has errors in files the migration will touch → note in `MIGRATION.md` notes section ("baseline: N pre-existing errors in files-in-scope; review enforces zero NEW only"). Migration proceeds.

## Step 5 — Foundation (if needed)

If `foundation_needed: true`:
- Invoke `utopia-hooks-migrate-bloc:foundation` agent
- Agent returns a diff (pubspec + `_providers.dart` + `useInjected` bridge + root widget wiring)
- Review diff cheaply (sanity check — does it touch only expected files?)
- Apply diff (Edit/Write yourself)
- Commit: `setup: utopia_hooks foundation`
- Re-run Inventory to refresh state.

## Step 6 — Phase A: migrate global state dependencies (wave-based parallel, one commit each)

Inventory returns `dependencies_to_migrate_first` plus a pre-computed `phase_a_waves` (topological layering on `depends_on`, capped at 3 per wave) AND a `blocked_globals` list (direct blocks + transitive cascade from inventory's Step 6b/7). Global states within a wave have file-disjoint migration work and can run in parallel; commits remain per-state for bisect hygiene.

Budget-aware but loose here: **Phase A commits do NOT consume `--budget`.** Budget only counts screen commits (Phase B). Global states are preparatory — if user asks for `--screens item_screen`, they implicitly want all its deps migrated regardless of how many there are.

If `phase_a_waves` is missing (older inventory output), compute it yourself: `wave_0` = items with `depends_on ⊆ already_migrated`; `wave_N` = items whose `depends_on ⊆ (already_migrated ∪ items in waves < N)`; cap each wave at 3. If `blocked_globals` is missing, assume empty.

### Blocked set — the orchestration-wide cascade

Maintain one accumulating set for the whole run: `blocked = {state_name → {reason, blocked_by}}`. Seed it from `inventory.blocked_globals`. Add to it on each Phase A double-fail. Every subsequent decision (which wave items to skip, which screens to pull into `next_wave`) consults this set.

**When to add to `blocked`:**
1. At startup: copy every entry in `inventory.blocked_globals` in.
2. During Phase A: when a wave item double-fails review, add `{state: runtime_blocked, reason: "<review fail reason>", blocked_by: null}`.
3. Immediately after (1) or (2), compute the transitive closure: for every un-processed global whose `depends_on` intersects `blocked`, add it with `{reason: null, blocked_by: <nearest ancestor>}`. Use `dependencies_to_migrate_first` (and later waves' entries) as the dependency graph.

**Up-front reporting:** if step 1 produces a non-empty set, print to user before spawning any agents:
`"Phase A: N globals blocked up-front (M direct + K cascaded via: <chain>). They and their dependent screens will be skipped this run."`

### Why orchestrator owns `_providers.dart`

The only shared file across a wave is `_providers.dart` (every global-state migration registers an entry). To keep wave agents truly file-disjoint, the orchestrator invokes them with `provider_registration: orchestrator` — each agent writes its state file + `@Deprecated`-annotates its old Cubit, and returns a `provider_entry` string instead of editing `_providers.dart`. The orchestrator applies entries serially, one per commit, so each commit's `_providers.dart` diff contains exactly one new registration.

### Wave loop

```
for each wave in phase_a_waves:
  0. Filter wave: drop any item whose state_name is in `blocked`. If a previous wave's
     failure cascaded into this wave's items, they're now blocked — skip them.
     If the filtered wave is empty → continue to next wave.

  1. Verify scope: every remaining item's `depends_on` is already migrated (sanity check
     against inventory ordering). If violated → abort with error; inventory is the bug.

  2. PARALLEL migration — one message, one Agent call per wave item:
     Invoke utopia-hooks-migrate-bloc:global-state for each item with:
       - cubit_path, cubit_class
       - target_state_name, target_state_path, target_hook_name
       - providers_path (for context — agent does NOT edit this file)
       - provider_registration: orchestrator   # agent skips _providers.dart, returns provider_entry
     Each agent returns:
       - files_touched: new state file (created) + old Cubit file (annotated). NOT _providers.dart.
       - self_report.provider_entry: exact string to append under the _providers map
       - status, complexity, pattern_families, etc.

  3. SERIAL commit loop — for each item in filtered-wave order:
     a. If that item's agent returned status ≠ success → handle per "Failure handling" below.
        Note: the specific error statuses (scope_exceeded, dep_not_ready, needs_refactor,
        other_error) all become blocks — the orchestration does NOT stop.
     b. Apply its provider_entry to _providers.dart via Edit (Read _providers.dart once per wave,
        Edit once per item). Run dart_format on _providers.dart after the edit
        (dart_fix not needed — it's a single-line insertion).
     c. Invoke utopia-hooks-migrate-bloc:review
        Prompt: files_touched = [state_file, old_cubit_file, _providers.dart],
                proposed_commit_message, scope hint "global-state migration".
        Fresh context — do NOT paste the global-state agent's reasoning.
     d. Decide:
        - pass → refresh MIGRATION.md (step e below), commit
          "migrate: <target_state_name> (global, parallel to <cubit_class>)".
        - fail first time → re-invoke global-state agent with fix_list AND provider_registration:
          orchestrator. Agent rewrites state file / Cubit annotation; if fix_list references
          _providers.dart, agent returns a corrected provider_entry — orchestrator replaces the
          previously-applied entry (Edit) before re-review.
        - fail twice → mark as runtime-blocked; do NOT stop orchestration. See "Failure handling".
     e. Refresh MIGRATION.md (before committing):
        - Invoke utopia-hooks-migrate-bloc:inventory (read-only, fast).
          It re-scans code and regenerates MIGRATION.md with the just-migrated state
          flipped from "[ ] XState" to "[x] XState (was XCubit)".
        - Stage MIGRATION.md alongside the migration files.
        - The commit therefore includes: state file + _providers.dart entry (one line) + @Deprecated
          annotation on old Cubit + MIGRATION.md refresh.

  4. Before proceeding to the next wave: all items in the current wave must be resolved
     (committed OR added to `blocked`). No overlap between waves.
```

### Failure handling — mark blocked, cascade, continue

Phase A failures never stop orchestration. Instead:

**Agent-returned error status** (`scope_exceeded`, `dep_not_ready`, `needs_refactor`, `other_error`):
- Roll back any partial writes the agent made for this item (state file if created; Cubit annotation reversal).
- Add to `blocked`: `{state: <this_item>, reason: "<agent_status>: <message>", blocked_by: null}`.
- Recompute transitive closure: every un-processed global whose `depends_on` includes this item gets added to `blocked` with `blocked_by: <this_item>`. Same for the screen cascade (Phase B will re-check).
- Continue with the next wave item (or next wave).

**Review double-fail:**
- Roll back this item's state file + Cubit annotation + the `_providers.dart` entry the orchestrator applied (Edit to remove the line).
- Add to `blocked` the same way as above (reason: `"review double-fail: <last fix_list summary>"`).
- Cascade, then continue.

**Special case — `dep_not_ready` pointing at another wave item:** likely an inventory ordering bug (same-wave items shouldn't depend on each other by construction). Add the pointed-to dep to `blocked` with reason `"inventory ordering bug — re-run inventory"`, cascade from there, continue with the rest. Surface loudly in the final report so the user re-runs inventory.

**Rollback scope for a runtime-blocked item:** ONLY the files in that item's agent `files_touched` + its `_providers.dart` line. Never touch successfully-committed siblings.

After Phase A: inventory already re-ran after each successful commit in step 3e. Orchestrator uses the last inventory output + its in-memory `blocked` set for Phase B work_list without a separate re-run here.

### File-disjoint check for the parallel migration batch

Sanity-verify before spawning wave agents: the N items' `target_state_path`s must be distinct, `cubit_path`s must be distinct, and none of them equals `_providers.dart` (they shouldn't — agents don't touch it in orchestrator mode). If any overlap, serialize those items into separate waves.

## Step 7 — Phase B: migrate screens (wave-based, parallel-capable)

Before building `work_list`, filter by the orchestration-wide `blocked` set accumulated during Phase A:

- Drop every screen whose deps include any state in `blocked` (direct or cascaded).
- Record each dropped screen with `reason: "depends on blocked global <X>"` (nearest blocker) — it surfaces in the final report and the next inventory run will also mark it.

```
blocked_dep_names = keys(blocked)           # from Phase A
phase_b_candidates = next_wave_from_fresh_inventory
  .filter(s -> s.deps disjoint-from blocked_dep_names)

cascaded_screens = next_wave_from_fresh_inventory
  .filter(s -> not disjoint-from blocked_dep_names)
  .map(s -> {screen: s, blocked_by: <nearest in s.deps ∩ blocked_dep_names>})

work_list = filter(phase_b_candidates, --screens arg)
budget_remaining = --budget or ∞

while work_list not empty and budget_remaining > 0:
  batch = first up to 3 items from work_list (file-disjoint — verify)

  for each screen in batch (parallel Agent calls in one message):
    1. Invoke utopia-hooks-migrate-bloc:screen
       Prompt includes:
         - screen_path
         - complexity class
         - decomposition plan (if Complex — pull from inventory)
         - screen_local_cubits_to_migrate (from inventory — Cubits that are consumed ONLY by this screen; the screen agent migrates them as screen-local, not global)
         - allowed_file_list (screen + view + screen_state + sub-hook state files + screen-local cubit files — NOT global states or _providers)
         - baseline_analyze (from Step 4 — for review agent to use)
       Agent returns diff description. ALL global deps it reads should already be migrated
       (via `useProvided<XState>()`). If a global dep is not migrated, agent returns
       `missing_dep` — orchestrator error.

    2. Apply diff.

    3. Invoke utopia-hooks-migrate-bloc:review
       Prompt: files_touched + proposed_commit_message + optional extra_info_for_review.
       Fresh context.

    4. Decide:
       - pass → refresh MIGRATION.md (step 4a below), then commit "migrate: <screen_stem>" (all screen-scope files + MIGRATION.md in one commit)
       - fail first time → retry screen agent with fix_list
       - fail twice → rollback screen-scope files only (not global state commits from Phase A),
                       log to skipped with reason, continue batch
       - budget_remaining -= 1 on successful commit only

    4a. Refresh MIGRATION.md (before committing):
        - Invoke utopia-hooks-migrate-bloc:inventory (read-only, fast).
          It re-scans code and regenerates MIGRATION.md with the just-migrated screen
          moved from "Remaining" to "Done".
        - Stage MIGRATION.md alongside the screen-scope files.
        - The commit includes: all files_touched by the screen agent + MIGRATION.md refresh.

  # The last inventory run (from step 4a of the final screen in the batch) already
  # has fresh work_list input. No separate inter-batch inventory needed.
```

**File-disjoint check for parallel screen batch**: `allowed_file_list`s must not overlap. After Phase A, `_providers.dart` should be stable for screens — they read via `useProvided`, don't re-register. But if a screen has its own screen-local state that uses `_providers`, serialize.

## Step 7.5 — Post-migration refactor sweep (per screen, after successful commit)

After each Phase B screen commit, check the review agent's `post_migration_hits` field. This is **advisory output from review agent's §M (post-migration refactor sweep) and §L3 (shape conformance)** — migration is already correct and committed; this is a follow-up optimization pass that hoists cross-cutting coordination to aggregators, collapses aggregator pass-throughs to getter-delegates, and pushes per-item state to widget-level hooks. Based on the `rnd-*`-style refactor pattern; driven by `references/post-migration-refactor-checklist.md`.

**Skip if:** `post_migration_hits` is empty, or screen is Simple.

**Flow** (runs immediately after the `migrate: <screen_stem>` commit):

```
if review.post_migration_hits not empty:
  1. Invoke utopia-hooks-migrate-bloc:screen again for the same screen
     Prompt includes:
       - screen_path (same)
       - allowed_file_list (same as original + any aggregator/sibling files named in hits)
       - retry_feedback:
           mode: post_migration_refactor
           hits: <copy of review.post_migration_hits>
       - authoritative_reference: references/post-migration-refactor-checklist.md
     The agent reads the checklist, applies the fix pattern for each hit, and produces
     ONE diff per anti-pattern (not one mega-diff). Per the checklist's "Why per-anti-pattern
     commits" section — each hoist is a one-purpose change, so smoke-testable and bisect-able.

  2. Apply each diff separately, committing between them:
     - Commit message format: refactor(<screen_stem>): <antipattern_id> — <short description>
       Examples:
         refactor(comments): A3 — scroll sub-hook → primitives; scrollToComment to aggregator
         refactor(comments): D1 — aggregator pass-throughs → getter-delegates
         refactor(comments): B1 — GlobalKey ownership to widget-level hook
     - Do NOT refresh MIGRATION.md (migration state didn't change — just refactored shape).

  3. Re-invoke review for each refactor commit — must still pass A–K.
     - If any refactor commit fails A–K → revert that commit only, log in warnings, continue with next hit.
     - If re-review reports NEW post_migration_hits — those are second-order findings.
       Do NOT loop. Log in warnings, move on. One sweep per screen per orchestration run.

  4. budget_remaining is NOT decremented by refactor commits. They are cleanup on an already-
     counted migration.
```

**Hard rules for the sweep:**

- **Never roll back the original `migrate:` commit.** If the refactor sweep fails, the screen is still migrated — the refactor just didn't land. Log and continue.
- **One refactor commit per anti-pattern.** Do NOT batch multiple anti-patterns into one commit. Granularity is the safety net for smoke-testing (per the checklist's commit-granularity rationale).
- **No new migration work.** The screen agent in `mode: post_migration_refactor` may only touch files in the sweep scope — no new widgets, no new states. If a hit requires creating a new widget hook (B1/B2 archetypes), that's in scope; creating a new sub-hook is not.
- **Soft failures are OK.** If 3 of 5 hits fix cleanly and 2 fail, that's acceptable — take the wins, log the losses.

**Why this is a separate step, not part of review/commit:**

- Review agent is read-only and fresh-context. Keeps the correctness gate sharp. It spots bloat, but the orchestrator is what acts on it.
- Refactor commits must be **separate from migration commits** — otherwise you can't bisect a migration regression vs a refactor regression.
- This mirrors the `rnd-*` pattern from the reference codebase: first make it work, then make it lean, in distinct commits.

## Step 8 — Final report

Print to user:
- Phase A: N global states migrated (list)
- Phase A blocked: list of globals in the orchestration-wide `blocked` set, split into:
  - Direct blocks: `<StateName> — <reason>` (inventory-detected side-effects, runtime review double-fails, etc.)
  - Cascaded blocks: `<StateName> — blocked_by <NearestAncestor>`
- Phase B: M screens migrated (list)
- Phase B cascaded-blocked: screens dropped from work_list because their deps include any blocked global — `<screen> — blocked_by <StateName>`
- Skipped: list with reasons (user opt-out via MIGRATION.md)
- Blocked (pre-existing): list with reasons + suggested action (from inventory's screen blocked category)
- Remaining screens: count
- Next suggested command: e.g. `/utopia-hooks-migrate-bloc:migrate --budget 5` or `--status`. If any blocks are present, suggest how to unblock (e.g. "Fix AdminCubit.close() I/O, then re-run; AdminDashboardState and 3 screens will automatically unblock.").

## Non-negotiables

- **NEVER commit without review pass** — even if the code looks fine to you
- **NEVER skip the hook gate** — `screen_gate.sh` runs automatically on Edit/Write, respect its output
- **Commit granularity**:
  - Phase A: one commit per global state. Format: `migrate: <StateName> (global, parallel to <CubitClass>)`. **MUST include MIGRATION.md refresh.**
  - Phase B: one commit per screen scope (screen + view + screen-local state + sub-hook state files + subtree widgets). Format: `migrate: <screen_stem>`. **MUST include MIGRATION.md refresh.**
- **MIGRATION.md is authoritative** — every successful migration commit must include a refreshed `MIGRATION.md`. If the diff does not contain `MIGRATION.md`, the commit is malformed — block it and invoke inventory.
- **Phase A failures cascade, not STOP** — a double-failed or inventory-blocked global is added to the run-wide `blocked` set. Every un-processed global whose `depends_on` includes it is transitively added too. Every screen whose deps include any blocked global is dropped from Phase B's work_list with `blocked_by: <X>`. Orchestration keeps running on the un-blocked remainder.
- **Phase B failure is local** — a failed screen is rolled back (its files only) and skipped; other screens continue.
- **Atomic rollback on double-fail** — only roll back files in the failed scope's `allowed_file_list`. Never touch global-state commits from Phase A.
- **Preserve the Skipped section of `MIGRATION.md`** — user-owned, do not regenerate
- **Do not delete old Cubits during this session.** `@Deprecated` only. Old Cubits are removed in a final cleanup commit (manual or a separate command, not part of this one).

## What to show the user during the run

Use TodoWrite to track progress. One todo per Phase A global-state migration + one todo per Phase B screen. Transition through: pending → in_progress (migration agent) → in_progress (review) → completed (commit). Failed/skipped marked completed with a note.

Short text updates at meaningful moments:
- "Running inventory..."
- "Foundation needed — creating `_providers.dart` and `useInjected` bridge."
- "Phase A: 14 global states across 5 waves. Wave 1: FeedState, AnalyticsState, CartState (parallel)."
- "Pre-blocked: AdminState (dispose I/O) → cascades to AdminDashboardState + 3 screens."
- "Wave 1 migration done — applying providers and reviewing each."
- "AuthState: review passed, committing."
- "SettingsState: review double-failed → blocked (cascades to 2 downstream globals, 4 screens)."
- "Phase A done. Re-inventory, moving to Phase B."
- "Phase B: migrating item_screen (complex, decomposing into Comments + Poll sub-hooks)."
- "item_screen: review failed, retrying with feedback."

Do NOT narrate every file edit.
