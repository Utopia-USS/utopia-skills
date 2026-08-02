# .claude/refs/

AI-layer-level shared markdown - content too small to be a skill, with
no autonomous applicability, but consumed by 2+ skills.

Each `SKILL.md` that uses a file here links it explicitly in its
`## See also` section. The link must live in `SKILL.md` itself, not
buried in a reference - `SKILL.md` always loads when the skill
matches; references are doc-on-demand, so a cross-skill link buried
deeper is two hops away from visibility and gets lost.

This directory exists deliberately separate from `.claude/docs/`
(which holds the architecture decision log, authoring templates, and
other meta-documents that aren't loaded into agent context). Files
here are **content** consumed by skills; files in `.claude/docs/` are
**decisions about** the layer.

Both live under `.claude/` so the AI architecture is self-contained.
Repo-root `docs/` remains free for non-Claude project documentation
if needed; that surface is unrelated to this folder.

## When to put something here

- The content is consumed by 2+ skills (e.g. a cross-techstack proto
  contract referenced by both Flutter and backend skills).
- It's small enough that wrapping it in its own `SKILL.md` would be
  pure ceremony (no autonomous applicability scope).
- It changes rarely and serves as a passive lookup, not an active
  guide.

## When NOT to put something here

- It would naturally trigger autonomous loading via description
  match → it's a skill, not a ref.
- It's used by exactly one skill → put it in that skill's
  `references/`.
- It's a project-wide concern that should always be in context →
  put it in `CLAUDE.md`.
- It's a "shared dump" with no clear consumers → it doesn't belong
  anywhere yet; figure out who actually uses it first.

## Examples of what goes here

- `proto-naming-cheatsheet.md` - naming rules for proto fields,
  consumed by Flutter and backend skills when either side touches
  the contract layer.
- `freezed-snippets.md` - common Freezed shapes used by multiple
  skills, where reproducing them in each skill's references would
  duplicate.
- `env-config.md` - environment table (staging vs live) referenced
  by services, deployment, and admin skills.

## Discipline

This is the **only** location for cross-skill shared markdown.
The Claude Code meta-model has no global-references mechanism - this
folder is the project's convention for filling that gap, scoped to
the AI layer.
