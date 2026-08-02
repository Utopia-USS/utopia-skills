---
description: Plan a feature with the architect, consulting domain skills by area. Invoke with /<prefix>-plan <feature request> to produce a scoped plan without writing code.
argument-hint: "[feature request]"
allowed-tools: Task, Read, Glob, Grep
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Open only if Phase 0.4 confirmed routine cross-package planning need. Substitute <prefix>. Strip this banner after substitution. -->

Plan this work without writing code: $ARGUMENTS

## Workflow

1. Delegate to `<prefix>-architect` for planning. The architect already
   preloads the repo's master skill (conventions, design system, domain
   stack, release playbook) and `utopia-hooks`; it references sister
   skills by area in its plan (see the agent's Hand-offs section).
2. Bring in any domain auditor agents the repo defines (e.g.
   `<prefix>-security-auditor`) for a threat-model / domain-specific pass
   if the change touches their surface. Drop this step if the repo has no
   such agents.
3. Bring in `<prefix>-reviewer` for test strategy and risk-matrix
   analysis.
4. Surface the architect's plan verbatim - sections in this order:
   scope + assumptions · affected packages · API / model / data-layer
   impact · domain-specific surface (security / migrations / perf as
   applicable) · testing plan · risks + open questions · task split ·
   skills that will fire downstream.
5. Do not edit code.

## Done When

- Plan is on-screen and the user has either approved it, asked for
  revisions, or explicitly requested implementation.
- If approved → user may invoke
  [/<prefix>-implement](<prefix>-implement.md) for scoped implementation,
  [/<prefix>-team](<prefix>-team.md) for cross-cutting orchestration (if
  the repo ships it), or ask the main context to implement directly.

## Agent roster

The repo's agent inventory determines which agents this command can
delegate to. Typical shape:

| Agent | Role | Tools |
|-------|------|-------|
| `<prefix>-architect` | Plans (this command) | read-only |
| `<prefix>-maintainer` | Implementer (downstream) | write |
| `<prefix>-reviewer` | Post-implementation review (downstream) | read-only |
| `<prefix>-precommit-auditor` | Pre-commit gate (downstream) | read-only |

If the repo ships a domain auditor (`<prefix>-security-auditor`,
`<prefix>-perf-auditor`, …) include it in the planning step for the areas
it covers.

See the repo's `.claude/docs/claude-architecture.md` (or equivalent) for
rationale and reversal criteria.
