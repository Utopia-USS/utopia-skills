---
name: utopia-resolve-code-review
description: >
  Resolve review comments on the user's OWN pull/merge request end to end: read every
  thread (GitHub via gh, GitLab via glab, Bitbucket via its API, Claude-in-Chrome, or
  pasted text), verify each comment against the actual code, the optional task spec,
  and Utopia Flutter conventions, fix what's real, push back on what isn't — then,
  after a single approval gate, commit, push, reply under every thread, and resolve
  the fixed ones. Trigger whenever the user shares a PR/MR link and wants review
  comments addressed, resolved, handled, or answered ("address the review", "rozwiąż
  code review", "odpowiedz na komentarze", "przejdź przez review") — even if they
  never say "skill" or "review". An optional task spec (link or pasted description)
  makes the triage more complete, but is not required to start. NOT for authoring new
  features from scratch (that is utopia-hooks / utopia-cms) and not for reviewing
  someone else's PR — it only triages and resolves comments on the user's own PR/MR.
  If the user is the REVIEWER wanting to assess someone's changes, use the sibling
  utopia-code-review skill instead.
---

# Utopia Resolve Code Review

Drive the full loop of addressing reviewer comments on **the user's own** PR/MR:
read every comment, triage each one against the real code and Utopia conventions,
present one consolidated plan, and — once approved — fix, verify, push, and reply.

The reviewer on the other side may be a human or another agent running the sibling
`utopia-code-review` skill; the loop is the same either way.

## Forge plumbing

Per-forge commands live in the plugin-shared reference directory (paths relative to
this skill). Detect the forge from the link's host and read its file before Step 0:

- `../../references/github.md` — `gh` + GraphQL review threads, replies, resolve.
- `../../references/gitlab.md` — `glab` + positioned discussions.
- `../../references/bitbucket.md` — REST 2.0 via `curl`.
- `../../references/browser-fallback.md` — read-only browser access + unknown forges.

Unknown forge → browser fallback for reading, drafts-only for output.

## The contract

**One gate, then everything.** Before the gate (Step 3) only read and plan — nothing
leaves the machine. After explicit approval: edit, verify, commit, push, post replies,
resolve fixed threads. This is the default because replies are published under the
user's name — they see the exact wording once, in one place, before anything goes out.

Mode words in the invocation change the depth:

- **"auto"** — don't wait at the gate. Still print the full plan table before acting,
  so the transcript shows what was decided and why.
- **"drafts only" / "tylko drafty"** — never commit, push, or post. Hand back the
  diff and copy-paste-ready replies instead. This is also the automatic fallback
  whenever publishing isn't possible or safe (no CLI/API auth, not the user's PR,
  unknown forge).

Non-negotiables in every mode:

- The browser is **read-only**. Publishing happens only through the forge's
  authenticated CLI/API (`gh` / `glab` / Bitbucket token) — never by clicking a web
  UI. No auth → drafts-only.
- Never force-push, never rewrite history, never commit to any branch other than the
  PR's source branch.
- If the PR author is not the authenticated user, say so and drop to drafts-only
  unless the user explicitly confirms — speaking in someone else's review is their
  call, not yours.
- Don't resolve threads you pushed back on — the reviewer closes those.
- Never post "Done" over an unverified fix. If verification failed or was skipped,
  the reply must say what actually happened.

## Input

- **PR/MR link** — GitHub, GitLab, or Bitbucket; the forge file has the commands.
- **Optional spec** — an issue/Notion/any link, or a description pasted in the
  prompt. Fetch it with whatever tool is connected (the forge CLI for its own
  issues, Notion tools for Notion links, web fetch otherwise). Without a spec do
  NOT block: judge from the code and conventions, and label spec-dependent
  conclusions as assumptions in the plan table so the user can correct them at
  the gate.
- **Mode word** — "auto" / "drafts only" (see above).

Invoked bare, with no link anywhere in the conversation? Ask once and wait:

```
To resolve your review I need:
1. The PR/MR link.
2. Optional: task spec (link or short description) — improves the triage.
3. Optional: mode — default is plan → your OK → full execution;
   say "auto" to skip the gate, or "drafts only" to keep everything local.
```

## Step 0 — Ground yourself

1. Check forge auth (`gh auth status` / `glab auth status` / Bitbucket token —
   see the forge file). No auth means drafts-only from the start; say so up front.
2. From the link: repo coordinates + PR number. Pull metadata and CI in one pass —
   on GitHub:
   `gh pr view <url> --json number,title,body,author,headRefName,headRefOid,baseRefName,isDraft,reviewDecision,url`
   plus `gh pr checks <url>`; equivalents for the other forges are in their files.
   Failing checks earn a line in the plan — fixing comments while CI is red changes
   priorities.
3. Read the spec if one was given.
4. Check out the source branch. The working tree must be clean
   (`git status --porcelain`); if it's dirty, stop and ask before touching anything.
   Use the forge checkout command (`gh pr checkout` / `glab mr checkout` / plain
   `git fetch` + checkout for Bitbucket). If local and remote heads diverge,
   reconcile with the user first — the reviewer commented on a specific commit, and
   planning against different code produces wrong conclusions.

## Step 1 — Read every thread

Use the forge file's commands. Collect from all three surfaces:

- **Review threads** (resolvable, anchored to file:line) — skip already-resolved
  ones; keep outdated ones (outdated ≠ done).
- **Review summaries** (approve / request-changes bodies) and **general PR
  comments** — reply-only surfaces, no resolve button.
- Per item note: thread id, reviewer, file:line, their **exact words**, the diff
  hunk, and whether the author is a bot or an agent (CodeRabbit, a Claude running
  utopia-code-review, …). They get the same triage — bots are wrong more often,
  but not always.

Reconcile your list against the PR's unresolved-thread count so nothing is missed.
Then read the **current code** around every location — not just the diff hunk. The
hunk shows what the reviewer saw; the file shows what's true now.

Fallbacks when the CLI/API can't see the discussion: the browser (read-only —
`../../references/browser-fallback.md`), or comments pasted by the user (then
confirm which branch the PR is on before planning).

## Step 2 — Triage every comment: fix / reply / defer

Verify each comment against the actual code and the spec before deciding. Reviewers
are sometimes wrong, and sometimes the "issue" is intended behaviour. Don't blindly
agree — and don't blindly defend either.

**The Utopia layer** — this is what makes fixes land on the first try. Before
planning any Dart change, load the skill that owns that ground and follow it:

- `utopia-hooks` — screens, hook state, global state, async/pagination, DI, tests.
- `utopia-cms` — admin panels: CmsEntry, CmsTablePage, delegates, actions.

`utopia describe -o -` orients you in an unfamiliar repo (screens, routes, states).
A fix that ignores the conventions bounces off the PostToolUse quality gate and
invites a second round of review comments — slower than doing it right once.

Classify each item:

- **Fix** — a real issue. Note the minimal correct change; no gold-plating, no
  drive-by refactors beyond what was asked.
- **Reply / push back** — a preference you'd argue against, or intended behaviour
  (cite the spec when you can). Draft the reasoning.
- **Defer** — valid but out of scope. Draft a follow-up issue title plus two lines,
  to be created only if the user wants it.

Genuine product calls you can't settle from code or spec: ask at the gate
(AskUserQuestion) — don't guess.

## Scale: one pass or fan out

Decide after reading everything, not before:

- A handful of comments, or comments touching the same code — handle inline.
- A large review with **independent** clusters (separate files/features) — fan out
  read-only subagents, one per cluster, each verifying its comments against code +
  spec and reporting fix/reply/defer with the minimal change.
- Parallelize investigation freely; parallelize **edits** only when file-disjoint.
- Whatever the fan-out, everything funnels into the single gate below.

## Step 3 — The gate

One message containing the whole plan:

| # | Thread (file:line, reviewer) | Comment (faithful, short) | Verdict | Change | Reply to be posted |
|---|------------------------------|---------------------------|---------|--------|--------------------|

plus: the verification you intend to run, the commit plan, CI status, and any
assumptions made for lack of a spec. Then stop and wait for approval (unless
"auto"). If the user flips a verdict, honor it — and regenerate the affected
replies rather than patching them.

## Step 4 — Execute and verify

- Make the approved changes, following the matching Utopia skill. The utopia-hooks
  plugin's PostToolUse hook runs `utopia hooks analyze` on every Dart edit — treat
  its findings as blocking, not advisory.
- Verify with what the repo actually uses: `fvm dart analyze` / `melos run analyze`
  / plain `dart analyze`; targeted tests for the touched code; `utopia doctor` when
  structure moved. Report exactly what ran and what it said. Running a subset is
  fine — the report hiding that it was a subset is not.
- A fix that fails verification does not ship: pull it out of the commit, downgrade
  its reply to an honest status ("tried X, blocked on Y"), and surface it in the
  final report.

## Step 5 — Ship

- **Commit** per logical fix (or one commit for a batch of trivia), matching the
  repo's existing message style. **Push** to the PR branch — plain push only.
- **Reply** under every thread with the approved text, verbatim. For fixed threads
  include the commit: "Done in `abc1234` — …". Then **resolve** those threads.
  Pushback and question replies stay open. Deferred items: post the proposal;
  create the follow-up issue only on request.
- **Final report**: thread → action → commit/reply link; verification summary;
  anything left open and why.

## Reply tone

Match the thread's language — Polish thread, Polish reply. Peer-level, one or two
lines, no corporate padding.

- Good (fixed): "Done in `abc1234` — gated the timer behind the no-sign-up variant."
- Good (fixed, PL): "Poprawione w `abc1234` — timer odpala się tylko w wariancie bez rejestracji."
- Good (pushback): "Intentional — the spec pins the logo to the safe-area top; the old offsets would push it back down."
- Bad: "Thank you for your valuable feedback. After careful consideration of clean-architecture principles…"

## Self-Audit

Before shipping — and again before each publish step — confirm each non-negotiable held:

1. Every thread accounted for, reconciled against the PR's unresolved-thread count?
2. Each verdict checked against the actual current code + spec, not the diff hunk alone?
3. No "Done" reply over an unverified fix — every reply matches what verification actually said?
4. Only fixed-and-pushed threads resolved; pushback and question threads left open?
5. Pushed to the PR's source branch only, plain push — no force-push, no history rewrite, no other branch?
6. If the PR author isn't the authenticated user (or there's no auth), dropped to drafts-only unless the user confirmed?
7. Nothing published before the gate (except explicit "auto"); nothing published at all in drafts-only?

## Attribution

Built by [UtopiaSoftware](https://utopiasoft.io).
