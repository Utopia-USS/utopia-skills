---
description: Coordinate cross-cutting work spanning multiple ownership areas. Architect plans; (optional domain auditor) gates sensitive surface; maintainer implements (or batched maintainers if disjoint chunks); reviewer audits; precommit-auditor gates commit. Invoke with /<prefix>-team <task>.
argument-hint: "[feature or task]"
allowed-tools: Task, Read, Bash, Glob, Grep
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Open only if Phase 0.4 confirmed routine parallel-implementation need. Substitute <prefix>. If your repo has a domain auditor, adjust the gate steps and the roster row; otherwise delete both. Strip this banner after substitution. -->

Work on this cross-cutting task: $ARGUMENTS

## Non-negotiables (read these first)

- **Never commit.** The protocol ends at the pre-commit audit; the user
  types the final commit.
- **Never push.** Period.
- **Plan → STOP → user approval** before any maintainer fires (step 1).

## Decision Rule

- **Single-area, small, sequential** - use
  [/<prefix>-implement](<prefix>-implement.md). Lighter orchestration.
- **Cross-cutting** (multiple ownership areas, or ≥2 disjoint chunks
  where parallelism helps) - use this coordination protocol.

## Roster

| Agent | Role | Write? |
|-------|------|--------|
| [`<prefix>-architect`](../agents/<prefix>-architect.md) | Plans, splits work, identifies which skills should fire where | no |
| [`<prefix>-domain-auditor`](../agents/<prefix>-domain-auditor.md) *(if defined)* | Pre-implementation domain check + post-implementation audit on sensitive surface | no |
| [`<prefix>-maintainer`](../agents/<prefix>-maintainer.md) | Implements each plan chunk; runs codegen + analyze + tests; reports per-chunk | **yes** |
| [`<prefix>-reviewer`](../agents/<prefix>-reviewer.md) | Post-implementation review (BLOCKER / WARN / NIT classification) | no |
| [`<prefix>-precommit-auditor`](../agents/<prefix>-precommit-auditor.md) | Final commit-readiness gate via [/<prefix>-audit](<prefix>-audit.md) | no |

If the repo defines per-area maintainers, the production precedent (repo-A)
dropped them in favour of a single cross-area `<prefix>-maintainer` -
parallelism comes from batching multiple calls to that one maintainer,
not from splitting the agent definition. See the repo's
`.claude/docs/claude-architecture.md` for rationale.

## Protocol

1. **Plan.** Delegate to `<prefix>-architect`. Architect defines scope,
   affected areas, file ownership per chunk, codegen impact, domain-
   sensitive surface, testing plan, and risks. **Stop and wait** for
   user approval before step 2.

2. **Domain gate (pre-implementation).** *(Skip this step if the repo
   has no domain auditor.)* If the plan touches the auditor's surface
   (e.g. auth / crypto / key management / RLS / migrations - adjust to
   the team's domain), run `<prefix>-domain-auditor` on the plan.
   **Stop and wait** if it returns findings of severity ≥ medium.

3. **Implement.** Delegate to `<prefix>-maintainer` for each chunk.
   - **Parallelism.** If the architect's task split has ≥2 genuinely
     disjoint chunks AND wall-clock matters, batch multiple `Agent`
     calls to `<prefix>-maintainer` in a single assistant message so
     they run concurrently. One call per chunk, each with a scoped
     prompt naming its files and the relevant domain skills.
   - **Sequential default.** Otherwise call `<prefix>-maintainer` once
     per chunk in turn, waiting for the report before the next.
   - Path-based reference nudges fire automatically via the repo's
     quality-check hook (if installed); the maintainer's preloaded
     skills cover the universal surface, with sister skills firing by
     description match for their paths.
   - Codegen runs as part of the maintainer's chunk workflow.

4. **Review.** Invoke `<prefix>-reviewer` on the resulting diff for
   correctness, regressions, test coverage, and contract drift.
   Reviewer runs on **fresh context** - pass only `files_touched`, the
   proposed commit message, and the baseline analyze. Output:
   BLOCKER / WARN / NIT.
   - `BLOCKER` or `WARN` → loop back to step 3, maintainer fixes
     exactly those findings.
   - `NIT` only → continue. Retry cap: two maintainer attempts per
     chunk before stopping and surfacing to the user.

5. **Domain re-check.** *(Skip if no domain auditor.)* If domain-
   sensitive code changed, re-run `<prefix>-domain-auditor` on the
   final diff.

6. **Pre-commit audit.** Invoke [/<prefix>-audit](<prefix>-audit.md)
   (= `<prefix>-precommit-auditor`) on the staged diff for commit
   readiness - debug artefacts, scaffolding, codegen consistency,
   drift in `.claude/`. **Do not commit on the user's behalf.**

7. **Summarise.** Per-area changes, what was actually run vs only
   proposed, outstanding risks, suggested next step.

## Background reading (load before step 1 for domain-adjacent work)

- The repo's architecture / system-topology docs (link in the master
  skill).
- Domain-specific specs the architect needs (data-exchange contract,
  formal spec, RLS matrix, etc.) - keep this section if the repo has
  load-bearing docs; drop if not.
