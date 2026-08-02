---
title: Skill Design - Applicability, Splits, Reference Styles
impact: CRITICAL
tags: skills, applicability, scope, router, shared, references, module, pattern, cheatsheet, graduation
---

# Skill Design - Applicability, Splits, Reference Styles

## What this is

How to **design a project skill** that loads at the right time, on the right files, with the right depth. The discipline is built around three load-bearing prohibitions ("no router skill", "no cross-cutting shared skill", "no preempting primitive skills") and three reference styles (module / pattern / cheatsheet).

## When this applies

- Adding a new skill (`<prefix>-<area>/SKILL.md`)
- Splitting an existing master skill into a master + sister skill
- Deciding whether to write a `<feature>-module.md` ref, a `<topic>-pattern.md` ref, or a `<topic>-cheatsheet.md` ref
- Reviewing a SKILL.md whose `description:` is matching too broadly or too narrowly
- Graduating content from project memory → `references/<feature>-module.md` → its own skill (or vice versa)
- Authoring a `.claude/refs/<shared>.md`

## Rules

### 1. Every skill needs positive AND negative applicability.

The `description:` frontmatter is the only signal for auto-invocation. It must contain:

- **POSITIVE** - explicit paths / file types / surfaces where this skill applies
- **NEGATIVE** - explicit paths / surfaces where this skill explicitly does NOT apply (usually pointing to sister skills or `utopia-hooks`)

**Why.** Without negative scope, the skill description ends up "everywhere relevant" - a router-in-disguise that loads when the agent can't act on its content for the specific surface. Description matching fires the wrong skill, the agent reads conventions that don't apply, drift compounds.

> "Not 'cross-cutting' with no real applicability. A skill whose applicability is 'everywhere relevant' is a router skill in disguise. If you can't write a concrete positive+negative scope, the content doesn't belong in a skill." - blueprint README v1

**The test:** if you cannot write a one-sentence negative applicability, the skill is trying to be a router. Split or merge until each skill has a real boundary.

### 2. No router skill.

A "router skill" - one that points the agent to other skills - fails two ways: too broad (loads instead of the domain skill, leaves the agent with a map but no content) or too narrow (the inventory belongs in `CLAUDE.md`, which is always in context).

> "A 'router skill' would either fire too broadly … or too narrowly (in which case the inventory belongs in `CLAUDE.md`, which is always in context). Both cases lose to the three-mechanism split." - blueprint README v1

Routing is solved by three mechanisms working together:

1. **`CLAUDE.md`** - always loaded, the top-of-context inventory
2. **`<prefix>_quality_check.sh`** - deterministic path → skill nudge
3. **`description:` frontmatter** - probabilistic autonomous match

### 3. No cross-cutting "shared" skill.

A `<prefix>-shared/` skill is the same anti-pattern wearing different clothes. "Shared" is not an applicability scope - it's an admission the skill has no real one.

> "No `<repo>-shared/` skill. 'Shared' is not an applicability scope - it's an admission the skill has no real one. Such a skill loads at the wrong times and competes with the skills that consume it." - blueprint README v1

**Where shared content goes:** `.claude/refs/<shared-doc>.md` - passive markdown, only entered via "See also" links from each consuming SKILL.md.

### 4. Cross-link discipline - links live in `SKILL.md`, not in references.

> "A cross-link must live in `SKILL.md` itself, not deep inside a reference. `SKILL.md` always loads when the skill matches; references are doc-on-demand. A buried cross-link is two hops from visibility and gets lost." - blueprint README v1

Sections that may contain cross-skill or cross-refs links:

- `## References` (within this skill)
- `## See also` (cross-skill / `.claude/refs/`)

Never bury a cross-link three levels deep in a reference file.

### 5. Don't preempt with primitive skills.

A primitive skill = a SKILL.md with no `references/` content, opened just because a techstack exists.

> "Skills with no applicability content … fire wrongly and confuse the agent." - `production-repo-B/.claude/docs/claude-architecture.md:139-141`

**Exception:** open a primitive sister skill ONLY when:
- A distinct techstack lives in the repo
- AND there's a `.claude/refs/<contract>.md` that needs a logical owner (e.g. repo-B's `<prefix>-api` primitive existed primarily to legitimise `proto-contract.md`)

Otherwise defer until there's real content.

### 6. Split a skill out of the master WHEN:

- The audit / convention checklist applies under a **tighter description** than the engineering surface
- AND benefits from being preloaded alongside the master skill (not in competition)
- AND has ≥3 reference docs of audit-only material

**Precedent (DO split):** repo-A's `<prefix>` / `<prefix>-security` split - engineering surface vs adversarial audit. All agents preload both.

> "The audit checklist applies under a tighter description (confidentiality / integrity / RLS / push-payload contract) and benefits from being preloaded by all five agents alongside `<prefix>` + `utopia-hooks`, separately from the engineering surface." - `production-repo-A/.claude/docs/claude-architecture.md:127`

**Do NOT split** when the content is <3 refs or applies under the same description as the master. Keep it in `<master>/references/`.

### 7. Don't put cross-cutting Dart content inside the master skill's `references/`.

> "[`<prefix>`] was originally documented as the master skill that 'owns' Freezed / codegen / strict-analyzer / imports / design-system / dependencies / release coordination - but those concerns are not master-skill-specific, they apply to anyone authoring Dart in this repo. Keeping them inside `<prefix>/references/` made `<prefix>` look like an uber-skill that has to fire on every techstack." - `production-repo-A/.claude/docs/claude-architecture.md:126`

If two or more skills consume the same content, lift it to `.claude/refs/` and link from each consuming SKILL.md's See also.

### 8. Don't write a reference that repeats deterministic tool output.

`dart format`, `dart fix`, the analyzer, `utopia_lints` - these enforce mechanics. A reference titled "Imports and Formatting" or "Strict Analysis" that documents what the tool catches is a maintenance liability without payoff.

> "`imports-and-formatting.md` and `strict-analysis.md` were originally in this set, then deleted - `dart format` + `dart fix` + `utopia_lints` + the analyzer enforce the mechanics directly, so the refs were repeating tool output." - `production-repo-A/.claude/docs/claude-architecture.md:126`

## Reference styles (3-way split)

The distinguishing test, repeated in three places of the blueprint:

| Has a … | Use style | Filename suffix |
|---------|-----------|-----------------|
| user flow (someone *does* something step by step) | **module** | `<feature>-module.md` |
| rules with reasoning (no product story; the code is just shaped this way) | **pattern** | `<topic>-pattern.md` (or `-system.md`, `-services.md`, `-models.md`) |
| inventory, no rules and no flows | **cheatsheet** | `<topic>-cheatsheet.md` (or `-catalogue.md`, `-map.md`) |

### Module style (`<feature>-module.md`)

**Lead with user flow + business intent.** Not API documentation, not a code dump.

Required sections:
- `# <Module name>` (match user-visible feature name)
- `## Business intent` - 2–4 sentences: who/what/why
- `## User flow` - numbered, user-POV. Flag moments where **the system has to react** (persist, sync, handle offline, recover from crash, expire session)
- `## Location` - paths only
- `## Data hierarchy` - tree if nesting is meaningful, one line of business meaning per non-trivial entity
- `## Technical surface` - tables of services / screens / contracts / refs

Optional: `Session / sync`, `Conventions specific to this module`, `Open questions / WIP`, `Anti-patterns`.

Hard rules:
- No code blocks > ~10 lines
- No copy-paste from freezed / generated output
- Business intent leads, technical surface follows. Reversing this turns the doc into API docs.
- Modules graduate - when surface area outgrows a single reference (multiple sub-flows, its own patterns), it splits into its own skill.

### Pattern style (`<topic>-pattern.md`)

**Lead with technical surface.** No product story to tell. The convention exists because the code is shaped this way, and an agent needs to know it to write code that fits.

Required sections:
- `# <Pattern name>` (noun phrase)
- `## What this pattern is` (1–2 sentences; if you can't, it's trying to be a module)
- `## When this applies`
- `## Rules` - numbered or table. **Why-first for every rule.** A rule without a reason is cargo-cult; the agent needs the reason to handle edge cases.
- `## How to apply` - concrete walk-through; an agent following these steps should produce code that looks like the existing code

Optional: `Reference shapes`, `Anti-patterns`, `See also`.

Hard rules:
- No code blocks > ~15 lines
- Don't restate foundation conventions
- **Patterns describe what IS, not what should be.** If the codebase doesn't yet follow the convention, this is a roadmap document - move it to project memory until the migration lands.

### Cheatsheet style (`<topic>-cheatsheet.md`)

**The agent needs a map of what exists** so they reuse it instead of inventing it.

Required sections:
- `# <Catalogue name>`
- `## How to use this` (1–3 sentences; "this exists to steer the agent away from duplicating things that already exist")
- `## <Inventory tables>` - scannable in one read. Tables right, long prose wrong.
- `## When to add a new entry`

Optional: `Deprecated` (mark + point to replacement, "prevents the agent from 'discovering' old code and re-introducing it"); `See also`.

Hard rules:
- Tables, not prose
- No "how to write X" content (that's a pattern)
- No business / user-flow content (that's a module)
- One line per cell
- **Stale entries are worse than missing entries.** When the codebase changes, the cheatsheet follows on the same PR.

### Workflow-style skills - recognised exception to the trichotomy

Some skills are about **driving a tool / surface** end-to-end: browser automation (Chrome DevTools MCP, `preview_*`), a design MCP (`<design-tool>` / claude.design handoff), a vendored CMS submodule, a remote-deploy procedure. Their content is mostly procedural / how-to, not "what the code is shaped like" - and forcing them into the module / pattern / cheatsheet trichotomy distorts both the reference and the trichotomy.

**Precedent.** `browser-testing` exists as a top-level skill in all three production repos (repo-A, repo-B, repo-C). Its content is about driving the browser via MCP tools - not a user flow (no business intent), not a code-shape pattern (no Dart at all), not an inventory (it's procedural). It's a fourth shape.

**Rule.** When a skill's reference content is mostly tool-driving procedure:

- Use whatever section structure clarifies the procedure (Modes / Steps / Tool-by-tool / Recovery). Don't force a module or pattern shape.
- The filename suffix is descriptive: `<topic>-workflow.md`, `<topic>-procedure.md`, or just `<topic>.md` if there's only one reference.
- **Document the exception in `claude-architecture.md` §"Reference styles in use"** - explicitly note "skill X uses workflow-style references, not the standard trichotomy" with a one-line reason.
- The non-negotiables still apply: positive + negative applicability scope; no router behaviour; no foundation restatement; cross-link discipline.

**Anti-pattern.** Force-fitting a workflow into "module" because the trichotomy is canonical creates a module file with no business intent, no user flow, no data hierarchy - a shell of a module that confuses the agent about what to consult when.

**Two epistemic categories of workflow skills** (matters because the agent's decision procedure differs):

| Category | Examples | How agent decides to open |
|---|---|---|
| **Auto-inspectable** | `browser-testing` (web build presence), `<prefix>-deployment` (docker-compose presence), `<prefix>-cms` (vendored submodule presence) | Agent inspects repo for the signal, applies three-test (frequency / decision burden / recurrence). |
| **User-driven (workflow-template)** | `<prefix>-design` (`<design-tool>` / Figma / handoff), `<prefix>-ship` (Linear / `<ticketing-tool>` / Jira), `<prefix>-plan`, `<prefix>-team` | Agent CANNOT infer from repo state. Requires explicit user-prompt - see [bootstrap-procedure.md](bootstrap-procedure.md) §"0.4 External integrations". |

Both categories ship ready-to-copy bundles under [`../templates/workflow-templates/`](../templates/workflow-templates/). Bundles contain skill (where needed) + command (where needed) + a per-bundle README explaining when to open and what to substitute.

## Graduation gradient

Content matures along this gradient - reversible:

```
project memory (WIP vertical)
    ↓ vertical crystallises into a stable shape
references/<feature>-module.md (in the closest applicable skill)
    ↓ module grows beyond the skill's applicability
own skill (with explicit positive + negative scope)
    ↑ skill turned out to apply only to one area
collapses back into <feature>-module.md inside the consuming skill
```

See [evolution-and-drift.md](evolution-and-drift.md) for the trigger criteria and the mechanics of each step.

## SKILL.md canonical shape

```yaml
---
name: <prefix>-<area>
description: |
  <One-line WHEN-to-apply summary.>

  Applicability - POSITIVE: <paths / surface where this applies>.
  Applicability - NEGATIVE: NOT <paths / surface where this explicitly does NOT apply>.

  Layered on top of the upstream `utopia-hooks` plugin - this skill stays
  silent on hook idioms / Screen-State-View / async patterns / DI / IList
  / strict analyzer (those are foundation concerns).
---

# <prefix>-<area>

<One-paragraph framing referring back to the frontmatter applicability -
do NOT repeat it.>

## Relationship to the foundation

| utopia-hooks owns | This skill adds |
|-------------------|-----------------|
| Screen / State / View | <project concern A> |
| Hook catalog | <project concern B> |
| Async patterns | … |
| Global state, DI, IList/IMap/ISet, strict analyzer |  |

## Problem → reference mapping

| Task / question | Start with |
|-----------------|------------|
| <typical task A> | [<feature>-module.md](references/<feature>-module.md) |
| <typical task B> | [<topic>-pattern.md](references/<topic>-pattern.md) |
| <typical question C> | [<topic>-cheatsheet.md](references/<topic>-cheatsheet.md) |

## See also

- `.claude/refs/<shared-doc>.md` - <one line>
- Sister skill `<prefix>-<other-area>` - <one line>

## Non-negotiable

- <rules the hook can't enforce but agents must follow>

## References

| File | Style | Impact | Description |
|------|-------|--------|-------------|
| [<feature>-module.md](references/<feature>-module.md) | module | CRITICAL | <one line> |
| [<topic>-pattern.md](references/<topic>-pattern.md) | pattern | HIGH | <one line> |
| [<topic>-cheatsheet.md](references/<topic>-cheatsheet.md) | cheatsheet | MEDIUM | <one line> |

## Self-audit checklist

After editing files in this skill's applicability, verify:
- <repo-specific check 1>
- <repo-specific check 2>
- Static analysis clean.
```

### Optional sections in a mature SKILL.md

The canonical shape above is the **minimum** for a new skill. As the skill grows, production SKILL.md files commonly add:

- **`## Priority-Ordered Guidelines`** - a sorted table `Priority | Category | Impact | Reference` for **deterministic pruning under context pressure**. Impact ratings (CRITICAL / HIGH / MEDIUM) are user-curated and load-bearing. Once added, never overwrite ordering or ratings without explicit human approval. Precedent: `production-repo-B/.claude/skills/<prefix>/SKILL.md`, `utopia-hooks/SKILL.md`.
- **`## Quick Reference`** - pointer paragraphs for the 3-5 most-common entry points (one paragraph per top reference). Useful when a master skill grows past ~10 references.
- **`## Searching References`** - a grep code block listing distinctive symbol / hook names per reference, for fast lookup by an agent navigating unfamiliar territory.
- **`## Problem → reference mapping`** - task / question → starting reference. This is in the minimum shape too, but matures by listing 15-30 rows once the skill has real surface area.

These come from the master skill's maturity, not from bootstrap. A primitive sister skill should NOT preempt them.

## Anti-patterns

(Cross-layer symptoms - master swallowing cross-cutting refs, description firing on wrong files, `dart_fix` bulldoze in recommended commands - are in [evolution-and-drift.md](evolution-and-drift.md) §A, §L, §G. Below: skill-design-specific.)

### Description that says WHAT, not WHEN

❌ `description: "This skill teaches how to work with the app's domain flows."`
✅ `description: "Use when editing Flutter widgets / services / models in app/ or admin/ for domain flows, content, or design system. Stays silent on Kotlin backend/ and Next.js landing/."`

### Routing inventory inside a SKILL.md

`SKILL.md` containing only "Look at sister skill X for Y, sister skill Z for W" is a router. Put the inventory in `CLAUDE.md` (always loaded) or delete it.

### Reference style mismatch

A module file with no user flow is masquerading as a module - it's probably a pattern. A pattern file you can't summarise in two sentences is a module trying to be lean. A cheatsheet with paragraphs of prose is a pattern in disguise.

## See also

- [layer-model.md](layer-model.md) - foundation-vs-project boundary; `.claude/refs/` vs `.claude/docs/`
- [agent-roster.md](agent-roster.md) - `skills:` frontmatter preloading uses applicability scopes
- [enforcement-hooks.md](enforcement-hooks.md) - path nudges must match the skill's applicability exactly
- [evolution-and-drift.md](evolution-and-drift.md) - graduation triggers, splitting / collapsing a skill, deletion criteria; refs documenting tool output, primitive skills firing wrongly
- [architecture-doc.md](architecture-doc.md) - §"Skill split" table shape
- Inline reference-style authoring guides: [`../templates/conventions/module-style.md`](../templates/conventions/module-style.md), [`../templates/conventions/pattern-style.md`](../templates/conventions/pattern-style.md), [`../templates/conventions/cheatsheet-style.md`](../templates/conventions/cheatsheet-style.md) - link these from your repo's `claude-architecture.md` §3 by plugin name or GitHub URL; never copy them
- Inline SKILL.md template: [`../templates/claude-layer/skills/REPO-AREA/SKILL.md`](../templates/claude-layer/skills/REPO-AREA/SKILL.md)
