---
description: Drift scan over .claude/**/*.md and CLAUDE.md - reports dead markdown links. Pass "fix" to propose repairs interactively.
argument-hint: "[fix] - propose repairs interactively; omit for report-only"
allowed-tools: Bash, Read, Edit
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Strip this banner after substitution. -->

# /<repo>-audit-skills

Runs the deterministic drift scan over the `.claude/` layer and surfaces
dead markdown links. Report-only by default; with `fix` it walks the user
through repairs one finding at a time.

Raw arguments: `$ARGUMENTS`

## Non-negotiables (read these first)

- **Report-only unless `$ARGUMENTS` is `fix`.**
- **Never rewrite a reference silently** - always show the diff first.
- **Do not batch-apply** - confirm each repair with the user individually.

## Step 1 - Report

Run `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/<repo>_skills_drift.sh" --all`
and print its output verbatim. If `$ARGUMENTS` is empty, stop here.

## Step 2 - Repair (only when `$ARGUMENTS` is `fix`)

For each finding:

1. Read the line containing the dead link.
2. Glob by basename for the likely new location of the target.
3. If ambiguous, use `git log --diff-filter=D` to disambiguate rename
   vs delete.
4. Propose a concrete repair (file + line + replacement).
5. Apply only after the user confirms, then move to the next finding.

## Done When

- Report mode: the script output has been surfaced verbatim.
- Repair mode: every finding was repaired (user-confirmed) or explicitly
  skipped.

## Do not

- Edit anything in report-only mode.
- Apply a repair without showing the diff and getting confirmation.
- Batch-apply repairs.

## See also

- [/<repo>-audit](<repo>-audit.md) - staged-diff commit-readiness audit
- [.claude/docs/claude-architecture.md](../docs/claude-architecture.md) - §7
  for the drift-scan mechanism
