---
name: utopia-code-review
description: >
  Perform a code review of a changeset: a PR/MR link (GitHub, GitLab, Bitbucket) or a
  purely local branch pair — no link required. Reads the full diff plus surrounding
  code, judges it against Utopia Flutter conventions (utopia-hooks / utopia-cms), the
  analyzers, and the optional task spec, and produces a severity-ranked review
  (blockers / should-fix / nits / questions). Given a PR/MR, it can — after one
  approval gate — post the review as inline comments so the author (human or another
  agent) can respond thread by thread. Trigger whenever the user asks to review
  changes, a branch, or a PR/MR ("zrób code review", "przejrzyj ten branch przed
  merge", "review this PR", "co sądzisz o tych zmianach") — even with no link and no
  explicit word "review". NOT for authoring features or fixing code yourself (that is
  utopia-hooks / utopia-cms) and not a substitute for the analyzer, tests, or CI — it
  judges a changeset, it does not produce one. If the user is the AUTHOR handling
  comments they received, use the sibling utopia-resolve-code-review skill instead.
---

# Utopia Code Review

Review a changeset the way a strong Utopia reviewer would: read the whole diff,
verify every suspicion against the actual code, judge against the conventions, and
hand back a severity-ranked review — in chat for local runs, or posted onto the
PR/MR so the author (human or a Claude running `utopia-resolve-code-review`) can
respond thread by thread.

## Forge plumbing

Per-forge commands live in the plugin-shared reference directory (paths relative to
this skill). Read the matching file when a link is involved:

- `../../references/github.md` — `gh` + GraphQL review threads, replies, resolve, batched review.
- `../../references/gitlab.md` — `glab` + positioned discussions.
- `../../references/bitbucket.md` — REST 2.0 via `curl`.
- `../../references/browser-fallback.md` — read-only browser access + unknown forges.

Unknown forge or no auth → the review still happens; only the posting doesn't.

## Scope resolution — what exactly is under review?

Work down this list and state the outcome in one line before reviewing:

1. **PR/MR link given** → pull the source branch (reviewed) and target branch from
   the forge, per its reference file. This also enables posting the review.
2. **Two branches given** ("review X against Y", "X → Y", "X vs develop") → diff X
   against Y locally. Check whether an open PR/MR for X exists (forge file shows
   how); if one does, offer to post there.
3. **One branch given** → target defaults to the repo's default branch
   (`git symbolic-ref refs/remotes/origin/HEAD`); name the assumption.
4. **Nothing given** → current branch vs the default branch; name the assumption.

Then, always:

- `git fetch` first — reviewing stale refs is reviewing fiction.
- The diff under review is `git diff <target>...<source>` (three-dot: changes since
  the merge-base — the same thing the PR shows), plus
  `git diff --stat <target>...<source>` for the shape.
- Optional spec (link or pasted text) sharpens the judgment; without it, don't
  block — mark spec-dependent judgments as assumptions.

## Ground rules

- Read-only until the gate. Posting happens only through the forge's authenticated
  CLI/API; the browser is read-only; no auth or local-only scope → deliver the
  review in chat and stop there.
- Default posting verdict is **COMMENT**. Approve / request-changes are the user's
  call — only on their explicit word.
- One batched review, not a comment per finding as you go. Nothing is posted that
  the gate didn't show.
- An empty Blockers section is a valid outcome. Don't pad severity to look
  thorough, and don't invent nits to fill sections. A finding you could not verify
  against the code is a **Question**, not a Blocker.
- Findings must be actionable: file:line, what's wrong, why it matters, minimal fix.

## Step 1 — Understand the change

- PR/MR title + body (or the user's description), the spec if given, CI status when
  a PR exists.
- `git diff --stat` for the shape, then the full diff, file by file.
- Read the **surrounding code** of touched files — hunks lie by omission: the bug is
  often in how the change meets the code that didn't change.
- Orient in the project: `utopia describe -o -` (screens, routes, global states).

## Step 2 — Three review passes

Cheap to expensive; skip nothing silently:

1. **Conventions** (Dart changes): load the owning skill — `utopia-hooks` for
   screens/state/hooks/DI/async, `utopia-cms` for admin panels — and check the diff
   against its rules: Screen/State/View boundaries, hook usage, state ownership,
   naming. Convention drift caught in review is the cheapest place to catch it.
2. **Mechanical**: when the source branch is checked out (or the tree is clean and
   the user agrees to check it out), run what the repo uses — `fvm dart analyze` /
   `melos run analyze` / `dart analyze` — and `utopia doctor` for a repo-wide
   convention audit (the full `utopia` CLI surface is documented in the utopia-hooks
   skill — see its `references/utopia-cli.md`). Count only issues the diff plausibly
   introduced —
   compare against the target branch when pre-existing noise muddies it. Can't run
   analyzers? The review proceeds static-only and the report says so.
3. **Reasoning**: correctness and edge cases, async/lifecycle (cancellation,
   mounted-ness, race windows), state ownership and rebuild scope, error handling,
   missing or weakened tests, dead code, cheap perf/security wins. Verify every
   suspicion against the actual code before it becomes a finding — a review that
   cries wolf gets ignored.

Large diff with independent areas? Fan out read-only subagents per area; their
findings funnel into the single report below. Parallelize reading, never posting.

## Step 3 — The report

Use exactly this structure; number findings globally (the numbers become inline
comments when posting):

```
## Review: <source> → <target>
Verdict: ship | ship after fixes | needs work
Scope: <N> files, +<A>/−<B> · analyzers: ran / static-only (why) · spec: yes / assumed
Assumptions: <only if any>

### Blockers
1. `file:line` — what breaks, why it matters — minimal fix
### Should fix
2. …
### Nits
3. …
### Questions
4. …
### Solid
- one to three things genuinely done well (omit the section rather than flatter)
```

Local scope (no PR/MR)? Deliver the report in chat and stop — done.

## Step 4 — Post (PR/MR scope, after the gate)

Show the full report plus, per finding, where its inline comment will land
(file:line, exact text). Wait for approval. Mode words:

- **"auto"** — don't wait; still print the report first.
- **"local only" / "tylko lokalnie"** — never post, even with a link.

Then post **one review**: inline comments at each finding's location, the verdict
summary as the review body (forge file has the commands; on forges without batched
reviews, e.g. Bitbucket, post per-comment in finding order). Report back with links.

If the author is another agent, nothing changes — write comments a human would be
glad to receive; the sibling skill on the other side will read them thread by thread.

## Tone

Match the language of the PR/its comments. Peer-level, specific, no lectures —
every comment says what, why, and the smallest fix. Questions are honest questions,
not rhetorical traps.

- Good (blocker): "`state.dart:42` — `useSubmitState` swallows the error here, so a
  failed save looks like success in the UI. Rethrow or surface `error` in the view."
- Good (nit, PL): "`main_screen.dart:18` — ten `Container` nic nie wnosi, można go
  usunąć."
- Bad: "This file has several issues that should be addressed for code quality."

## Self-Audit

Before posting (or delivering) the review, run down this list — each maps to a Ground rule above:

1. Every finding carries `file:line` + why it matters + a minimal fix? → "Findings must be actionable"
2. Anything you couldn't verify against the actual code filed as a **Question**, not a Blocker? → "verify every suspicion"
3. Blockers empty because the change is genuinely clean — not padded, and no invented nits?
4. Verdict is COMMENT unless the user explicitly asked to approve / request changes?
5. Scope line states whether analyzers ran (or why not) and whether the spec was given or assumed?
6. Nothing posted that the gate didn't show; nothing posted at all in local-only / no-auth scope?

## Attribution

Built by [UtopiaSoftware](https://utopiasoft.io).
