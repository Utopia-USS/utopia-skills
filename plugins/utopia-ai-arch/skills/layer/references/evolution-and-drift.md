---
title: Evolution & Drift - Operations on a Live `.claude/` Layer
impact: CRITICAL
tags: evolution, drift, graduation, splits, decision-log, maintenance, lifecycle, anti-patterns, audit, failure-modes
---

# Evolution & Drift - Operations on a Live `.claude/` Layer

## What this is

Two halves, deliberately fused:

1. **Operations** - the mechanical procedures for evolving an existing `.claude/` layer once bootstrap is done (graduate a memory entry, split a skill, collapse one back, delete a stale skill, add/remove a path nudge, add a domain auditor mid-project, record a rejected alternative).
2. **Drift catalogue** - the empirical failure-mode list: 21 things that have actually happened in production-repo-A, production-repo-B, or production-repo-C (shortened to repo-A / repo-B / repo-C throughout these references). Each entry: symptom, file:line evidence, fix.

They live in one file because every operation has a corresponding drift symptom - every "how to" pairs with a "what goes wrong if you don't". Reading them apart re-creates the same drift twice.

Creation of the layer is covered separately by [bootstrap-procedure.md](bootstrap-procedure.md).

## When this applies

Triggers that should make the agent **re-read `.claude/docs/claude-architecture.md` before acting**:

- A **new techstack** joining the repo (Kotlin backend in a Dart-only repo; Cloud Functions alongside Flutter; an active Next.js landing).
- A **new MCP server** considered or installed (changes the permission allowlist, the agent-prompt tool tables, and the `assumed MCP` rejected-alternative entry).
- A **new external integration** (Linear, `<ticketing-tool>`, `<design-tool>`, Figma, RevenueCat, GitHub Issues) an agent or slash command will need to talk to.
- A **recent incident** - the strongest trigger for adding a domain auditor.
- A **proposal to add or remove an agent / a slash command** - even before drafting, check §"Agent roster" / §"Rejected alternatives".
- **Repeated agent drift** - the agent keeps losing convention X across unrelated sessions; X belongs in a hook, a skill row, or `CLAUDE.md`, not just memory.
- **A skill no longer fires** on files it should (or fires on files it shouldn't) - applicability has drifted from the codebase.
- **A reference no longer matches the codebase** (stale paths, deleted classes, renamed components) - stale refs are worse than missing refs.
- **A `.claude/refs/` file is referenced from only one skill** - drifted out of "cross-skill" territory; collapse back into that skill's `references/`.

Also: auditing a layer (`/<prefix>-audit-skills`, manual scan), debugging "why is the agent doing X?", or reviewing a proposed `.claude/` change against known anti-patterns.

---

## 1. Operating discipline - re-read the architecture doc first

Before any operation below:

1. **Read `.claude/docs/claude-architecture.md` §"Decisions" and §"Rejected alternatives" in full.** Not skim - read.
2. **Check whether the proposed change matches an existing reversal criterion.** If yes - proceed, then **update the entry in place** (don't delete it; record what flipped the decision).
3. **If the proposed change matches nothing listed** - it's *unrecorded design space*. Add a new entry in the canonical 4-field shape ([architecture-doc.md](architecture-doc.md)) as part of the proposal, *before* doing the work.

The rejected-alternative entries are the only mechanism preventing the same proposal from being re-litigated every few months. Keep all entries; flip them in-place when criteria are met. Deleting an entry because "we've confirmed it's wrong now" removes the prevention.

---

## 2. The graduation gradient - reversible

```
project memory  ←→  references/<feature>-module.md  ←→  own skill
                              (in the closest applicable skill)
```

Reversibility is load-bearing. A graduation that turns out to be premature collapses back into a `*-module.md` without ceremony.

### 2.1 Memory → `references/<feature>-module.md` (forward)

**Trigger.** Vertical touched in 2+ sessions, stable shape, you find yourself re-explaining it in memory.

**Mechanical steps:**

1. Pick the **closest applicable skill** - the one whose `applicability` already covers the file paths.
2. Author `<skill>/references/<feature>-module.md` per [skill-design.md](skill-design.md) module-style rules - business intent first, user flow numbered, location paths only. No code dumps.
3. Add the file to `<skill>/SKILL.md` §"Problem → reference mapping" *and* §"References" tables. A reference not linked from `SKILL.md` is invisible.
4. Delete the project-memory entries the module now subsumes.
5. **No `claude-architecture.md` entry needed** unless this is a new reference *style* - then update §"Reference styles in use".

### 2.2 `<feature>-module.md` → own skill (forward)

**Trigger.** Module grown beyond consuming skill's applicability - multiple sub-flows, own patterns/cheatsheet - *and* its applicability scope is genuinely disjoint.

**Mechanical steps:**

1. Write the new skill's `description:` with **explicit positive AND negative applicability** ([skill-design.md](skill-design.md)). Can't write the negative scope → it's not a real split.
2. Create `<prefix>-<area>/SKILL.md` per canonical shape. Cross-link to the parent skill from §"See also".
3. **Move** (not copy) the module reference and accumulated siblings to `<new-skill>/references/`. Update internal links.
4. Update parent skill's `SKILL.md` - remove migrated rows from Problem→reference and References tables; add a See also line pointing at the new sister.
5. Update `CLAUDE.md` Skills inventory.
6. Update `claude-architecture.md` §"Skill split" - add a row with positive + negative applicability + granularity rationale.
7. If the parent's path nudge in `<prefix>_quality_check.sh` covered migrated paths, **split the nudge** - parent stays for what stays, new branch for what moved. New branch must match new skill's `applicability` exactly ([enforcement-hooks.md](enforcement-hooks.md)).
8. Update each agent's `skills:` frontmatter if the agent should preload the new skill.
9. Throwaway-edit a file in the new skill's positive applicability; confirm description match fires + path nudge surfaces the right reference.

### 2.3 Own skill → `<feature>-module.md` (reverse - collapse)

**Trigger.** Symptoms:
- Description never fires when expected.
- The skill's `references/` content is consumed only by the parent skill's domain workflows.
- Split justified by "we expect this to grow" and it hasn't for ≥3 months.

Pre-recorded reversal precedent: `production-repo-C/.claude/docs/claude-architecture.md:117` for `<prefix>-functions`.

**Mechanical steps:**

1. Identify the **consuming master skill**.
2. Move all of `<orphan>/references/*.md` into `<master>/references/`. Resolve collisions with a domain prefix (`<area>-<topic>-pattern.md`).
3. Update internal cross-links (relative paths shift).
4. Delete `<orphan>/SKILL.md` and the empty `references/`.
5. Update `<master>/SKILL.md` - add migrated refs to its tables, remove the See also for the deleted sister.
6. Update `CLAUDE.md` Skills inventory - delete the collapsed row.
7. Update `claude-architecture.md` §"Skill split" - delete the row, **add §"Rejected alternatives"** capturing the experiment. The experiment lived in your repo for months; record it.
8. Fold path nudge in `<prefix>_quality_check.sh` back into the parent's.
9. Remove the orphan from each agent's `skills:` frontmatter.

---

## 3. Splitting a skill out of the master

When the master is firing on too broad a surface, or an audit/convention checklist has tightened enough to deserve its own description match.

**Trigger (use [skill-design.md](skill-design.md) §6 criteria):**
- The audit / convention checklist applies under a **tighter description** than the engineering surface.
- AND benefits from being preloaded alongside the master skill.
- AND has ≥3 reference docs of audit-only material.

**Precedent.** repo-A's `<prefix>` / `<prefix>-security` split - engineering surface vs adversarial audit, all agents preload both (`production-repo-A/.claude/docs/claude-architecture.md:127`).

**Mechanical steps:**

1. Read §"Rejected alternatives" - is "keep as one master" the recorded choice? If yes, you need a reversal-criterion-met update; if no, a new positive entry.
2. Author the new `SKILL.md` with positive+negative scope. Negative scope must explicitly disclaim the master's surface.
3. **Move** files from `<master>/references/` to `<sister>/references/`. Don't copy - two copies drift.
4. Update cross-links inside moved files. Update master's `SKILL.md` tables and add the See also.
5. Update agent `skills:` frontmatter for every agent that should preload the new skill (usually all four standard agents - audit perspective is a posture, not a role).
6. Update `<prefix>_quality_check.sh` - add a new path-nudge branch, OR adjust existing nudges to surface *both* skills on shared paths.
7. Update `CLAUDE.md` Skills inventory.
8. Update `claude-architecture.md` §"Skill split" + a §"Rejected alternatives" entry if "keep as one master" was a real candidate.
9. Validate: description match fires on the new skill's positive applicability; negative scope keeps wrong-stack files from loading.

---

## 4. Deleting a stale skill (vs collapsing it)

**Delete** (not collapse) when:
- Description hasn't fired in ≥10 PRs.
- ALL references have moved elsewhere (other skills' `references/` or `.claude/refs/`).
- Content overlaps with `CLAUDE.md`'s always-loaded inventory.
- The skill was a "FAQ skill" better expressed as inline `CLAUDE.md` rows.

**Precedent.** repo-A rejected `<prefix>-repo-map` and `<prefix>-build-verify` for this - content thin, overlapped with `CLAUDE.md` which loads every turn (`production-repo-A/.claude/docs/claude-architecture.md:256-258`).

**Mechanical steps:**

1. Migrate any worth-keeping content to `CLAUDE.md` or a sister skill's references.
2. `rm -rf .claude/skills/<prefix>-<area>/`.
3. Update `CLAUDE.md` Skills inventory.
4. Update `claude-architecture.md` - delete the §"Skill split" row, **add a §"Rejected alternatives" entry** for the deletion (alternative kept as standalone / case for / case against / reversal criterion).
5. Remove path nudges pointing at the deleted skill.
6. Remove from agent `skills:` frontmatter.
7. Run `<prefix>_skills_drift.sh --all` to confirm no dangling links remain (no arguments = hook mode, which reads stdin and scans nothing).

---

## 5. Hook path nudges - add and remove

### 5.1 Adding incrementally

When a surface has **≥2 references** the agent should consult, deterministic path nudging starts to pay rent. Single-reference surfaces are better served by description matching alone - adding a nudge for one reference clutters the hook.

Precedents: `production-repo-B/.claude/docs/claude-architecture.md:170-178` (defer `<prefix>-api` nudge); `production-repo-C/.claude/docs/claude-architecture.md:141-145` (defer `<prefix>-functions` nudge until 2+ refs).

**Mechanical steps:**

1. **Verify the path pattern matches the skill's `applicability` EXACTLY.** A nudge firing on a path the description wouldn't auto-match surfaces the wrong skill - defeating the determinism.
2. Add the `case/esac` branch to `<prefix>_quality_check.sh`, mirroring existing branches' indentation, exit code, and message format.
3. Throwaway-edit a real file in the surface to validate firing.
4. Document in `claude-architecture.md` §"Hook scope".
5. **Don't** preemptively add nudges for "future" content.

### 5.2 Removing

When a surface no longer has references worth surfacing - content moved, or refs deleted because a tool now enforces what they documented.

1. Remove the `case` branch. Don't delete the script - thin the surface.
2. Update `claude-architecture.md` §"Hook scope" - record removal + why (prevents the next contributor re-adding).
3. **Leave generated-file blocks alone.** Removing a `*.g.dart` block needs separate reasoning in §"Enforcement mode".

---

## 6. Adding a domain auditor mid-project

The standard roster is four ([agent-roster.md](agent-roster.md)). A fifth requires written justification in `claude-architecture.md` §"Agent roster".

**Mechanical steps:**

1. **Document the trigger** - incident, threat-surface change, or audit checklist the standard reviewer can't carry without bloat. Without a documented trigger, the agent is roster-creep.
2. Write the agent file with `tools: Read, Grep, Glob, Bash` (read-only) and `skills:` preloading `<prefix>-<master-skill>`, `<prefix>-<domain-skill>` (if you also split out a domain skill), `utopia-hooks`.
3. Update architect / maintainer / reviewer prompts - add "When to route to `<prefix>-<domain>-auditor`" hand-off blocks.
4. Update `CLAUDE.md` §"When to invoke" - add a row for the new agent with trigger paths.
5. Update slash commands that gate on the domain.
6. Update `claude-architecture.md` §"Agent roster" with the new agent + justification. Flip the existing "no domain auditor" rejected-alternative entry in place if it exists.

---

## 7. Updating an agent prompt

**Hard constraint: keep the role contract unchanged.** Architect plans; maintainer writes; reviewer reads on fresh context; auditor gates the staged diff. Do **not** edit the role line at the top - it's the foundation of the orchestration loop.

**Free to update:**
- Invariants list (add new; never remove without architecture-doc justification).
- Anti-patterns block (new symptoms observed in practice).
- Tooling preferences table (when a new MCP joins).
- Hand-off format (when a new field becomes useful).

**Lift to a shared `.claude/refs/agent-conventions.md`** when the same change has landed in 2+ agents' prompts independently (comment-style block, `dart_fix` warning, hand-off field). Drift across agent prompts is its own anti-pattern - reviewer's comment rules and maintainer's comment rules **must** match exactly.

---

## 8. Updating `CLAUDE.md`

Two-pronged drift target: it must (a) match every artefact in `.claude/`, and (b) stay tight enough to not bloat top-of-context.

**Update whenever you:**
- Add/remove/rename a skill → Skills inventory.
- Add/remove/rename an agent → Agents + When-to-invoke.
- Add/remove a slash command → Slash commands table.
- Add/change a top-level common command → Common commands block.
- Add/remove a foundation plugin from `enabledPlugins` → Foundation paragraph.

**Also update whenever the architecture doc changes** in a way that contradicts what `CLAUDE.md` describes (e.g. you flipped a rejected-alternative entry into a `Decisions` row).

Run `/<prefix>-audit-skills` after edits - drift scanner flags dead links. Precommit-auditor catches CLAUDE.md inconsistency on staged diffs that touch `.claude/**/*.md` or `CLAUDE.md` itself (`production-repo-A/.claude/agents/<prefix>-precommit-auditor.md:120-122`).

---

## 9. Moving `.claude/refs/` content

A `.claude/refs/<doc>.md` is only justified when ≥2 skills link to it from their `See also`.

- **Single-consumer ref** → collapse back into that skill's `references/`. The "shared" status was aspirational.
- **Skill-specific content drifted into refs/** → move back to the consuming skill's `references/`.

**Mechanical steps:**

1. Move the file.
2. Update the consuming skill's `SKILL.md` (See also and References).
3. If linked from `claude-architecture.md`, update those cross-links.
4. Run `<prefix>_skills_drift.sh --all` to catch dangling links.

---

## 10. Recording a rejected alternative mid-project

Even if you **didn't** do the thing, write it down - future-you will re-propose it. Use the canonical 4-field shape (`Alternative` / `Case for` / `Case against here` / `Reversal criterion`) documented in [architecture-doc.md](architecture-doc.md) §"Rejected alternatives - 4-field shape".

**Never delete prior entries.** When a previously-rejected alternative IS reversed: update the entry, don't delete. The original `case against` becomes a history note; append "**Flipped (date / context).** New status: adopted / partial / pending"; cross-link the §"Decisions" or §"Skill split" row that owns the adopted shape.

---

# Part II - Drift catalogue

21 failure modes (A through U). Each entry: symptom, evidence (file:line), fix. These are not hypotheticals - each precedent is real and (in most cases) recorded in a §"Rejected alternatives" entry. (T and U are codified from the blueprint's authoring conventions rather than a single production incident; the rest were observed in the production repos.)

When auditing, this is the grep target for what to look for. When designing a new layer, this is the list of mistakes not to make.

---

### A. Master skill `references/` accumulating cross-cutting Dart content

**Symptom.** Master's `references/` holds `freezed.md`, `code-generation.md`, `components.md`, `strict-analysis.md`, `imports-and-formatting.md` - concerns that apply to any Dart authoring, not just the master's surface. Sister skills deep-link into the master.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:126` - `<prefix>` originally documented as the master skill that "owns" Freezed / codegen / strict-analyzer / imports / design-system; the master became uber-skill firing on every techstack.

**Fix.** Lift cross-cutting Dart refs to `.claude/refs/<topic>.md`. Each consuming SKILL.md links from `See also`. Master keeps only what's truly master-specific (repo-A kept `ffi-conventions.md`, `isar.md`).

---

### B. References documenting what deterministic tools already enforce

**Symptom.** Reference files (`imports-and-formatting.md`, `strict-analysis.md`, `naming-conventions.md`) describing rules `dart fix` / `dart format` / `utopia_lints` / the analyzer already block.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:126` - `imports-and-formatting.md` and `strict-analysis.md` were deleted; tools enforce mechanics, the refs were repeating tool output. Judgment calls (suppression policy, FFI-bindings exception) were inlined into `SKILL.md` §"Non-Negotiable Rules".

**Fix.** Delete the reference. Move *judgment calls* (suppression policy, exceptions) inline into `SKILL.md` §"Non-Negotiable Rules". Rule: if the analyzer/formatter would catch the violation, it does not need a markdown ref.

---

### C. Eng-manager / hygiene agent where a script suffices

**Symptom.** `<prefix>-eng-manager.md` / `<prefix>-doc-auditor.md` agent that "audits the `.claude/` layer after feature work" using probabilistic heuristics.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:244` - "a probabilistic agent is strictly weaker than a script that always runs."

**Fix.** Replace with `<prefix>_skills_drift.sh` (dead-link scanner that always runs) + `/<prefix>-audit-skills` (explicit invocation for full scan + guided repair). The precommit-auditor handles internal `CLAUDE.md` / `.claude/docs/` consistency.

---

### D. Per-area maintainers (`<prefix>-<area>-maintainer`)

**Symptom.** Multiple write-capable agents scoped to disjoint directories.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:222-223` - typical work is ticket-scoped single-area; three-area cross-cutting features are infrequent. Parallelism payoff triggers on a small fraction of tasks; the cost (description-matching noise, heavier `/team` protocol, more drift surface) is paid every turn.

**Fix.** Single cross-area `<prefix>-maintainer`. For genuine parallelism, batch multiple `Agent` calls in one assistant message. **Reversal criterion.** Sustained pattern of branches spanning ≥3 disjoint areas in a single PR.

---

### E. Skill with no applicability content (primitive firing wrongly)

**Symptom.** `SKILL.md` with frontmatter that matches a techstack, but `references/` is empty or contains a single pointer to `.claude/refs/`. Skill loads on description match and the agent reads nothing actionable.

**Evidence.** `production-repo-B/.claude/docs/claude-architecture.md:138-141`; `production-repo-C/.claude/docs/claude-architecture.md:122-124` - "skills with no applicability content fire wrongly and confuse the agent."

**Fix.** Don't preempt. Defer the skill until there's real content. Legitimate exception: a primitive sister skill existing **only to legitimise a `.claude/refs/<contract>.md`** (repo-B's `<prefix>-api` owns `proto-contract.md`). Record as deliberate decision in §"Skill split" with reversal criterion.

---

### F. Domain auditor without incident justification

**Symptom.** `<prefix>-<domain>-auditor` agent added because "this surface looks risky", with no recorded incident or threat-surface change.

**Evidence.** `production-repo-B/.claude/docs/claude-architecture.md:148-152`; `production-repo-C/.claude/docs/claude-architecture.md:130` - "no recent incident has cost enough to warrant a dedicated read-only pass."

**Fix.** Defer until incident or documented threat-surface change. Record candidate in §"Rejected alternatives" with reversal criterion. repo-A's `<prefix>-security-auditor` is the precedent for justified (native crypto FFI, key-exchange primitives, row-level security, push-payload confidentiality - real adversarial surface).

---

### G. `dart_fix` running project-wide and bulldozing user WIP

**Symptom.** Agent diffs show changes far outside stated scope - trailing commas flipped on hundreds of files, `prefer_const_*` cascades, `unnecessary_this` removals across untouched packages.

**Evidence.** `production-repo-B/.claude/agents/<prefix>-maintainer.md:38-46` - "do NOT run `mcp__<prefix>-dart__dart_fix` as a mandatory step." `<prefix>-reviewer.md:42-44` - "project-wide `dart_fix` ran → **BLOCKER**."

**Fix.** Maintainer rule: `dart_format` on `files_touched` ONLY; never project-wide `dart_fix`. If you genuinely need auto-fix, invoke on a **single specific file** from `files_touched` and review the diff. Reviewer rule: project-wide `dart_fix` is a **BLOCKER**, not a warning.

---

### H. Worktree edits silently no-op

**Symptom.** Agent edits Dart files in a worktree. Analyzer says "no issues". Hot reload doesn't show changes. Build keeps using the main repo's content.

**Evidence.** `production-repo-B/.claude/skills/<prefix>/references/worktree-gotchas.md:9-20` - a worktree shares `.git/` but has its own working tree; with no `.dart_tool/`, `dart analyze` walks **up** and resolves `package:<x>/…` to the **main repo's** copy.

**Fix.** Pre-flight before any non-trivial Dart edit in a worktree:

```bash
ls .dart_tool/package_config.json 2>/dev/null \
  && echo "OK - worktree has its own resolution" \
  || echo "BROKEN - worktree will read package:* from the main repo"
```

If BROKEN: bootstrap the worktree (`melos bootstrap` from its root) or do the work in the main repo. Bake the check into the master skill's `references/worktree-gotchas.md`.

---

### I. Stale `dart mcp-server` + `dart language-server` processes accumulating memory

**Symptom.** ~40GB+ resident memory by end of day. `ps aux | grep dart` shows multiple `dart mcp-server` / `dart language-server` processes with PPID 1 (orphaned).

**Evidence.** `production-repo-B/.claude/scripts/dart_mcp_setup.sh:4-10` - each Claude Code session spawns its own `dart mcp-server`, which spawns a `dart language-server` (~2.5GB). Clean `/exit` cascades them; crashes orphan to init and accumulate.

**Fix.** A `SessionStart` hook that (a) kills Claude top-level processes older than a threshold, (b) reaps orphaned `dart mcp-server` / `dart language-server` with `PPID == 1`, (c) warns to stderr when too many live sessions. Always exits 0. See repo-B's `dart_mcp_setup.sh` for the template.

---

### J. AI-comment cruft (prompt-referencing, task-referencing, review-thread-referencing comments)

**Symptom.** Comments like `// Added per user request for <TASK-ID>`, `// FIXME from the review feedback`, `// AI-generated layout for the new flow`.

**Evidence.** `production-repo-A/.claude/agents/<prefix>-maintainer.md:170-189`; `production-repo-B/.claude/agents/<prefix>-maintainer.md:144-164` - the core sentence verbatim in both maintainers: "if the comment wouldn't make sense to a reader who has never seen this conversation, PR, or review thread - delete it." The reviewer enforces it from the other side (`production-repo-B/.claude/agents/<prefix>-reviewer.md:45-48` classifies such comments as WARN).

**Fix.** Inline `//` for genuine WHY (subtle invariants, workarounds); `///` for public API doc; never for narrating WHAT or referencing the prompt. Reviewer rule: WARN-grade; strip before merge. Precommit-auditor surfaces these as COMMIT-FIX-FIRST when staged.

---

### K. Reviewer leakage from maintainer self-report

**Symptom.** Reviewer's report quotes maintainer's reasoning ("the maintainer mentioned this was intentional because…") instead of verifying from the diff. BLOCKER findings get downgraded because "the maintainer explained why".

**Evidence.** `production-repo-B/.claude/agents/<prefix>-maintainer.md:222-227` - "when `/<prefix>-implement` invokes the reviewer, it withholds this self-report on purpose - the reviewer must verify the diff from scratch."

**Fix.** `/<prefix>-implement` passes the reviewer only `files_touched`, `proposed_commit_message`, `baseline_analyze` - NOT the maintainer's warnings, observations, or reasoning. Maintainer rule: anything the reviewer needs to know goes into the code or a code comment, not a hint.

---

### L. Skill description firing on files the skill can't act on (router-in-disguise)

**Symptom.** Single skill description matches files across three or four techstacks. Agent loads the skill on a Kotlin file edit; skill is mostly Dart conventions; agent gets misleading context.

**Evidence.** `production-repo-B/.claude/docs/claude-architecture.md:122-126`; `production-repo-C/.claude/docs/claude-architecture.md:114-117` - "three techstacks share no real conventions; applicability scope becomes 'everywhere relevant' - a router-in-disguise."

**Fix.** Split by techstack. Each skill gets explicit positive + negative applicability; negative scope must name what's NOT covered (`NOT <area-backend>/ (Kotlin)`; `NOT functions/ (TS)`). Description matching now picks the right skill per file type.

---

### M. `CLAUDE.md` skill-table drifting from `.claude/`

**Symptom.** `CLAUDE.md` describes a skill/agent/command that doesn't exist under `.claude/`, or vice versa.

**Evidence.** `production-repo-A/.claude/agents/<prefix>-precommit-auditor.md:120-122` - "CLAUDE.md / `.claude/docs/` edits must keep CLAUDE.md internally consistent. Flag mismatches. **COMMIT-FIX-FIRST**."

**Fix.** Precommit-auditor checks CLAUDE.md internal consistency on staged diffs that touch `.claude/**/*.md` or `CLAUDE.md`. `<prefix>_skills_drift.sh` catches dead markdown links. Run `/<prefix>-audit-skills` periodically. Every `.claude/` artefact change ends with "and update `CLAUDE.md` inventory" - non-optional.

---

### N. Re-implementing primitives already provided by `CLAUDE.md`

**Symptom.** Thin SKILL.md files named after meta-concerns - `<prefix>-repo-map.md`, `<prefix>-build-verify.md`, `<prefix>-conventions-overview.md`. Content is mostly inventory tables.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:256-258` - "content thin and overlaps with `CLAUDE.md`. `CLAUDE.md` loads on every turn; the skill would only load on description match. Inlining makes it unconditionally available at lower context cost."

**Fix.** Inline into `CLAUDE.md` (Topology, Skills inventory, Common commands). `CLAUDE.md` stays tight by linking deep content to skills, not by hosting it.

---

### O. `PreToolUse` push-guard duplicating branch protection + permissions allowlist

**Symptom.** `.claude/scripts/<prefix>_git_push_guard.sh` registered as `PreToolUse` on `Bash`, parsing commands and blocking `git push`.

**Evidence.** `production-repo-B/.claude/docs/claude-architecture.md:108-113` - push protection delegated to (a) `permissions.allow` deliberately excluding `git push` (every push prompts), (b) GitHub branch protection on `master` / `staging`. A `PreToolUse` push-guard was removed as redundant.

**Fix.** Delete the `PreToolUse` push-guard. **Reintroduce only in a repo that has neither layer.** Canonical statement in [enforcement-hooks.md](enforcement-hooks.md).

---

### P. Assuming an MCP server that isn't installed

**Symptom.** Agent prompts reference `mcp__<server>__<tool>` calls; permissions allowlist has `mcp__<server>__*` entries; agent fallback tables list "MCP preferred / bash fallback" for a server the repo never declared in `.mcp.json`.

**Evidence.** `production-repo-C/.claude/docs/claude-architecture.md:147-152` - "listing permissions for a server that isn't installed pollutes the allowlist; agent prompts referencing absent tools confuse the model."

**Fix.** Pre-flight: before listing an MCP permission or referencing an MCP tool, verify the server is declared in `.mcp.json` or the user's MCP config. If absent, don't reference it. Reversal: when `mcp.json` lands the entry, wire MCP-preferred / bash-fallback throughout.

---

### Q. Release-playbook AGENT instead of release-playbook SKILL

**Symptom.** A write-capable `<prefix>-release-manager` agent with submodule tables, remote URLs, tag procedure, version-bump commands. Loads on every description match for "release"; invocations are once a month at best.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:235-237` - "release cadence is low. Agent cost is amortized over too few invocations. A playbook skill loads on demand, has the same information, and doesn't compete with domain skills for description matching."

**Fix.** Write a release-playbook **skill** (`<prefix>/references/release-playbook.md` or a sister skill if large). Loads on demand via description match on "release" + path context. **Reversal criterion.** Release cadence becomes weekly with a mechanical workflow.

---

### R. Slash-command wrapper around a single agent

**Symptom.** `.claude/commands/<prefix>-review.md` that does nothing except invoke `<prefix>-reviewer`. Or `/<prefix>-plan` invoking `<prefix>-architect` directly.

**Evidence.** `production-repo-A/.claude/docs/claude-architecture.md:249-251` - "the reviewer agent is the entire value; the wrapper adds a layer and splits context. Direct invocation by name gives subagent isolation with a clean context and no wrapper overhead."

**Fix.** Slash commands are for **orchestration** (multi-step, fan-out, conditional flow). For single-agent invocations, rely on description matching and `@<agent-name>`. **Reversal criterion.** Review routinely needs to fan out to multiple read-only specialists in parallel.

---

### S. Hook nudging at a primitive skill with no references

**Symptom.** A `case` branch in `<prefix>_quality_check.sh` that surfaces a skill name on path match, but the surfaced skill has no `references/` content - the agent reads `SKILL.md` ("see references for…") and finds nothing.

**Evidence.** `production-repo-B/.claude/docs/claude-architecture.md:170-178`; `production-repo-C/.claude/docs/claude-architecture.md:141-145` - "adding a nudge that points at 'no content yet' wastes a hook firing."

**Fix.** **≥2-references rule** for adding a path nudge (§5.1). Description matching alone handles primitives.

---

### T. Patterns describing what SHOULD-BE rather than what IS

**Symptom.** A pattern reference (`<topic>-pattern.md`) describing a convention the codebase doesn't yet follow. Agent reads it, writes code that fits the convention, diff doesn't match surrounding code, reviewer flags inconsistency.

**Evidence.** Blueprint `conventions/pattern-style.md:107-109` - "patterns describe what IS, not what should be. If the codebase doesn't yet follow the convention, this is a roadmap document, not a pattern. Move it to project memory until the migration lands."

**Fix.** A pattern ref describes the **current** shape. If you're mid-migration, the new shape lives in project memory ("when touching X, prefer the new pattern Y described in <PR-link>") until the migration is complete enough that the new shape is what the agent will encounter. Then the ref graduates.

---

### U. Cheatsheets going stale and being worse than missing

**Symptom.** `<topic>-cheatsheet.md` with entries that no longer exist (renamed, retired) or missing entries for recent additions. Agent reads it, reaches for a retired component, re-introduces dead code.

**Evidence.** Blueprint `conventions/cheatsheet-style.md:114-118` - "stale entries are worse than missing entries. When the codebase changes, the cheat-sheet has to follow on the same PR."

**Fix.** **Same-PR discipline.** Component/token rename PR updates source AND cheatsheet. Mark retired entries with `Deprecated` section pointing at the replacement. Precommit-auditor and reviewer flag cheatsheet drift when staged diff includes a touched file and the cheatsheet wasn't updated.

---

## How to scan for these symptoms

Bash one-liners for an audit pass. Run from repo root. These are heuristics, not verdicts - each hit is a prompt to read the linked precedent. (Symptoms I and K have no grep - they surface at runtime: I in the process table, K in reviewer transcripts.)

```bash
# A. Master skill references that look cross-cutting
ls .claude/skills/*/references/ \
  | grep -E "^(freezed|code-generation|components|tokens|imports|formatting|strict-analysis|dependencies|release|design-system)\.md$"

# B. References documenting deterministic tool output
grep -rl "dart format\|dart fix\|analyzer\|utopia_lints" .claude/skills/*/references/

# C. Eng-manager / hygiene-style agent files
ls .claude/agents/ | grep -iE "(eng-manager|doc-auditor|hygiene|skills-auditor|layer-auditor)"

# D. Per-area maintainer files
ls .claude/agents/*-maintainer.md 2>/dev/null | wc -l   # expect 1; >1 is per-area

# E. Primitive skills (no references content)
for s in .claude/skills/*/; do
  refs=$(find "$s/references" -name '*.md' 2>/dev/null | wc -l)
  [ "$refs" -lt 1 ] && echo "PRIMITIVE: $s ($refs refs)"
done

# F. Domain auditors without §"Agent roster" justification
ls .claude/agents/*-auditor.md \
  | grep -v "precommit-auditor" \
  | while read a; do
      name=$(basename "$a" .md)
      grep -q "$name" .claude/docs/claude-architecture.md \
        || echo "UNDOCUMENTED auditor: $a"
    done

# G. dart_fix usage in agent prompts (warn/block grade)
grep -rn "dart_fix" .claude/agents/

# H. Worktree gotcha guidance present in master skill?
find .claude/skills/*/references -name "worktree*.md"

# J. AI-cruft comments in source (project-specific paths)
grep -rnE "(per user request|review feedback|AI-generated|FIXME from|TODO\(self\))" lib/ packages/ 2>/dev/null

# L. Skill description likely over-broad (heuristic)
grep -A8 "^description:" .claude/skills/*/SKILL.md \
  | grep -iE "everywhere|cross-cutting|all repo|shared|any file"

# M. CLAUDE.md ↔ .claude/ drift (skill names mismatch)
diff <(ls .claude/skills/) <(grep -oE '`[a-z]+-[a-z]+`' CLAUDE.md | sort -u)

# N. Thin overlapping-with-CLAUDE.md skills
for s in .claude/skills/*-repo-map .claude/skills/*-build-verify \
         .claude/skills/*-overview .claude/skills/*-faq; do
  [ -d "$s" ] && echo "Candidate for CLAUDE.md inlining: $s"
done

# O. PreToolUse push-guard hooks
grep -rnE "PreToolUse.*push|push.*PreToolUse|git_push_guard" .claude/

# P. MCP tools referenced but server not declared
grep -rohE "mcp__[a-z][a-z0-9_-]+" .claude/ \
  | sort -u \
  | while read server; do
      grep -q "$server" .mcp.json ~/.claude.json 2>/dev/null \
        || echo "MCP referenced but not declared: $server"
    done

# Q. Release-playbook agent (vs skill)
ls .claude/agents/ | grep -iE "release-(manager|playbook|coordinator)"

# R. Slash-command files that look like single-agent wrappers
for c in .claude/commands/*.md; do
  body=$(grep -v '^---' "$c" | wc -l)
  agent_calls=$(grep -cE "^@|invoke|run agent" "$c" 2>/dev/null)
  [ "$body" -lt 30 ] && [ "$agent_calls" -ge 1 ] && echo "Thin command: $c"
done

# S. Hook nudges pointing at primitive skills
grep -nE 'echo.*<prefix>-[a-z-]+' .claude/scripts/*_quality_check.sh

# T. Patterns describing roadmap shapes (heuristic - future tense)
grep -rnE "we will|should|going to|migration|in progress" .claude/skills/*/references/*-pattern.md

# U. Cheatsheets with no recent edits
for cs in .claude/skills/*/references/*cheatsheet*.md; do
  age_days=$(( ($(date +%s) - $(stat -f%m "$cs" 2>/dev/null || stat -c%Y "$cs")) / 86400 ))
  [ "$age_days" -gt 60 ] && echo "$cs has been $age_days days untouched - verify against codebase"
done
```

---

## Meta anti-patterns (about applying this file)

### Treating one of these symptoms as "always wrong"

Most symptoms are wrong-by-default with explicit reversal criteria. repo-A **did** add `<prefix>-security-auditor` (F reversed); repo-A **does** maintain a release playbook as a *skill* (Q non-reversed). Read the linked entry.

### Removing a §"Rejected alternatives" entry because "we've confirmed it's wrong"

The entry IS the prevention. **Fix.** When an entry is still "no", strengthen the case-against with new evidence. When flipped to "yes", update in place (append "Flipped (date)" + cross-link). Never delete.

### Adding a hypothetical to the catalogue

Every entry in Part II quotes a real precedent - drift that actually happened, with file:line evidence. "I bet this could go wrong if…" entries dilute the signal. **Fix.** Only add a new entry when a real precedent exists - your own repo's history counts.

### Treating the catalogue as exhaustive

Drift happens in new shapes. This catalogue lists what's been observed. When you spot a new mode, record it as a §"Rejected alternatives" entry in your own `claude-architecture.md` - eventually it lands here.

### Splitting / deleting / collapsing a skill without a `claude-architecture.md` update

A new SKILL.md appears, references move, agent frontmatter updates - but §"Skill split" still shows the old shape. Future-you re-proposes the merge and finds no recorded reasoning. **Fix.** Every operation lands in the same PR that updates the architecture doc.

### Adding a path nudge that doesn't match the skill's applicability

The hook fires on a path; the surfaced skill's description doesn't actually match those files; the agent reads conventions that don't apply. Silent mis-fire - worse than no nudge. **Fix.** Before adding, verify the surfaced skill's positive applicability includes the path pattern.

### Updating an agent's role contract instead of its invariants

An architect that "now also implements small fixes" breaks the read-only-planner posture; a maintainer that "reviews its own work before hand-off" leaks reasoning into the reviewer's input. **Fix.** New behaviour goes into the Invariants list. If the behaviour requires a different posture, you're adding a new agent - use §6 first.

### Treating the architecture doc as write-once

`claude-architecture.md` is a **living** document. If you've done three operations this month and the doc hasn't been touched, something is undocumented. **Fix.** Operations 2–9 all end with "update `claude-architecture.md`" - non-optional.

### Letting `.claude/refs/` and `references/` content drift apart

If `.claude/refs/freezed.md` and `<prefix>/references/freezed.md` both exist (or contradict each other), the agent doesn't know which binds. **Fix.** One canonical location per topic. ≥2 consumers → refs/. 1 consumer → that skill's references/.

---

## Self-audit checklist (run after any operation)

1. Did `.claude/docs/claude-architecture.md` get an update reflecting the change?
2. Did `CLAUDE.md` get updates to inventory tables matching what's in `.claude/` now?
3. Did the relevant `SKILL.md`(s) update their Problem→reference and References tables?
4. Did agent `skills:` frontmatter get updated where preloading changed?
5. Did path nudges in `<prefix>_quality_check.sh` get updated/added/removed to match the new shape?
6. Did `<prefix>_skills_drift.sh --all` (or `/<prefix>-audit-skills`) come back clean?
7. If a previously-rejected alternative was reversed, did the entry get flipped in place (not deleted)?
8. If a previously-applied decision was reversed, did a fresh §"Rejected alternatives" entry capture the experiment?
9. Did a throwaway edit confirm the firing surface (description match + path nudge) actually loads what you intended?

---

## See also

- [layer-model.md](layer-model.md) - foundation vs project; `.claude/refs/` vs `.claude/docs/` discipline
- [agent-roster.md](agent-roster.md) - the four standard agents; when to extend
- [skill-design.md](skill-design.md) - applicability scopes, no-router, the three reference styles, split criteria
- [enforcement-hooks.md](enforcement-hooks.md) - `<prefix>_quality_check.sh` shape, path-nudge contract, SessionStart hooks
- [slash-commands.md](slash-commands.md) - orchestration vs wrapper test
- [architecture-doc.md](architecture-doc.md) - 9-section spine; rejected-alternative 4-field shape
- [claude-md.md](claude-md.md) - what stays in `CLAUDE.md` vs graduates
- [bootstrap-procedure.md](bootstrap-procedure.md) - creating the layer from scratch
- Source documents (the precedent corpus):
  - `production-repo-A/.claude/docs/claude-architecture.md`
  - `production-repo-B/.claude/docs/claude-architecture.md`
  - `production-repo-C/.claude/docs/claude-architecture.md`
  - `production-repo-A/.claude/agents/<prefix>-maintainer.md`
  - `production-repo-B/.claude/agents/<prefix>-maintainer.md`
  - `production-repo-B/.claude/agents/<prefix>-reviewer.md`
  - `production-repo-B/.claude/scripts/dart_mcp_setup.sh`
  - `production-repo-B/.claude/skills/<prefix>/references/worktree-gotchas.md`
  - blueprint `conventions/pattern-style.md`, `conventions/cheatsheet-style.md`
