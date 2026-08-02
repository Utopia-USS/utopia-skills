---
description: Pre-commit audit of staged changes for commit-readiness. Read-only.
argument-hint: "[optional scope note, e.g. 'only <area> changes']"
allowed-tools: Task
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Strip this banner after substitution. -->

# /<repo>-audit

One-shot pre-commit gate: launches the precommit auditor against the
staged diff and surfaces its verdict. No loop, no fixes - the user decides
whether to ship or fix first.

Raw arguments: `$ARGUMENTS` (optional scope note, passed through to the
auditor).

## Non-negotiables (read these first)

- Launch the `<repo>-precommit-auditor` subagent via the Task tool with
  the staged diff (`git diff --staged`).
- Surface its output verbatim.
- **Do not modify the diff** - this command is read-only; the user fixes,
  we re-audit.
- Do not auto-fix.

## Done When

- The auditor's verdict (COMMIT-OK / COMMIT-FIX-FIRST / COMMIT-BLOCK) has
  been surfaced verbatim to the user.

## Do not

- Edit, stage, or unstage anything.
- Commit or push.
- Soften or re-interpret the auditor's findings.

## See also

- [/<repo>-implement](<repo>-implement.md) - the code ↔ review loop that
  precedes this gate
- [.claude/docs/claude-architecture.md](../docs/claude-architecture.md) - §4
  for the auditor's place in the roster
