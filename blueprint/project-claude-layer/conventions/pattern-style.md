# `*-pattern.md` — cross-cutting convention style

Use this style for **technical conventions that span features** —
naming rules, model shape, service taxonomy, layout idioms, code-gen
contracts. The defining property: there is no product story to tell.
The convention exists because the code is shaped this way, and an
agent needs to know it to write code that fits.

If the content has a product story (a user flow, a business
intent), use `*-module.md` instead. If it's a flat lookup
(component catalogue, color tokens, asset inventory), use
`*-cheatsheet.md` instead.

Common suffixes for this style: `*-pattern.md`, `*-system.md`,
`*-services.md`, `*-models.md`. They're interchangeable — pick the
one that reads best in the parent skill's reference table.

---

## Required sections

### `# <Pattern name>`

Noun phrase naming the convention (e.g. *Activity Pattern*,
*Crazy Design System*, *Flutter Services*, *Proto → Ext → Id → Ref*).

### `## What this pattern is`

1–2 sentences. The convention in plain language. *"All activities
follow a 3-letter code + 2-digit variant naming, with proto messages
under `proto/classroom/activity/`, base classes in `…/activity/base/`,
and registration in `…/activity_registry.dart`."*

If you can't summarise the pattern in two sentences, the document is
trying to be a module — switch styles.

### `## When this applies`

The path / surface where the pattern is enforced. Mirror the parent
skill's `applicability`, narrowed to this specific pattern. If the
pattern only applies in part of the skill's scope, say so explicitly
(`"only for activity widgets, not for assessment widgets"`).

### `## Rules`

The actual conventions, as a numbered list or table. Each rule is:

- **What** — the convention itself, stated as an instruction.
- **Why** — what would break or get inconsistent if it weren't
  followed (this is the load-bearing part — it lets the agent
  generalise to edge cases not explicitly covered).

Example:

> 1. **New activities use a 3-letter code + 2-digit variant.**
>    *Why:* the code identifies the activity across proto / Dart /
>    asset paths; the variant lets us iterate on UX without breaking
>    saved data. Ad-hoc names diverge between layers.

If the rules have natural sub-groups (naming, structure, lifecycle,
testing), use sub-headings.

### `## How to apply`

Concrete walk-through of "I'm adding a new <thing> — what do I do?".
Step-by-step, file paths, command names. This is the section that
turns the pattern from theory into action.

The bar: an agent following these steps should produce code that
looks like the existing code, without needing to read 20 files first.

---

## Optional sections

### `## Reference shapes`

Type signatures, base classes, registration entries — small
snippets that document the surface. Keep them short. If you find
yourself reproducing 50 lines of a base class, link to the source
file instead and quote only the signatures.

### `## Anti-patterns`

What NOT to do, with WHY. Same load-bearing principle as in modules.
Especially valuable for patterns where the wrong shape "compiles
fine but diverges from the codebase".

### `## See also`

Cross-links to related patterns or modules. Use sparingly — the
parent skill's `SKILL.md` is the routing hub; if this section gets
long, the link probably belongs there instead.

---

## Hard rules

- **Why-first for every rule.** A rule without a reason is
  cargo-cult. The agent needs the reason to handle edge cases.
- **No code blocks longer than ~15 lines.** Patterns are about
  shape, not implementation. If you need more, link to the canonical
  source file in the codebase.
- **Don't restate foundation conventions.** If `utopia-hooks` owns
  the rule (hook idioms, Screen/State/View, IList), reference it.
  This document is for project-specific conventions only.
- **Patterns describe what IS, not what should be.** If the codebase
  doesn't yet follow the convention, this is a roadmap document, not
  a pattern. Move it to project memory until the migration lands.
