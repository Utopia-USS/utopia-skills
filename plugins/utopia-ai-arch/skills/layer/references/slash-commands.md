---
title: Slash Commands - Three-Base Set and When to Extend
impact: HIGH
tags: slash-commands, orchestration, implement, audit, retry-cap, fresh-context, plan, team, design, ship
---

# Slash Commands - Three-Base Set and When to Extend

## What this is

Slash commands under `.claude/commands/` are **multi-step orchestrators**, not aliases to single agents. Every Utopia project ships exactly three base commands - `/<prefix>-implement`, `/<prefix>-audit`, `/<prefix>-audit-skills` - and adds project-specific commands only when a recurring workflow has genuine multi-step orchestration (plan-only, parallel fan-out, design pipeline, ticketing-coupled ship). A slash command wrapping a single agent invocation adds nothing - direct agent invocation auto-loads the agent via `description:` matching with subagent isolation for free.

> "Slash commands are added **only** when a workflow is multi-step orchestration (e.g. code↔review loop). Slash commands are not aliases to single agents - description matching auto-loads agents when relevance is clear." - blueprint README v1

> "Plain agent-aliases (`/<repo>-plan` → architect) are not added. Description matching auto-loads the architect when the user asks for a plan; the slash adds a layer for no benefit." - blueprint README v1

## When this applies

- Adding or editing a slash command (`.claude/commands/<prefix>-<verb>.md`)
- Debugging why a command's loop is escaping its scope (e.g. reviewer thrash, retry storm, scope creep on retry)
- Considering a new project-specific command (`/<prefix>-plan`, `/<prefix>-team`, `/<prefix>-design`, `/<prefix>-ship`, …)
- Removing a slash wrapper around a single agent
- Recording a slash-command decision in `claude-architecture.md` §"Slash commands"

## The three-base set

Every project has these. None are optional. Each lives in `.claude/commands/<prefix>-<verb>.md`.

### `/<prefix>-implement` - orchestrated code↔review loop

```yaml
---
description: Orchestrate a focused implementation with the <project> review loop (plan? → code ↔ review → exit). Does NOT commit.
argument-hint: "<scope or plan reference> [--plan-first] [--no-analyze-baseline]"
allowed-tools: Task, Read, Bash, Glob, Grep, Edit
model: inherit
---
```

**Loop shape** - per the blueprint template (`REPO-implement.md`):

1. **Plan (optional).** If the user passes `--plan-first` or the scope is a free-form description, delegate to `<prefix>-architect`. **Stop and wait** for user approval before step 2. (The STOP is a blueprint addition - the production implement commands proceed without one; plans are cheap to approve, redos aren't.)
2. **Baseline.** Capture analyzer / test baseline so the reviewer's exit gate is "zero NEW issues in `files_touched` vs baseline", not "zero absolute". Skip with `--no-analyze-baseline`.
3. **Implement.** Delegate to `<prefix>-maintainer` with the plan and the affected-skill list.
4. **Review.** Delegate the resulting diff to `<prefix>-reviewer` - **fresh context** (see below).
5. **Loop.** If any `BLOCKER` (or a new analyzer issue vs baseline), send the BLOCKERs back to the maintainer; repeat 3-5 until clean. **Retry cap = 2.** WARNs and NITs are advisory - surface to the user, don't retry on them.
6. **Hand off.** Do NOT commit. Summarise per-area changes, what was actually run, open NITs.

**Non-negotiables** - present verbatim in every production implement command:

> 1. **Never commit.** The loop ends with a hand-off to the user, who decides whether to run `/<prefix>-audit` and then commit.
> 2. **Never push.** Period.
> 3. **Reviewer runs on fresh context.** When invoking `<prefix>-reviewer`, pass only `files_touched` + `proposed_commit_message` + `baseline_analyze`. Withhold the maintainer's self-report, reasoning, and warnings - independence is the reviewer's only superpower.
> 4. **Retry cap: 2.** Maintainer runs, reviewer fails → maintainer retries once with the fix list → reviewer runs again. If it still fails, stop and hand the two failing reports to the user. Do NOT loop further.
> 5. **Scope stays constant across retries.** Retry is for fixing the maintainer's mistakes against the existing scope - not for expanding scope.
> - `production-repo-B/.claude/commands/<prefix>-implement.md:16-29` (replicated verbatim in `production-repo-C/.claude/commands/<prefix>-implement.md:16-29`)

### `/<prefix>-audit` - pre-commit gate

```yaml
---
description: Pre-commit audit of staged changes for commit-readiness. Read-only.
argument-hint: "[optional scope note, e.g. 'only <area> changes']"
allowed-tools: Task
model: inherit
---
```

**One-shot.** No loop. Launches `<prefix>-precommit-auditor` against `git diff --staged` (or an explicit refspec). Surfaces output verbatim. Does NOT auto-fix.

> "Use the Task tool to launch the `<repo>-precommit-auditor` subagent with the staged diff (`git diff --staged`). Surface its output verbatim. Do not auto-fix." - blueprint `REPO-audit.md`

This is what gates a commit. The reviewer in `/<prefix>-implement` checks correctness and conventions; the auditor here checks commit-readiness - staged-diff hygiene, debug artifacts, codegen consistency, doc drift. Disjoint scopes; do not collapse them.

> "**Do not modify the diff.** This command is read-only. The user fixes; we re-audit." - `production-repo-A/.claude/commands/<prefix>-audit.md:50-52`

### `/<prefix>-audit-skills` - drift scan

```yaml
---
description: Drift scan over `.claude/**/*.md` and `CLAUDE.md` - reports dead markdown links. Optionally proposes repairs.
argument-hint: "[fix] - propose repairs interactively; omit for report-only"
allowed-tools: Bash, Read, Edit
model: inherit
---
```

**Two modes:**

- **Report-only** (no `$ARGUMENTS`) - runs `<prefix>_skills_drift.sh --all`, prints stderr verbatim, exits.
- **Repair** (`$ARGUMENTS = fix`) - for each finding, propose a concrete repair (file + line + replacement) and **ASK before applying**. Do not batch-apply.

> "If `$ARGUMENTS` is `fix`: for each finding, propose a concrete repair (file + line + replacement) and ask before applying. Do not batch-apply." - blueprint `REPO-audit-skills.md`

The repair workflow has discipline: read the line, search for the likely new location (glob by basename; `git log --diff-filter=D` to disambiguate rename vs delete), propose the edit, apply only after user confirms. See [enforcement-hooks.md](enforcement-hooks.md) for the script's contract.

> "Never rewrite a reference silently - always show the diff first." - `production-repo-A/.claude/commands/<prefix>-audit-skills.md:33`

## The implement-loop in detail

```
   ┌──────────── /<prefix>-implement <scope> [--plan-first] [--no-analyze-baseline] ────────────┐
   │                                                                                            │
   │  Step 1 - Parse $ARGUMENTS                                                                 │
   │    scope (required), --plan-first (optional), --no-analyze-baseline (optional)             │
   │                                                                                            │
   │  Step 2 - Baseline analyze (unless --no-analyze-baseline)                                  │
   │    fvm dart analyze   OR   mcp__<prefix>-dart__analyze_files                               │
   │    store baseline_analyze keyed by path                                                    │
   │                                                                                            │
   │  Step 3 - Plan (only if --plan-first OR auto-trigger conditions)                           │
   │    auto-trigger: scope >1 package, schema/codegen surface, vague scope                     │
   │    → <prefix>-architect produces plan; STOP and wait for user approval                     │
   │                                                                                            │
   │  Step 4 - Maintainer attempt 1                                                             │
   │    Pass: scope + plan (if any) + "return self-report per Hand-off format"                  │
   │    Receive: status, files_touched, commit_message_draft, analyze, output_hygiene,          │
   │             warnings, out_of_scope_observations                                            │
   │    If status=needs_human → STOP (surface report, do NOT run reviewer)                      │
   │    If analyze non-clean+unjustified → bounce ONCE (does NOT consume a retry)               │
   │                                                                                            │
   │  Step 5 - Reviewer attempt 1 (FRESH CONTEXT - see "Reviewer-fresh-context" below)          │
   │    Pass ONLY: files_touched, proposed_commit_message, baseline_analyze                     │
   │    Receive: BLOCKER / WARN / NIT classified list                                           │
   │    Pass → Step 7                                                                           │
   │    Fail (any BLOCKER OR new analyzer issue vs baseline) → Step 6                           │
   │                                                                                            │
   │  Step 6 - Maintainer retry (attempt 2) - RETRY CAP                                         │
   │    Pass: same scope + plan + retry_feedback (reviewer BLOCKERS verbatim + new analyzer     │
   │          issues)                                                                           │
   │    Instruction: re-read current state, apply fixes, DO NOT widen scope                     │
   │    Re-invoke reviewer with same fresh-context discipline                                   │
   │    Pass → Step 7                                                                           │
   │    Fail → Step 7 with status=review_double_fail (no third round)                           │
   │                                                                                            │
   │  Step 7 - Exit / hand off                                                                  │
   │    Print: status, files_touched, commit_message_draft, reviewer verdict,                   │
   │           maintainer self-report (for user - NOT passed to reviewer)                       │
   │    Suggest: /<prefix>-audit then git commit (user-driven)                                  │
   └────────────────────────────────────────────────────────────────────────────────────────────┘
```

**What gets passed to the reviewer:**

| Field | To maintainer | To reviewer | To user |
|-------|---------------|-------------|---------|
| `scope` | yes | no (reviewer infers from commit msg) | yes |
| `plan` (from architect) | yes | no | yes |
| `files_touched` | (produces it) | yes | yes |
| `commit_message_draft` | (produces it) | yes | yes |
| `baseline_analyze` | (produced in Step 2) | yes | no (internal) |
| `analyze` (post-impl) | (produces it) | no - reviewer re-runs | yes |
| `output_hygiene` | (produces it) | **no - withheld** | yes |
| `warnings` | (produces it) | **no - withheld** | yes |
| `out_of_scope_observations` | (produces it) | **no - withheld** | yes |
| `retry_feedback` (Step 6 only) | yes | (no - already incorporated) | no |

The maintainer's self-report has two audiences: **the main orchestrator** (for hand-off to user) and **the maintainer itself on retry**. The reviewer is deliberately not in either.

## Reviewer-fresh-context discipline (load-bearing)

This is the single most-cited rule across production implement commands. It exists because the reviewer's value is independence - if the reviewer reads the maintainer's reasoning, the review collapses to approval-by-narration.

> "Reviewer runs on fresh context. When invoking `<prefix>-reviewer`, pass only `files_touched` + `proposed_commit_message` + `baseline_analyze`. Withhold the maintainer's self-report, reasoning, and warnings - **independence is the reviewer's only superpower**." - `production-repo-B/.claude/commands/<prefix>-implement.md:21-24`

The reviewer prompt (verbatim from `production-repo-B/.claude/commands/<prefix>-implement.md:213-231`, replicated in `production-repo-C/.claude/commands/<prefix>-implement.md:208-228`):

```
Review the following change set against the <prefix> + utopia-hooks skill
surface. You are independent - you do NOT see the maintainer's reasoning,
self-report, or warnings. Verify the diff from scratch.

files_touched:
<list>

proposed_commit_message:
<draft>

baseline_analyze (pre-change analyzer issue counts per file):
<map or "not captured - use zero-absolute gate">

Produce your classified report (BLOCKER / WARN / NIT) per your agent
definition. Exit gate for this orchestration: zero BLOCKERS in
files_touched, zero NEW analyzer issues in files_touched vs baseline.
WARNs and NITs are advisory.
```

Note what's absent: no scope description, no plan, no maintainer reasoning, no "the maintainer says this is fine because X". The reviewer reads the diff cold and makes its own call.

**The maintainer cooperates with this discipline.** From the maintainer-side rule (`production-repo-B/.claude/agents/<prefix>-maintainer.md:222-227`):

> "If you find yourself writing 'the reviewer should be OK with this because X', that X belongs in the code or in a warning, not as a hint to the reviewer. When `/<prefix>-implement` invokes the reviewer, it withholds this self-report on purpose - the reviewer must verify the diff from scratch, not from your reasoning."

## Retry-cap discipline

Retry is for fixing the maintainer's mistakes against the **existing scope**. It is NOT for expanding scope or accommodating "oh while I'm here let me also fix X".

> "Retry cap: 2. Maintainer runs, reviewer fails → maintainer retries once with the fix list → reviewer runs again. If it still fails, stop and hand the two failing reports to the user. Do NOT loop further." - `production-repo-B/.claude/commands/<prefix>-implement.md:25-27`

> "Scope stays constant across retries. Retry is for fixing the maintainer's mistakes against the existing scope - not for expanding scope." - `production-repo-B/.claude/commands/<prefix>-implement.md:28-30`

The retry prompt enforces this (`production-repo-B/.claude/commands/<prefix>-implement.md:191-209`):

```
The reviewer flagged issues with your previous implementation. Apply the
fixes and return a refreshed self-report. Do NOT widen scope beyond the
original request.

Original scope: <scope>

Reviewer BLOCKERS:
<blockers verbatim>

New analyzer issues vs baseline:
<list or "none">

Re-read the current state of files_touched, apply fixes, re-run output
hygiene (mcp__<prefix>-dart__dart_format on files_touched only - do NOT
run dart_fix, it bulldozes unrelated files and conflicts with the user's
WIP), re-run analyze via mcp__<prefix>-dart__analyze_files, and return a
fresh self-report.
```

**Why the cap is exactly 2** - if two careful attempts haven't resolved it, the scope is wrong or the rule is ambiguous, and a human needs to make the call. A third round is the orchestrator papering over a problem it can't fix.

> "Reviewer double-fails → hand off to user with both reports. Do NOT attempt a third round - if two careful attempts didn't resolve it, the scope is wrong or the rule is ambiguous, and that needs a human." - `production-repo-B/.claude/commands/<prefix>-implement.md:253-255`

**Analyzer bounce is not a retry.** If the maintainer reports a non-clean unjustified analyzer, bounce back once before involving the reviewer. This does not consume a retry - it's the maintainer not meeting its own hand-off contract.

## When to ADD project-specific commands

Default is **three**. Add a fourth only when a recurring workflow has genuine multi-step orchestration that the base three can't express. Each addition gets a §"Slash commands" entry in `claude-architecture.md` justifying its existence.

**Each command below has a ready-to-copy template** under [`../templates/workflow-templates/<bundle>/`](../templates/workflow-templates/). The bundle contains the command body + any paired skill + a per-bundle README explaining when to open and what to substitute. Don't write a project-specific command from scratch - copy the template, sed `<prefix>`, adjust the body for your team's specifics.

| Command | Template bundle | Paired with skill? | User-prompt required (Phase 0.4) |
|---|---|---|---|
| `/<prefix>-plan` | `workflow-templates/plan/` | No | "Routine cross-package PRs?" |
| `/<prefix>-team` | `workflow-templates/team/` | No | "PRs split into 2+ disjoint chunks routinely?" |
| `/<prefix>-design` | `workflow-templates/design/` | **Yes** - `<prefix>-design/SKILL.md` co-installed | "Design-tool integration (`<design-tool>` / Figma / handoff)?" |
| `/<prefix>-ship` | `workflow-templates/ship/` | No | "Ticketing tool with commit conventions?" |

### `/<prefix>-plan` - planning-only flow

**Add ONLY when** cross-cutting work spanning ≥3 ownership areas is **recurring** (not occasional). Otherwise `/<prefix>-implement --plan-first` produces the same plan with one extra flag.

**Precedent (added):** repo-A's `/<prefix>-plan` - cross-package planning involving E2E crypto + Supabase RLS + app UI + native FFI bindings is frequent enough that a dedicated "plan and stop" command pays for itself. Brings in `<prefix>-security-auditor` for threat-model passes routinely.

> "Delegate to `<prefix>-architect` for planning. … Bring in `<prefix>-security-auditor` for a threat-model pass if the change touches auth, crypto, key management, native crypto FFI, key-exchange primitives, or row-level security." - `production-repo-A/.claude/commands/<prefix>-plan.md:10-18`

**Rejected (not added):** repo-B and repo-C - single-area plan-then-implement is the dominant shape; `/<prefix>-implement --plan-first` covers it. The blueprint explicitly avoids `/plan` aliases (blueprint README v1).

**Reversal criterion.** Cross-cutting plan-only requests become routine; the orchestrator wants security / domain auditors to run pre-implementation; users keep typing `--plan-first` and forgetting the implement step.

### `/<prefix>-team` - multi-area orchestration with parallel fan-out

**Add when** the architect's task splits routinely yield ≥2 genuinely disjoint chunks where **wall-clock parallelism via batched maintainer Agent calls** matters. Otherwise sequential `/<prefix>-implement` is enough.

**Precedent (added):** repo-A's `/<prefix>-team` - Phone (Flutter) + crypto (Dart + FFI) + backend (Supabase RLS / Edge) are genuinely disjoint surfaces and large enough cross-cutting features are common.

> "**Parallelism.** If the architect's task split has ≥2 genuinely disjoint chunks AND wall-clock matters, batch multiple `Agent` calls to `<prefix>-maintainer` in a single assistant message so they run concurrently. One call per chunk, each with a scoped prompt naming its files and the relevant domain skills." - `production-repo-A/.claude/commands/<prefix>-team.md:32`

**Critical:** parallel fan-out happens via **batched calls to `<prefix>-maintainer`**, not via per-area maintainers. Per-area maintainers were tried in repo-A and reverted - see [agent-roster.md](agent-roster.md) "Do NOT add per-area maintainers".

> "Per-area maintainers (`<prefix>-area1-maintainer`, `<prefix>-area3-maintainer`, …) were tried and dropped - one cross-area `<prefix>-maintainer` covers the surface; if the architect splits into disjoint chunks, batch parallel `Agent` calls to that maintainer." - `production-repo-A/.claude/commands/<prefix>-team.md:23`

**Rejected (not added):** repo-B and repo-C - typical work is ticket-scoped and single-area. Parallelism payoff triggers on a small fraction of tasks; the orchestration cost of a second command is paid on every turn. `/<prefix>-implement` covers them.

### `/<prefix>-design` - design→code pipeline

**Add when** the team has a design tool integration that **materially affects the planning input**:

- `<design-tool>` MCP installed and used
- claude.design handoff bundles routinely produced
- Figma export pipeline feeding into Claude

Without such an integration, this command is empty - `/<prefix>-implement` with a "build this UI" scope works as well.

**Precedent (added):** repo-B's `/<prefix>-design` - `<design-tool>` is the team's design tool of record; handoff bundles come in via `.claude-handoff/`.

> "Acquire design from `$ARGUMENTS`: `paper` → use `<design-tool>` MCP tools; `handoff <path>` → read handoff bundle; (empty) → auto-detect: try `get_basic_info` (paper MCP available?), check for `.claude-handoff/` directory, ask user if neither found." - `production-repo-B/.claude/commands/<prefix>-design.md:29-35`

The acquisition step (Step 0) compiles a design brief that becomes the architect's input. The rest of the flow mirrors `/<prefix>-implement` - same non-negotiables, same retry cap, same fresh-context reviewer.

**Rejected (not added):** repo-A and repo-C - no design-tool integration in regular use; `/<prefix>-implement` covers UI work.

### `/<prefix>-ship` - commit/sync/push pipeline

**Add when** the team has an external ticketing integration (Linear / `<ticketing-tool>` / Jira) that demands strict commit-message format, branch naming, or per-commit status sync, AND the team values an interactive plan-before-execute breakdown.

**Precedent (added):** repo-B's `/<prefix>-ship` - `<ticketing-tool>` MCP integration with custom short task IDs (e.g. `ACME-12`), commit format `<TICKET> | <description>`, umbrella/subtask hierarchy.

> "**Custom Task IDs** (e.g. `<TICKET-ID>`). Workspace uses them - use that format in commit messages and branches, never the long internal ID. **Commit format:** `<TICKET> | <human description>`. **One umbrella, N subtasks, ONE branch.**" - `production-repo-B/.claude/commands/<prefix>-ship.md:21-23`

`/<prefix>-ship` has a mandatory STOP between Phase 4 (plan) and Phase 5 (execute) - the user must say "ok"/"go"/"ship" to proceed. It's the only base-or-extension command that **does** push to remote - because it's the user's deliberate commit-and-push gesture, not an orchestration side effect.

> "**Never commit or push without explicit user approval** - there is a mandatory STOP between Phase 4 (plan) and Phase 5 (execute). User must say 'ok' / 'go' / 'ship' to proceed." - `production-repo-B/.claude/commands/<prefix>-ship.md:20`

**Rejected (not added):** repo-A and repo-C - no external ticketing tool that demands strict commit format; `git commit` directly works.

## Slash-command file shape (canonical)

```markdown
---
description: <one-line WHEN to use - match precision against the user's likely phrasing>
argument-hint: "<optional args description>"
allowed-tools: <comma-separated minimum needed list>
model: inherit
---

# /<prefix>-<verb>

<One-paragraph framing - what this orchestrator coordinates, what it does NOT do.>

Raw arguments: `$ARGUMENTS`

## Non-negotiables (read these first)

- <invariant 1>
- <invariant 2>
- ...

## Step 1 - <name>
<body>

## Step 2 - <name>
<body>

...

## Done When
- <termination condition>

## Do not
- <explicit prohibitions>

## See also
- [/<prefix>-<other>](<other>.md) - <when to use that instead>
- [.claude/docs/claude-architecture.md](../docs/claude-architecture.md) - §<section> for rationale
```

**`allowed-tools` is minimum-needed, not broad.** `/<prefix>-audit` lists only `Task` because that's all it needs (one subagent invocation). `/<prefix>-implement` adds `Read, Bash, Glob, Grep, Edit` because the orchestrator may need to read files for context, parse arguments, run analyzer baselines. Listing more than needed erodes the determinism guarantee - the agent might wander into edits the command's intent doesn't justify.

## Anti-patterns

(Symptoms common across the whole layer - wrapper-around-single-agent, `dart_fix` bulldoze, reviewer leakage - live in [evolution-and-drift.md](evolution-and-drift.md) §R, §G, §K. Below: only the slash-command-specific ones.)

### Slash command that commits or pushes automatically

❌ `/<prefix>-implement` that ends with `git commit -m "$commit_message_draft"`.

> "Never commit. The loop ends with a hand-off to the user, who decides whether to run `/<prefix>-audit` and then commit. Never push. Period." - `production-repo-B/.claude/commands/<prefix>-implement.md:18-20`

The user decides when to commit; `/<prefix>-audit` is the gate. The only command that does commit/push is `/<prefix>-ship` - and it has a mandatory STOP gate before doing so.

### Retry loop without a cap

❌ `while reviewer.has_blockers(): maintainer.retry()`. Reviewer thrash. Two careful attempts not resolving = scope is wrong or rule is ambiguous; that needs a human, not a third agent round. The cap is exactly 2 across all production commands.

### Allowing retry to expand scope

❌ Retry prompt that says "fix the BLOCKERS and feel free to clean up adjacent code". Scope-creep on retry produces a moving target the reviewer can't pin down. The retry prompt MUST include "Do NOT widen scope beyond the original request" and pass only the reviewer's BLOCKERS verbatim (`production-repo-B/.claude/commands/<prefix>-implement.md:28-30`).

### Project-specific command added without a recurring workflow

❌ `/<prefix>-design` in a repo with no `<design-tool>` / Figma; `/<prefix>-ship` with no Linear / `<ticketing-tool>` / Jira; `/<prefix>-team` where cross-cutting work spanning ≥3 areas happens once a quarter.

Slash command sprawl pays maintenance for no recurring benefit. The justification lives in `claude-architecture.md` §"Slash commands". If you can't write it, the command shouldn't exist.

### Over-broad `allowed-tools`

❌ `allowed-tools: Task, Read, Edit, Write, MultiEdit, Bash, Glob, Grep` on `/<prefix>-audit`. The audit command needs only `Task`. Listing `Edit` / `Write` / `MultiEdit` gives the orchestrator latitude to "fix things on the way" - which is the auto-fix anti-pattern the audit explicitly forbids (`production-repo-A/.claude/commands/<prefix>-audit.md:50-52`). Match `allowed-tools` to actual needs.

### Multiple parallel writers

❌ Spinning up `general-purpose` write-capable subagents alongside the maintainer for "throughput". The maintainer is the only writer in the roster on purpose; ad-hoc subagents lack preloaded skills and pay context warm-up on each invocation. For parallelism, batch multiple `Agent` calls to **`<prefix>-maintainer`** in a single assistant message - disjoint chunks, one call each (`production-repo-A/.claude/commands/<prefix>-team.md:32`).

## See also

- [agent-roster.md](agent-roster.md) - the four agents the implement loop coordinates; reviewer-fresh-context as agent-side rule; why no per-area maintainers
- [enforcement-hooks.md](enforcement-hooks.md) - `<prefix>_skills_drift.sh` script behind `/<prefix>-audit-skills`; the hook that complements the audit gate
- [evolution-and-drift.md](evolution-and-drift.md) - adding a slash command mid-project; wrapper-around-single-agent symptom; `dart_fix` bulldoze; reviewer-leakage drift
- [architecture-doc.md](architecture-doc.md) - §"Slash commands" entry shape; §"Rejected alternatives" entries for `/<prefix>-plan` in non-cross-cutting repos
- [claude-md.md](claude-md.md) - the commands table in `CLAUDE.md` (always-loaded inventory)
- [bootstrap-procedure.md](bootstrap-procedure.md) - Phase 3 substitution for command files
- Inline templates: [`../templates/claude-layer/commands/REPO-implement.md`](../templates/claude-layer/commands/REPO-implement.md), [`REPO-audit.md`](../templates/claude-layer/commands/REPO-audit.md), [`REPO-audit-skills.md`](../templates/claude-layer/commands/REPO-audit-skills.md)
- Production precedents:
  - repo-A: `production-repo-A/.claude/commands/<prefix>-{implement,plan,team,audit,audit-skills}.md`
  - repo-B: `production-repo-B/.claude/commands/<prefix>-{implement,design,ship,audit,audit-skills}.md`
  - repo-C: `production-repo-C/.claude/commands/<prefix>-{implement,audit,audit-skills}.md`
