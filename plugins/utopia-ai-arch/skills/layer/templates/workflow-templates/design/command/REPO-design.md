---
description: "Design→code pipeline - reads design from <design-tool> or claude.design, then runs architect → maintainer ↔ reviewer loop. Does NOT commit."
argument-hint: "[paper | handoff <path>] [--no-analyze-baseline]"
allowed-tools: Task, Read, Bash, Glob, Grep, Edit
model: inherit
---

<!-- BLUEPRINT - adapt per-repo. Workflow-style slash command paired with REPO-design/SKILL.md. Open only if Phase 0.4 confirmed design-tool integration. Substitute <prefix> tokens. Strip this banner after substitution. -->

# /<prefix>-design - design→code orchestrator

You coordinate design acquisition, then `<prefix>-architect`,
`<prefix>-maintainer`, and `<prefix>-reviewer` to land a design
implementation with review-loop discipline. You do **not** write code
yourself. You do **not** commit or push. The `<prefix>-design` skill owns
the design-acquisition and translation workflow - this command assumes it
is installed alongside.

Raw arguments: `$ARGUMENTS`

## Non-negotiables (read these first)

- **Never commit.** The loop ends with a hand-off to the user.
- **Never push.** Period.
- **Reviewer runs on fresh context.** Pass only `files_touched` +
  `proposed_commit_message` + `baseline_analyze`. Withhold the maintainer's
  self-report and reasoning.
- **Retry cap: 2.** Maintainer → reviewer fails → maintainer retries once →
  reviewer again. If still failing, stop and hand both reports to the user.
- **Scope stays constant across retries.**

## Step 0 - Acquire design

Detect the design source from `$ARGUMENTS`:

- `paper` → use <design-tool> MCP tools.
- `handoff <path>` → read handoff bundle from `<path>`.
- (empty) → auto-detect: try `mcp__paper__get_basic_info` (paper MCP
  available?), check for `.claude-handoff/` directory, ask user if
  neither found.

### <design-tool> acquisition

```
1. get_basic_info          → file name, artboards, dimensions
2. get_tree_summary        → full hierarchy of the target artboard/node
3. get_screenshot          → visual reference (save as context)
4. get_jsx                 → JSX + Tailwind code representation
5. Compile into design brief
```

If the user has selected specific nodes in <design-tool>, use `get_selection`
first instead of `get_tree_summary`.

### Claude.design acquisition

```
1. ls <bundle path>        → inventory what's in the bundle
2. Read PROMPT.md          → designer intent, hierarchy, instructions
3. Read tokens/            → design token definitions
4. Read components/        → component structure
5. List assets/            → referenced assets
6. Compile into design brief
```

### Design brief format

Compile the acquired design into a structured brief:

```
## Design Brief
Source: <design-tool> / claude.design
Artboard(s): <name, dimensions>

### Structure
<hierarchy from tree_summary or bundle components>

### Visual Reference
<screenshot reference or description>

### Components identified
<list of UI elements visible in the design>

### Interactions implied
<buttons, forms, navigation, data loading visible in design>

### Assets
<icons, images that need handling>
```

## Step 1 - Parse remaining arguments

Extract from `$ARGUMENTS`:

- `--no-analyze-baseline` - skip baseline analyze capture.

## Step 2 - Baseline analyze (unless skipped)

Capture per-file issue counts by severity using the repo's analyzer tool
(`mcp__<prefix>-dart__analyze_files` or `dart analyze`). The reviewer's
exit gate is **"zero NEW issues in `files_touched` vs baseline"**.

## Step 3 - Planning (always on for designs)

Always invoke `<prefix>-architect`. Designs need planning - the architect
determines which files to create/modify, which components to use, and
what Screen/State/View structure is needed.

Invoke `<prefix>-architect` via the Task tool:

```
Implement the following design in the <prefix> codebase.

Design brief:
<design brief from Step 0>

Plan which files to create/modify, which components to use, what
Screen/State/View structure is needed, and what hooks handle the
interactions. Use the <prefix> master skill for component knowledge and
utopia-hooks for state patterns.
```

## Step 4 - Code (maintainer, attempt 1)

Invoke `<prefix>-maintainer` via the Task tool:

```
Implement the following design. The result must be production-ready -
use the repo's component catalogue (no custom widgets where catalogue
equivalents exist), design tokens (no raw literals), and utopia-hooks
Screen/State/View for full pages.

Design brief:
<design brief from Step 0>

Plan:
<architect plan from Step 3>

Match the visual design as closely as possible using the design system.
Follow the <prefix>-design skill's Translation Workflow for the
design-to-component mapping. Flag any design elements that don't have
catalogue equivalents.

Follow the <prefix>-maintainer workflow. Return the structured self-report
per your "Hand-off format" section. Do NOT commit or push.
```

Extract from the maintainer's self-report: `status`, `files_touched`,
`commit_message_draft`, `analyze` status.

If `status = needs_human` → stop. Surface the report.
If `analyze` is non-clean and not justified → bounce back before review.

## Step 5 - Review (reviewer, attempt 1)

Invoke `<prefix>-reviewer` via the Task tool, **fresh context**:

```
Review the following change set against the <prefix> + utopia-hooks skill
surface. You are independent - you do NOT see the maintainer's reasoning,
self-report, or warnings. Verify the diff from scratch.

files_touched:
<list from maintainer self-report>

proposed_commit_message:
<draft from maintainer self-report>

baseline_analyze (pre-change analyzer issue counts per file):
<map or "not captured - use zero-absolute gate">

Produce your classified report (BLOCKER / WARN / NIT) per your agent
definition. Exit gate: zero BLOCKERS in files_touched, zero NEW
analyzer issues vs baseline. WARNs and NITs are advisory.
```

- **Pass** (no BLOCKERS) → Step 7.
- **Fail** (any BLOCKER) → Step 6.

## Step 6 - Retry (maintainer, attempt 2)

Re-invoke `<prefix>-maintainer` with the reviewer's BLOCKERS:

```
The reviewer flagged issues with your previous implementation. Apply the
fixes and return a refreshed self-report. Do NOT widen scope beyond the
original design.

Original design brief:
<design brief>

Reviewer BLOCKERS:
<blockers verbatim>

New analyzer issues vs baseline:
<list or "none">

Re-read the current state of files_touched, apply fixes, re-run output
hygiene (formatter on files_touched only - do NOT bulk-format unrelated
files), re-run the analyzer, and return a fresh self-report.
```

Then re-invoke `<prefix>-reviewer` with fresh-context discipline.

If reviewer passes → Step 7. If fails again → Step 7 with
`status: review_double_fail`.

## Step 7 - Exit

Hand off to the user. Print:

```
# /<prefix>-design - <design label>

source: <<design-tool> / claude.design>
status: <passed | partial | review_double_fail | needs_human>

files_touched:
- <path>
- ...

commit_message_draft:
<the maintainer's draft>

reviewer verdict:
<final reviewer report>

maintainer self-report (for user visibility, NOT passed to reviewer):
<full self-report from last maintainer attempt>

design gaps (elements without catalogue equivalents):
<list from maintainer's flags, if any>

next step:
- if passed: run /<prefix>-audit then commit
- if review_double_fail: review the reports and decide
- if partial / needs_human: read the self-report for what's needed
```

## What to show during the run

Brief text updates at meaningful moments:

- "Acquiring design from <design-tool>…"
- "Design brief compiled: 3 artboards, ~12 components identified."
- "Running architect - planning component mapping + Screen/State/View
  structure."
- "Maintainer done. files_touched: 6 files, 2 design gaps flagged.
  Handing to reviewer."
- "Reviewer flagged 1 BLOCKER - retrying maintainer with fix list."
- "Review passed. Summary below; commit is yours."

## Failure modes - stop, do not improvise

- Paper MCP not available → inform user, suggest `handoff <path>`
  alternative.
- Handoff bundle path doesn't exist → stop, ask for correct path.
- Maintainer returns `needs_human` → stop.
- Reviewer double-fails → hand off with both reports.
- Agent returns empty / malformed report → surface raw output.
