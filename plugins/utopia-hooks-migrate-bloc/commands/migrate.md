---
description: Orchestrate BLoC → utopia_hooks migration for the current Flutter project
argument-hint: "[--budget N] [--screens a,b,c] [--status] [--finalize]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, ToolSearch, TaskCreate, TaskUpdate
---

# BLoC → utopia_hooks Migration Orchestrator

You are orchestrating a BLoC → utopia_hooks migration. You do NOT migrate code yourself - you coordinate five specialized sub-agents and commit their work per screen.

Raw arguments: `$ARGUMENTS`

## Step 0 - Reconcile the working tree (crash recovery)

A previous run may have died mid-wave (session limit, kill), leaving half-applied work. The inventory agent classifies by what exists on disk, so un-reconciled leftovers would be treated as migrated code and downstream work would build on unreviewed files.

1. Run `git status --porcelain` and filter to migration surfaces: `lib/state/`, `lib/**/state/`, `lib/_providers*.dart`, `MIGRATION.md`, `pubspec.yaml`.
2. Clean → proceed to Step 1.
3. Dirty → reconcile BEFORE anything else:
   - An uncommitted new state file + matching `@Deprecated` Cubit annotation looks like a completed-but-uncommitted Phase A item → run `migrate-review` on those files; pass → commit it normally (salvaged wave item), fail → remove the orphan files / revert the annotation.
   - Anything you cannot confidently classify → STOP and ask the user, showing the file list. Never revert blindly - the user may have their own uncommitted work in the same tree.
4. Note the reconciliation outcome in the final report.

## Step 1 - Parse arguments

Parse from `$ARGUMENTS`:
- `--status` → status-only mode: run `migrate-inventory`, print `MIGRATION.md`, stop. No changes.
- `--budget N` → cap migrated screens this session at N (counted post-commit, skipped don't count)
- `--screens a,b,c` → only consider listed screens (by filename stem), rest treated as skipped for this session
- `--finalize` → endgame cleanup mode: no new migrations; remove the BLoC layer entirely (see Step 9). Requires all screens migrated.

If no args → unlimited budget, all screens in scope.

## Step 1.5 - Verify Dart MCP server is configured

Migration agents (`migrate-foundation`, `migrate-screen`, `migrate-global-state`) and this orchestrator all prefer Dart MCP over bash for `dart_fix`, `dart_format`, `analyze_files`, and `pub`. If it's not configured, the whole flow silently falls back to bash - slower, no structured diagnostics, and output-hygiene / baseline-analyze become inconsistent across agents.

**Check once at startup:**

1. Probe for a Dart MCP tool. **MCP tools may be deferred in current harnesses** - absence from the visible tool list proves nothing. Call `ToolSearch` with query `+dart analyze` (or `select:mcp__dart__analyze_files`); only if ToolSearch finds no Dart MCP match is the server actually not configured. Do not declare it missing without a ToolSearch probe.
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
   > **Then restart the Claude Code session** - MCP servers are loaded only at session start; adding to `.mcp.json` mid-session has no effect. After restart, re-run `/utopia-hooks-migrate-bloc:migrate` with the same args. The orchestrator reads `MIGRATION.md` and resumes from where it stopped - no screens re-migrated.
   >
   > If you intentionally want bash-only, re-run with `--allow-bash-fallback` - expect brittler reviews.
   ---

   Detect FVM by checking for `.fvmrc` or a `.fvm/` directory in repo root before suggesting which variant.

3. Honour `--allow-bash-fallback` in `$ARGUMENTS` - warn once and proceed with bash.

## Step 2 - Load context

Read `${CLAUDE_PLUGIN_ROOT}/skills/migrate-bloc-to-utopia-hooks/SKILL.md` so you know the target architecture and rules. Sub-agents will be told to load relevant references themselves.

## Step 3 - Run the migrate-inventory agent

Invoke via Agent tool:
- `subagent_type`: `utopia-hooks-migrate-bloc:migrate-inventory`
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

## Step 4 - Capture `dart analyze` baseline

**Per utopia-hooks convention: prefer Dart MCP (`analyze_files`) over bash.** Fall back to this plugin's bundled `${CLAUDE_PLUGIN_ROOT}/scripts/dart_analyze.sh` only when Dart MCP is unavailable in the session.

Why baseline: real codebases have pre-existing analyzer errors/warnings outside the migration's blast radius. Reviewer's exit gate must be **"zero NEW issues in touched files vs baseline"**, not "zero absolute issues" - the latter would fail every commit on a repo with unrelated pre-existing issues.

1. Run analyze on the whole repo once. With Dart MCP: `analyze_files` with no path filter, or the full repo root. With bash: `dart_analyze.sh` at repo root.
2. Store the structured result in-memory (per-file issue counts keyed by path, split by severity: error/warning/info) or in `.migration-baseline.json` in repo root. Git-ignore it if it's a file.
3. Hand the baseline to the `migrate-review` agent on every invocation - reviewer compares delta, not absolute.

If the analyze command fails catastrophically (SDK not found, invalid pubspec) → stop orchestration, report. Migration cannot proceed without a working analyzer.

If baseline already has errors in files the migration will touch → note in `MIGRATION.md` notes section ("baseline: N pre-existing errors in files-in-scope; review enforces zero NEW only"). Migration proceeds.

### Step 4b - Behavioral baseline (`flutter test`)

Static greps and the analyzer cannot catch "compiles but nothing happens" bugs (unwired triggers, `shouldCompute` never true). If the repo has a `test/` directory, run the suite once (`flutter test`) and record failing test names - that is the behavioral baseline. The per-batch gate in Step 6/7 is **"zero NEW test failures"**, mirroring the analyzer delta.

- Suite doesn't run at all (broken harness, missing goldens) → note it, skip the behavioral gate, surface loudly in the final report.
- No `test/` dir → skip; the final report MUST say "no behavioral gate - walk the §4g manual smoke checklist per screen".

## Step 5 - Foundation (if needed)

If `foundation_needed: true`:
- Invoke `utopia-hooks-migrate-bloc:migrate-foundation` agent
- Agent returns a diff (pubspec + `_providers.dart` + `useInjected` bridge + root widget wiring)
- Review diff cheaply (sanity check - does it touch only expected files?)
- Apply diff (Edit/Write yourself)
- Commit: `setup: utopia_hooks foundation`
- Re-run `migrate-inventory` to refresh state.

## Step 6 - Phase A: migrate global state dependencies (wave-based parallel, one commit each)

The `migrate-inventory` agent returns `dependencies_to_migrate_first` plus a pre-computed `phase_a_waves` (topological layering on `depends_on`, capped at 3 per wave) AND a `blocked_globals` list (direct blocks + transitive cascade from its Step 6b/7). Global states within a wave have file-disjoint migration work and can run in parallel; commits remain per-state for bisect hygiene.

Budget-aware but loose here: **Phase A commits do NOT consume `--budget`.** Budget only counts screen commits (Phase B). Global states are preparatory - if user asks for `--screens item_screen`, they implicitly want all its deps migrated regardless of how many there are.

If `phase_a_waves` is missing (older `migrate-inventory` output), compute it yourself: `wave_0` = items with `depends_on ⊆ already_migrated`; `wave_N` = items whose `depends_on ⊆ (already_migrated ∪ items in waves < N)`; cap each wave at 3. If `blocked_globals` is missing, assume empty.

### Blocked set - the orchestration-wide cascade

Maintain one accumulating set for the whole run: `blocked = {state_name → {reason, blocked_by}}`. Seed it from the `migrate-inventory` agent's `blocked_globals`. Add to it on each Phase A double-fail. Every subsequent decision (which wave items to skip, which screens to pull into `next_wave`) consults this set.

**When to add to `blocked`:**
1. At startup: copy every entry in `migrate-inventory`'s `blocked_globals` in.
2. During Phase A: when a wave item double-fails review, add `{state: runtime_blocked, reason: "<review fail reason>", blocked_by: null}`.
3. Immediately after (1) or (2), compute the transitive closure: for every un-processed global whose `depends_on` intersects `blocked`, add it with `{reason: null, blocked_by: <nearest ancestor>}`. Use `dependencies_to_migrate_first` (and later waves' entries) as the dependency graph.

**Up-front reporting:** if step 1 produces a non-empty set, print to user before spawning any agents:
`"Phase A: N globals blocked up-front (M direct + K cascaded via: <chain>). They and their dependent screens will be skipped this run."`

### Provider registration is DEFERRED to Phase B

Phase A does NOT register new states in `_providers.dart`. Rationale: `HookProviderContainer` builds every registered provider **eagerly at app startup**, so registering in Phase A would put the new hook AND the old Cubit live simultaneously for the entire migration window - double fetches, double stream subscriptions (e.g. two `FirebaseAuth.authStateChanges` listeners), double persistence writes. Instead, the entry lands in the commit of the FIRST migrated screen that consumes the state (Step 7, sub-step 2a). Until then the state file is inert: compiled and reviewed, but never executed.

Wave agents are still invoked with `provider_registration: orchestrator` - each agent writes its state file + `@Deprecated`-annotates its old Cubit and returns a `provider_entry` string. The orchestrator does NOT apply it in Phase A. Entries are deterministic (`XState: useXState,` + an import of the state file), so nothing needs persisting - Phase B re-derives them from `target_state_name` / `target_hook_name` / `target_state_path`.

### Wave loop

```
for each wave in phase_a_waves:
  0. Filter wave: drop any item whose state_name is in `blocked`. If a previous wave's
     failure cascaded into this wave's items, they're now blocked - skip them.
     If the filtered wave is empty → continue to next wave.

  1. Verify scope: every remaining item's `depends_on` is already migrated (sanity check
     against migrate-inventory ordering). If violated → abort with error; migrate-inventory is the bug.

  2. PARALLEL migration - one message, one Agent call per wave item:
     Invoke utopia-hooks-migrate-bloc:migrate-global-state for each item with:
       - cubit_path, cubit_class
       - target_state_name, target_state_path, target_hook_name
       - providers_path (for context - agent does NOT edit this file)
       - provider_registration: orchestrator   # agent skips _providers.dart, returns provider_entry
     Each agent returns:
       - files_touched: new state file (created) + old Cubit file (annotated). NOT _providers.dart.
       - self_report.provider_entry: exact string to append under the _providers map
       - status, complexity, pattern_families, etc.

  3. SERIAL commit loop - for each item in filtered-wave order:
     a. If that item's agent returned status ≠ success → handle per "Failure handling" below.
        Note: the error statuses (scope_exceeded, dep_not_ready, needs_refactor, other_error)
        all become blocks; `needs_service_extraction` gets its own sub-flow (below) - the
        orchestration does NOT stop either way.
     b. Invoke utopia-hooks-migrate-bloc:migrate-review
        Prompt: files_touched = [state_file, old_cubit_file],
                proposed_commit_message, scope hint "global-state migration, Phase A -
                the state file must NOT be registered in _providers.dart yet".
        Fresh context - do NOT paste the migrate-global-state agent's reasoning.
     c. Decide:
        - pass → update MIGRATION.md (step d below), commit
          "migrate: <target_state_name> (global, parallel to <cubit_class>)".
        - fail first time → re-invoke migrate-global-state with fix_list AND provider_registration:
          orchestrator. Agent rewrites state file / Cubit annotation.
        - fail twice → mark as runtime-blocked; do NOT stop orchestration. See "Failure handling".
     d. Update MIGRATION.md deterministically (before committing):
        - Edit MIGRATION.md YOURSELF: flip "[ ] XState (was XCubit)" to
          "[x] XState (was XCubit) - pending registration" and bump the Progress line.
          Do NOT re-run migrate-inventory per commit - a full repo re-scan per commit is
          wasted budget. Full re-scans happen at phase boundaries and session start only.
        - Stage MIGRATION.md alongside the migration files.
        - The commit therefore includes: state file + @Deprecated annotation on old Cubit
          + MIGRATION.md update. NOT `_providers.dart` (registration is deferred to Phase B).

     Service-extraction sub-flow (`status: needs_service_extraction`): the Cubit contains
     domain logic that lives in no service (agent returned a `proposed_service` sketch).
     Do NOT block - duplicating that logic into the hook is forbidden, and blocking wastes
     a migratable state. Instead:
       s1. Re-invoke migrate-global-state with `mode: extract_service` + the proposed_service
           sketch. The agent creates the service file and rewires the OLD Cubit to delegate
           to it - behavior-preserving, no hook yet.
       s2. Review (scope hint: "service extraction - logic must move verbatim, old Cubit must
           delegate, zero behavior change") → commit "refactor: extract <XService> from
           <XCubitClass>". Does not consume --budget.
       s3. Re-invoke migrate-global-state normally (mode: migrate_state) - the hook consumes
           the same service. Continue at (b).
       s1/s2 double-fail → NOW mark blocked as usual (and cascade).

  4. Before proceeding to the next wave: all items in the current wave must be resolved
     (committed OR added to `blocked`). No overlap between waves.
```

### Failure handling - mark blocked, cascade, continue

Phase A failures never stop orchestration. Instead:

**Agent-returned error status** (`scope_exceeded`, `dep_not_ready`, `needs_refactor`, `other_error`):
- Roll back any partial writes the agent made for this item (state file if created; Cubit annotation reversal).
- Add to `blocked`: `{state: <this_item>, reason: "<agent_status>: <message>", blocked_by: null}`.
- Recompute transitive closure: every un-processed global whose `depends_on` includes this item gets added to `blocked` with `blocked_by: <this_item>`. Same for the screen cascade (Phase B will re-check).
- Continue with the next wave item (or next wave).

**Review double-fail:**
- Roll back this item's state file + Cubit annotation. An already-committed service-extraction commit (sub-flow s2) stays - it is a behavior-preserving standalone improvement.
- Add to `blocked` the same way as above (reason: `"review double-fail: <last fix_list summary>"`).
- Cascade, then continue.

**Special case - `dep_not_ready` pointing at another wave item:** likely a `migrate-inventory` ordering bug (same-wave items shouldn't depend on each other by construction). Add the pointed-to dep to `blocked` with reason `"inventory ordering bug - re-run migrate-inventory"`, cascade from there, continue with the rest. Surface loudly in the final report so the user re-runs `migrate-inventory`.

**Rollback scope for a runtime-blocked item:** ONLY the files in that item's agent `files_touched`. Never touch successfully-committed siblings.

After Phase A: run `migrate-inventory` ONCE here (phase-boundary re-scan). It regenerates MIGRATION.md from ground truth and provides the fresh screen work_list for Phase B. This is the only inventory run between the initial one and the final report.

### File-disjoint check for the parallel migration batch

Sanity-verify before spawning wave agents: the N items' `target_state_path`s must be distinct, `cubit_path`s must be distinct, and none of them equals `_providers.dart` (they shouldn't - agents don't touch it in orchestrator mode). If any overlap, serialize those items into separate waves.

## Step 7 - Phase B: migrate screens (wave-based, parallel-capable)

Before building `work_list`, filter by the orchestration-wide `blocked` set accumulated during Phase A:

- Drop every screen whose deps include any state in `blocked` (direct or cascaded).
- Record each dropped screen with `reason: "depends on blocked global <X>"` (nearest blocker) - it surfaces in the final report and the next `migrate-inventory` run will also mark it.

```
blocked_dep_names = keys(blocked)           # from Phase A
phase_b_candidates = next_wave_from_fresh_inventory
  .filter(s -> s.deps disjoint-from blocked_dep_names)

cascaded_screens = next_wave_from_fresh_inventory
  .filter(s -> not disjoint-from blocked_dep_names)
  .map(s -> {screen: s, blocked_by: <nearest in s.deps ∩ blocked_dep_names>})

work_list = filter(phase_b_candidates, --screens arg)
work_list = sort(work_list, key = (simple before complex, alphabetical tiebreak))
  # ENFORCE the ordering here, deterministically - do NOT trust the inventory's list order.
  # Quick wins must land first; a stalled god-screen must never starve the whole run.
  # (Field lesson: a run that put the hardest complex screen first died with 0 screens done
  # while three ready simple screens waited.)
budget_remaining = --budget or ∞

while work_list not empty and budget_remaining > 0:
  batch = first up to 3 items from work_list (file-disjoint - verify)

  for each screen in batch (parallel Agent calls in one message):
    1. Invoke utopia-hooks-migrate-bloc:migrate-screen
       Prompt includes:
         - screen_path
         - complexity class
         - decomposition plan (if Complex - pull from migrate-inventory)
         - screen_local_cubits_to_migrate (from migrate-inventory - Cubits that are consumed ONLY by this screen; migrate-screen handles them as screen-local, not global)
         - allowed_file_list (screen + view + screen_state + sub-hook state files + screen-local cubit files - NOT global states or _providers)
         - baseline_analyze (from Step 4 - for migrate-review to use)
       Agent returns diff description. ALL global deps it reads should already be migrated
       (via `useProvided<XState>()`). If a global dep is not migrated, agent returns
       `missing_dep` - orchestrator error.

    2. Apply diff.

    2a. Register the screen's global deps in `_providers.dart` (orchestrator-owned, serial):
        for every global dep of this screen - INCLUDING the transitive `depends_on` closure
        (a hook global that calls `useProvided<OtherState>()` needs OtherState registered
        too) - that is not yet in `_providers.dart`, append `XState: useXState,` plus the
        import, in dependency order (dependencies above dependents). Run dart_format.
        VERIFY after the edit (a real run once wired `TipsState: useStoriesState`):
        every entry's Type and hook function must share the same name stem
        (`XState:` ↔ `useXState`), and the diff vs git HEAD must add exactly the intended
        N lines + imports. Mismatch → fix before review.

    3. Invoke utopia-hooks-migrate-bloc:migrate-review
       Prompt: files_touched (+ `_providers.dart` if 2a changed it) + proposed_commit_message
       + optional extra_info_for_review.
       Fresh context.

    4. Decide:
       - pass → refresh MIGRATION.md (step 4a below), then commit "migrate: <screen_stem>" (all screen-scope files + MIGRATION.md in one commit)
       - fail first time → retry migrate-screen with fix_list
       - fail twice → rollback screen-scope files only (not global state commits from Phase A),
                       log to skipped with reason, continue batch
       - budget_remaining -= 1 on successful commit only

    4a. Update MIGRATION.md deterministically (before committing):
        - Edit MIGRATION.md YOURSELF: move the screen from "Remaining" to "Done", flip any
          globals registered in 2a from "pending registration" to "registered", bump the
          Progress line. No migrate-inventory run per commit.
        - Stage MIGRATION.md alongside the screen-scope files.
        - The commit includes: all files_touched by migrate-screen + `_providers.dart`
          (if 2a registered anything) + MIGRATION.md update.

  # Behavioral gate after each batch (if a Step 4b baseline exists): run `flutter test`.
  # Zero NEW failures vs baseline → continue. New failures → identify the offending commit
  # (test per commit of this batch), revert it, log the screen as blocked with the failing
  # test names, continue with the next batch.
```

### Staged god-screen sub-flow (`status: staged_plan_proposed`)

For screens whose scope exceeds one safe invocation (screen-local Cubit > ~600 LoC, manifest > ~12 files, or estimated rewrite > ~2000 LoC), the migrate-screen agent returns `staged_plan: [stages]` instead of a diff. Execute the stages sequentially, each as its own commit, as a batch of ONE (no parallel siblings):

- Stages 1..N-1 (`stage: prep`): one sub-hook state-file group per stage, zero screen rewiring. Review each with Phase A-style scope (new files compile, idiomatic; being unused-yet is OK). Commit `migrate-prep: <screen_stem> - <stage_name>`. Not budget-counted.
- Stage N (`stage: final`): screen + view + widget-subtree rewiring consuming the prep files. Full exit-gate review. Commit `migrate: <screen_stem>`. Budget-counted.
- A prep-stage double-fail blocks the screen: roll back only the uncommitted stage (committed prep stages are inert additions and may stay), log to skipped with reason, continue.

**File-disjoint check for parallel screen batch**: `allowed_file_list`s must not overlap. Agents never touch `_providers.dart`; the orchestrator applies registrations serially at each screen's commit step (2a), so parallel agents stay disjoint even when their screens share deps - the later commit simply has fewer new entries to register.

## Step 7.5 - Post-migration refactor sweep (per screen, after successful commit)

After each Phase B screen commit, check the `migrate-review` agent's `post_migration_hits` field. This is **advisory output from `migrate-review`'s §M (post-migration refactor sweep) and §L3 (shape conformance)** - migration is already correct and committed; this is a follow-up optimization pass that hoists cross-cutting coordination to aggregators, collapses aggregator pass-throughs to getter-delegates, and pushes per-item state to widget-level hooks. Based on the `rnd-*`-style refactor pattern; driven by `references/post-migration-refactor-checklist.md`.

**Skip if:** `post_migration_hits` is empty, or screen is Simple.

**Flow** (runs immediately after the `migrate: <screen_stem>` commit):

```
if review_result.post_migration_hits not empty:
  1. Invoke utopia-hooks-migrate-bloc:migrate-screen again for the same screen
     Prompt includes:
       - screen_path (same)
       - allowed_file_list (same as original + any aggregator/sibling files named in hits)
       - retry_feedback:
           mode: post_migration_refactor
           hits: <copy of review_result.post_migration_hits>
       - authoritative_reference: references/post-migration-refactor-checklist.md
     The agent reads the checklist, applies the fix pattern for each hit, and produces
     ONE diff per anti-pattern (not one mega-diff). Per the checklist's "Why per-anti-pattern
     commits" section - each hoist is a one-purpose change, so smoke-testable and bisect-able.

  2. Apply each diff separately, committing between them:
     - Commit message format: refactor(<screen_stem>): <antipattern_id> - <short description>
       Examples:
         refactor(comments): A3 - scroll sub-hook → primitives; scrollToComment to aggregator
         refactor(comments): D1 - aggregator pass-throughs → getter-delegates
         refactor(comments): B1 - GlobalKey ownership to widget-level hook
     - Do NOT refresh MIGRATION.md (migration state didn't change - just refactored shape).

  3. Re-invoke migrate-review for each refactor commit - must still pass A–K.
     - If any refactor commit fails A–K → revert that commit only, log in warnings, continue with next hit.
     - If re-review reports NEW post_migration_hits - those are second-order findings.
       Do NOT loop. Log in warnings, move on. One sweep per screen per orchestration run.

  4. budget_remaining is NOT decremented by refactor commits. They are cleanup on an already-
     counted migration.
```

**Hard rules for the sweep:**

- **Never roll back the original `migrate:` commit.** If the refactor sweep fails, the screen is still migrated - the refactor just didn't land. Log and continue.
- **One refactor commit per anti-pattern.** Do NOT batch multiple anti-patterns into one commit. Granularity is the safety net for smoke-testing (per the checklist's commit-granularity rationale).
- **No new migration work.** The `migrate-screen` agent in `mode: post_migration_refactor` may only touch files in the sweep scope - no new widgets, no new states. If a hit requires creating a new widget hook (B1/B2 archetypes), that's in scope; creating a new sub-hook is not.
- **Soft failures are OK.** If 3 of 5 hits fix cleanly and 2 fail, that's acceptable - take the wins, log the losses.

**Why this is a separate step, not part of review/commit:**

- The `migrate-review` agent is read-only and fresh-context. Keeps the correctness gate sharp. It spots bloat, but the orchestrator is what acts on it.
- Refactor commits must be **separate from migration commits** - otherwise you can't bisect a migration regression vs a refactor regression.
- This mirrors the `rnd-*` pattern from the reference codebase: first make it work, then make it lean, in distinct commits.

## Step 8 - Final report

Print to user:
- Phase A: N global states migrated (list)
- Phase A blocked: list of globals in the orchestration-wide `blocked` set, split into:
  - Direct blocks: `<StateName> - <reason>` (side-effects detected by `migrate-inventory`, runtime review double-fails, etc.)
  - Cascaded blocks: `<StateName> - blocked_by <NearestAncestor>`
- Phase B: M screens migrated (list)
- Phase B cascaded-blocked: screens dropped from work_list because their deps include any blocked global - `<screen> - blocked_by <StateName>`
- Skipped: list with reasons (user opt-out via MIGRATION.md)
- Blocked (pre-existing): list with reasons + suggested action (from `migrate-inventory`'s screen blocked category)
- Remaining screens: count
- Globals migrated but still **pending registration** (no migrated consumer yet) - expected mid-migration; they are inert until a consuming screen lands
- Service extractions performed (list of `refactor: extract <XService>` commits)
- Behavioral gate: `flutter test` outcome (new failures: none / list), or "no test suite - manual smoke test is the only behavioral check"
- Per migrated screen, print the §4g manual smoke checklist (screen-migration-flow.md): fresh entry renders, primary data loads, refresh/retry works, primary actions work end-to-end, navigation round-trip. The automated gates do NOT cover runtime behavior - the user should walk this before shipping.
- Working-tree reconciliation outcome from Step 0 (if anything was salvaged or reverted)
- Next suggested command: e.g. `/utopia-hooks-migrate-bloc:migrate --budget 5` or `--status`. If any blocks are present, suggest how to unblock (e.g. "Fix AdminCubit.close() I/O, then re-run; AdminDashboardState and 3 screens will automatically unblock.").

### Step 8b - Append the session journal entry

Migration runs span multiple sessions; the journal is what lets the next session resume with full context instead of re-deriving it. Append ONE entry to the `## Session journal` section of `MIGRATION.md` (create the section at the end of the file if missing - `migrate-inventory` preserves it verbatim, like Skipped):

```markdown
### <YYYY-MM-DD> - session N
- migrated: <Phase A states; Phase B screens with commit SHAs>
- blocked/skipped: <items + reasons, or "none">
- deviations/refactors: <intentional behavior-preserving refactors beyond plain migration, with rationale, or "none">
- skill/plugin issues hit: <anything where the skill guidance was wrong/missing - these feed plugin fixes, or "none">
- gates: analyze delta <ok/issues>, flutter test <ok/new failures/no suite>
- next: <the exact suggested next command + which screens are up>
```

Commit it as `chore(migration): session journal <YYYY-MM-DD>` (or fold it into the last migration commit of the session if one is being made anyway). Keep entries factual and short - the journal is a resume brief, not a diary.

## Step 9 - Finalize mode (`--finalize` only)

The endgame that removes the BLoC layer for good. Run only when `migrate-inventory` reports every screen done and every global migrated AND registered (a pending-registration global with zero consumers anywhere → ask the user: register-and-keep or delete as dead state).

If anything remains → print the remaining list and stop; no partial finalize.

Sequence (each its own commit, reviewed before committing as usual):

1. `cleanup: remove deprecated Cubits/Blocs` - delete every `@Deprecated` Cubit/Bloc plus their event/state/part files, remove their `BlocProvider`/`MultiBlocProvider` entries from the app root, delete `BlocObserver` wiring in `main.dart`.
2. `cleanup: remove BLoC packages` - drop `flutter_bloc`, `bloc`, `hydrated_bloc`, `bloc_concurrency` from pubspec (and `equatable` if nothing else uses it - grep first), then `flutter pub get`.
3. Full-repo verification: every grep from SKILL.md "Exit Gate" §3-6 run repo-wide must return zero; whole-repo `dart analyze` delta vs baseline shows no new issues; `flutter test` per the Step 4b gate.
4. Update MIGRATION.md: mark the migration COMPLETE, list the cleanup commits. Suggest deleting `MIGRATION.md` in a follow-up if the user wants.

Note: once the BLoC packages leave the pubspec, the `screen_gate.sh` hook auto-disarms (its mid-migration guard requires both package families present) - the general utopia-hooks conventions take over.

## Non-negotiables

- **NEVER commit without review pass** - even if the code looks fine to you
- **NEVER skip the hook gate** - `screen_gate.sh` runs automatically on Edit/Write, respect its output
- **Commit granularity**:
  - Phase A: one commit per global state. Format: `migrate: <StateName> (global, parallel to <CubitClass>)`. **MUST include MIGRATION.md refresh.**
  - Phase B: one commit per screen scope (screen + view + screen-local state + sub-hook state files + subtree widgets). Format: `migrate: <screen_stem>`. **MUST include MIGRATION.md refresh.**
- **MIGRATION.md is authoritative** - every successful migration commit must include an updated `MIGRATION.md` (deterministic orchestrator edit per commit; full `migrate-inventory` re-scans only at session start, phase boundaries, and `--status`). If the diff does not contain `MIGRATION.md`, the commit is malformed - fix before committing.
- **Provider registration only with a consumer** - `_providers.dart` gains an entry only in a screen commit that consumes the state (or is a dependency of one). A Phase A commit touching `_providers.dart` is malformed.
- **Behavioral gate** - when a Step 4b test baseline exists, no batch may introduce new test failures.
- **Phase A failures cascade, not STOP** - a global that double-failed, or that `migrate-inventory` flagged as blocked, is added to the run-wide `blocked` set. Every un-processed global whose `depends_on` includes it is transitively added too. Every screen whose deps include any blocked global is dropped from Phase B's work_list with `blocked_by: <X>`. Orchestration keeps running on the un-blocked remainder.
- **Phase B failure is local** - a failed screen is rolled back (its files only) and skipped; other screens continue.
- **Atomic rollback on double-fail** - only roll back files in the failed scope's `allowed_file_list`. Never touch global-state commits from Phase A.
- **Preserve the Skipped section of `MIGRATION.md`** - user-owned, do not regenerate
- **Do not delete old Cubits during a migration session.** `@Deprecated` only. Old Cubits are removed exclusively by `--finalize` (Step 9), after every screen is migrated.

## What to show the user during the run

Track progress with the harness task tools (`TaskCreate` / `TaskUpdate`; on older harnesses this tool is called `TodoWrite`). One task per Phase A global-state migration + one task per Phase B screen. Transition through: pending → in_progress (migration agent) → in_progress (review) → completed (commit). Failed/skipped marked completed with a note.

Short text updates at meaningful moments:
- "Running inventory..."
- "Foundation needed - creating `_providers.dart` and `useInjected` bridge."
- "Phase A: 14 global states across 5 waves. Wave 1: FeedState, AnalyticsState, CartState (parallel)."
- "Pre-blocked: AdminState (dispose I/O) → cascades to AdminDashboardState + 3 screens."
- "Wave 1 migration done - reviewing and committing each (provider registration deferred to Phase B)."
- "AuthState: review passed, committing."
- "SettingsState: review double-failed → blocked (cascades to 2 downstream globals, 4 screens)."
- "Phase A done. Re-inventory, moving to Phase B."
- "Phase B: migrating item_screen (complex, decomposing into Comments + Poll sub-hooks)."
- "item_screen: review failed, retrying with feedback."

Do NOT narrate every file edit.
