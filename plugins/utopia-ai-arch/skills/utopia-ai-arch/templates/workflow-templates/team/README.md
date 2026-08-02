# team bundle

Command-only bundle. Installs `.claude/commands/<prefix>-team.md` - an
orchestrator that runs architect → parallel maintainer batches → reviewer
→ pre-commit auditor for cross-cutting work.

## When to open

Open this bundle when the team's typical PR routinely splits into **2 or
more genuinely disjoint chunks** worth implementing in parallel:

- Cross-cutting features that touch multiple ownership areas
  simultaneously (UI + backend + data, app + admin, etc.), and
- The disjoint chunks have minimal file overlap (so parallel maintainer
  calls don't fight over the same files), and
- Wall-clock matters - saving 30-90 seconds per PR by parallelising is
  worth the coordination overhead.

**Not auto-inspectable** - having multiple packages doesn't imply parallel
maintainer fan-out is worth it. Phase 0.4 must surface this with a user
prompt:

> *"Do your PRs routinely split into 2+ disjoint chunks you'd want to
> implement in parallel (different files, different ownership areas)?"*

If most PRs are single-area or the chunks aren't independent enough to
parallelise safely, reject this bundle and use `/<prefix>-implement`
instead.

## Reversal - when **not** to open

- Most PRs touch a single area and run cleanly through
  `/<prefix>-implement`.
- The repo's "disjoint" chunks aren't actually disjoint - parallel
  maintainers would step on each other's edits.
- The team prefers sequential implementation for predictability and
  doesn't value the wall-clock saving.

## What this bundle ships

- `command/<prefix>-team.md` (ships as [`command/REPO-team.md`](command/REPO-team.md)) - full cross-cutting orchestration: architect
  plans + splits → optional domain-auditor gate → parallel maintainer
  batches (when disjoint) → reviewer → optional domain-auditor re-check
  → pre-commit auditor → user-driven commit.

No skill - orchestration is the whole content; the agents this command
invokes carry the domain knowledge.

## Substitution checklist

- `<prefix>` - repo command/agent prefix (e.g. `aap`).
- Agent references - `<prefix>-architect`, `<prefix>-maintainer`,
  `<prefix>-reviewer`, `<prefix>-precommit-auditor`.
- Domain auditor - `<prefix>-security-auditor` is repo-specific (example). If the
  repo has a domain auditor (security, perf, migrations, accessibility,
  …), keep the gate steps and rename. If not, **drop steps 2 and 5
  entirely**.
- Sister-command references - `/<prefix>-implement`, `/<prefix>-audit`
  must exist in the repo, or remove the cross-links.
- Domain-specific gate criteria - the production version triggers
  security-auditor on "auth, crypto, key management, native crypto FFI, key-exchange primitives,
  Supabase RLS". Replace with the repo's actual security-sensitive surface
  (or perf-sensitive, or migration-touching, depending on what the domain
  auditor covers).

## Production precedent

repo-A is the only production repo currently shipping this bundle. The
five-agent roster (architect / security-auditor / maintainer / reviewer /
precommit-auditor) is documented in repo-A's
`.claude/docs/claude-architecture.md` §Decisions.

## Load-bearing pieces - keep when adapting

- **Plan → STOP → user approval before implementation.** Cross-cutting
  work is expensive to redo; the user approves the architect's split
  before any maintainer fires.
- **Domain-auditor gate before implementation** (step 2). If a domain
  auditor exists and the plan touches its surface, run it on the *plan*
  before any code is written. Severity ≥ medium → STOP and wait.
- **Parallel maintainer batches when disjoint.** If the architect's task
  split has ≥2 genuinely disjoint chunks AND wall-clock matters, batch
  multiple `Agent` calls to `<prefix>-maintainer` in a *single* assistant
  message so they run concurrently. One call per chunk, each with a
  scoped prompt naming its files and the relevant domain skills.
- **Sequential default otherwise.** Call `<prefix>-maintainer` once per
  chunk in turn, waiting for the report before the next.
- **Reviewer fresh context.** As in `/<prefix>-implement`, the reviewer
  sees only `files_touched`, the proposed commit message, and the
  baseline analyze - never the maintainer's reasoning.
- **Retry cap 2.** Per chunk. Two maintainer attempts max before stopping
  and surfacing to the user.
- **Domain-auditor re-check on final diff** (step 5). If security-/perf-/
  migration-sensitive code actually changed, run the auditor again on the
  resulting diff.
- **Pre-commit audit as a gate, not a commit.** The command never commits
  on the user's behalf - `/<prefix>-audit` runs the precommit-auditor and
  surfaces findings, but the user types the final commit.

## Strip-the-banner reminder

The command file ships with a `<!-- BLUEPRINT -->` banner. Remove it once
substitution is complete.
