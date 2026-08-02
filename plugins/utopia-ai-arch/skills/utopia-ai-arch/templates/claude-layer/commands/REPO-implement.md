---
description: Orchestrate a focused implementation with the review loop (plan? → code ↔ review → exit). Does NOT commit.
argument-hint: "<scope or plan reference> [--plan-first] [--no-analyze-baseline]"
allowed-tools: Task, Read, Bash, Glob, Grep, Edit
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Strip this banner after substitution. -->

# /<repo>-implement - code ↔ review orchestrator

Drives one scoped change through the maintainer ↔ reviewer loop and hands
the result back to the user. This command coordinates subagents; it does
not write code itself, and it never commits.

Raw arguments: `$ARGUMENTS`

## Non-negotiables (read these first)

- **Never commit.** The loop ends with a hand-off to the user, who decides
  whether to run `/<repo>-audit` and then commit.
- **Never push.** Period.
- **Reviewer runs on fresh context.** When invoking `<repo>-reviewer`, pass only
  `files_touched` + `proposed_commit_message` + `baseline_analyze`. Withhold the
  maintainer's self-report, reasoning, and warnings - independence is the
  reviewer's only superpower.
- **Retry cap: 2.** Maintainer runs, reviewer fails → maintainer retries once
  with the fix list → reviewer runs again. If it still fails, stop and hand the
  two failing reports to the user. Do NOT loop further.
- **Scope stays constant across retries.** Retry is for fixing the maintainer's
  mistakes against the existing scope - not for expanding scope.

## Step 1 - Parse arguments

From `$ARGUMENTS`: the scope (required), `--plan-first` (optional),
`--no-analyze-baseline` (optional).

## Step 2 - Baseline analyze

Unless `--no-analyze-baseline`: capture the analyzer baseline and store it
as `baseline_analyze`, keyed by path. The reviewer's exit gate is "zero
NEW issues vs baseline", not "zero absolute".

## Step 3 - Plan (optional)

Only if `--plan-first` or an auto-trigger condition holds (scope spans
more than one package, touches schema / codegen surface, or is vague):
delegate to `<repo>-architect` for a plan, then STOP and wait for user
approval before continuing.

## Step 4 - Maintainer attempt 1

Delegate to `<repo>-maintainer`. Pass: scope + plan (if any) + "return a
self-report per your Hand-off format". Receive the eight-field
self-report: `status`, `files_touched`, `commit_message_draft`, `analyze`,
`output_hygiene`, `regen`, `warnings`, `out_of_scope_observations`.

- If `status` is `needs_human`: STOP and surface the report. Do not run
  the reviewer.
- If `analyze` is non-clean and unjustified: bounce back to the maintainer
  once. This does NOT consume a retry - it is the maintainer not meeting
  its own hand-off contract.

## Step 5 - Reviewer attempt 1 (fresh context)

Delegate to `<repo>-reviewer`. Pass ONLY: `files_touched`,
`proposed_commit_message`, `baseline_analyze` - nothing else from the
maintainer.

Exit gate: zero BLOCKERs in `files_touched` AND zero NEW analyzer issues
in `files_touched` vs baseline. WARNs and NITs are advisory. Pass: go to
Step 7. Fail: go to Step 6.

## Step 6 - Maintainer retry (attempt 2 - the cap)

Send the maintainer the reviewer's BLOCKERs verbatim plus any new analyzer
issues, with the instruction: "re-read the current state, apply the fixes,
do NOT widen scope". Then re-invoke the reviewer with the same
fresh-context discipline as Step 5.

- Pass: go to Step 7.
- Fail: go to Step 7 with `status` = `review_double_fail`. No third round.

## Step 7 - Exit / hand off

Print: `status`, `files_touched`, `commit_message_draft`, the reviewer's
verdict, and the maintainer's self-report (for the user - never passed to
the reviewer). Suggest `/<repo>-audit`, then a user-driven `git commit`.

## Done When

- The Step 7 hand-off has been printed - whether the loop ended clean,
  `needs_human`, or `review_double_fail`.

## Do not

- Commit or push.
- Widen scope on retry.
- Run a third review round.
- Leak the maintainer's self-report (or its reasoning / warnings) to the
  reviewer.

## See also

- [/<repo>-audit](<repo>-audit.md) - the pre-commit gate to run after this
  loop
- [.claude/docs/claude-architecture.md](../docs/claude-architecture.md) - §4
  and §6 for the roster and command rationale
