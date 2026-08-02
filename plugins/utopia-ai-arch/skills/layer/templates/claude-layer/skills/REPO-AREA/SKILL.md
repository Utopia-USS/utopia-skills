---
name: <repo>-<area>
description: |
  <One-line WHEN-to-apply summary.>

  Applicability - POSITIVE: <paths / surface where this applies>.
  Applicability - NEGATIVE: NOT <paths / surface where this explicitly does NOT apply>.

  Layered on top of the upstream `utopia-hooks` plugin - this skill stays
  silent on hook idioms / Screen-State-View / async patterns / DI / IList
  / strict analyzer (those are foundation concerns).
---

<!-- BLUEPRINT - adapt per-repo. Strip this banner after substitution.
     Authoring guides for references: utopia-ai-arch plugin,
     templates/conventions/{module,pattern,cheatsheet}-style.md - link from
     claude-architecture.md §3, never copy. -->

# <repo>-<area>

<One-paragraph framing: what this skill owns and why it has its own
applicability scope. Refer back to the `applicability` in the
frontmatter - do not repeat it here, reference it.>

## Relationship to the foundation

| utopia-hooks owns | This skill adds |
|---|---|
| Screen / State / View pattern | <project-specific concern A> ([<area>-<topic>.md](references/<area>-<topic>.md)) |
| Hook catalog | <project-specific concern B> ([<other-topic>.md](references/<other-topic>.md)) |
| Async patterns (download / upload / streams) | |
| Global state, DI bridge | |
| IList/IMap/ISet, strict analyzer, lambda style | |

## Problem → reference mapping

| Task / question | Start with |
|---|---|
| <typical question / task> | [<reference>.md](references/<reference>.md) |
| ... | ... |

## See also

Cross-skill links live here, not deep in references. Keep them in
this section so they're visible whenever this skill loads.

- Shared snippet: [`.claude/refs/<shared-doc>.md`](../../refs/<shared-doc>.md)
  - <one-line why this is consulted>
- Related skill: [`<repo>-<other-area>`](../<repo>-<other-area>/SKILL.md)
  - <one-line when to switch>

## Non-negotiable

- <Rule that the hook can't enforce but agents must follow.>
- <Another such rule.>

## References

| File | Style | Impact | Description |
|---|---|---|---|
| [<feature>-module.md](references/<feature>-module.md) | module | <CRITICAL/HIGH/MEDIUM> | <business feature with user flow> |
| [<area>-<topic>.md](references/<area>-<topic>.md) | pattern | <impact> | <cross-cutting convention> |
| [<area>-cheatsheet.md](references/<area>-cheatsheet.md) | cheatsheet | <impact> | <inventory / lookup map> |

## Self-audit checklist

After editing within this skill's applicability, verify:

1. <repo-specific check, e.g. naming, registration, code-gen freshness>
2. ...
3. Static analysis clean.
