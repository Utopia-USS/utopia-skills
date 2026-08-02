# plan bundle

Command-only bundle. Installs `.claude/commands/<prefix>-plan.md` - a
plan-only invocation that delegates to the architect agent and stops before
implementation.

## When to open

Open this bundle when the team routinely works on PRs spanning **3 or more
packages / workspaces**, and a discrete plan-only step (separate from the
implementation orchestrator) adds value:

- Monorepo with backend + app + admin + landing (or similar), and
- Features routinely require touching the data model, the service layer,
  and the UI in one PR, and
- The team wants to review the architect's plan before deciding whether to
  proceed with `/<prefix>-implement` or `/<prefix>-team`.

**Not auto-inspectable** - having multiple packages doesn't mean PRs
routinely span them. Phase 0.4 must surface this with a user prompt:

> *"Do you frequently work on PRs spanning 3+ packages or workspaces?
> Would a plan-only invocation (before deciding how to implement) be
> useful?"*

If PRs mostly touch a single package and planning happens inline inside
`/<prefix>-implement`, reject this bundle.

## Reversal - when **not** to open

- Single-package repos.
- Multi-package repos where cross-package work is rare.
- Teams that always run the full architect → maintainer → reviewer loop
  and don't want a separate plan-only step.

## What this bundle ships

- `command/<prefix>-plan.md` (ships as [`command/REPO-plan.md`](command/REPO-plan.md)) - architect-only delegation; produces a
  scoped spec and **stops before implementation**.

No skill - planning logic lives in the architect agent's definition, not in
a separate body of knowledge.

## Substitution checklist

- `<prefix>` - repo command/agent prefix (e.g. `aap`).
  Appears in:
  - command name (`/<prefix>-plan`)
  - architect agent reference (`<prefix>-architect`)
  - any sister-command references in "Done When"
- Domain-skill list in step 2 - the production version names a domain
  auditor and references area-specific sister skills
  (`<prefix>-domain-auditor`, `<prefix>-backend`, …). Replace with the
  team's domain skills or drop entirely if the architect alone is enough.

## Production precedent

repo-A is the only production repo shipping this bundle. The plan step is
upstream of both `/<prefix>-implement` (single-area work,
e.g. `/aap-implement`) and `/<prefix>-team` (parallel cross-cutting work),
letting the user pick the right downstream orchestrator after seeing the
plan.

## Load-bearing pieces - keep when adapting

- **Architect-only delegation.** The command invokes only the architect;
  no maintainer, no reviewer, no codegen, no writes.
- **Stop before implementation.** The "Done When" criterion is explicitly
  "plan is on-screen and the user has approved / revised / asked for
  implementation". The command does not chain into implementation
  automatically.
- **Deliverable shape - scoped spec.** Sections in this order: scope +
  assumptions · affected packages · API / model / data-layer impact ·
  domain-specific surface (security / perf / migrations as applicable) ·
  testing plan · risks + open questions · task split · skills that will
  fire downstream.

## Strip-the-banner reminder

The command file ships with a `<!-- BLUEPRINT -->` banner below the
frontmatter. Remove it once substitution is complete.
