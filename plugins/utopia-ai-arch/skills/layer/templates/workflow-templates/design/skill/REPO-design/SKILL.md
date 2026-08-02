---
name: <prefix>-design
description: >
  Design-to-code workflow. Fires when using <design-tool> MCP tools
  (get_jsx, get_tree_summary, get_screenshot, etc.), processing a
  claude.design handoff bundle (.claude-handoff/ directory, PROMPT.md), or
  when asked to "translate a design", "implement this mockup", or
  "build from design". Provides design-source reading knowledge; defers
  component selection to the master skill and state/hook patterns to the
  utopia-hooks plugin.
---

<!-- BLUEPRINT - adapt per-repo. Workflow-style skill paired with the REPO-design.md command. Open only if Phase 0.4 confirmed design-tool integration. Substitute <prefix> tokens. Strip this banner after substitution. -->

# <prefix>-design

Workflow-style skill - format intentionally diverges from the
module / pattern / cheatsheet trichotomy that skill-design.md prescribes
for project reference docs. Knowledge is organised around
**sources / acquisition / translation steps**, because the value is in
sequencing the design-acquisition tools and mapping the result onto the
repo's component vocabulary.

Design acquisition and translation workflow. This skill knows how to **read
designs from external tools**; the actual implementation knowledge lives in
the repo's master skill (component vocabulary, design tokens) and
`utopia-hooks` (Screen/State/View, hooks, async).

For repo topology, environments, and the skills inventory see the always-on
[`CLAUDE.md`](../../../CLAUDE.md).

## Relationship to other skills

| Concern | Owner |
|---------|-------|
| Screen/State/View, hooks, async, DI | `utopia-hooks` plugin |
| Component vocabulary, tokens, services, models | `<prefix>` master skill |
| Design source reading, acquisition workflow | **<prefix>-design** (this skill) |
| Full orchestration (plan→code→review) | `/<prefix>-design` command |

## Design sources

Two supported sources:

- **<design-tool>** - live MCP connection. Tools:
  `mcp__paper__get_basic_info`, `get_tree_summary`, `get_screenshot`,
  `get_jsx`, `get_selection`, `get_computed_styles`, `get_fill_image`,
  `get_font_family_info`.
- **claude.design** - handoff bundle export. Structure:
  `.claude-handoff/` directory with `PROMPT.md` (designer intent), `tokens/`
  (token definitions), `components/` (component structure), `assets/`
  (referenced images / icons).

If the team uses Figma exports instead, the bundle structure differs but
the principles are the same - read tokens, read components, compile a brief.

## When this skill fires

- <design-tool> MCP tools are in use (`get_jsx`, `get_tree_summary`, etc.).
- A handoff bundle is present (`.claude-handoff/` directory, `PROMPT.md`
  from claude.design).
- User asks to "translate design", "implement this mockup", "build from
  design", or equivalent in the team's language.

## Output depth

Infer from the design scope; the user can always override.

| Design scope | Output | Files |
|--------------|--------|-------|
| Single component (card, button group, list item) | `StatelessWidget` | Widget file only |
| Full page layout, state trivial or external | View only | `_view.dart` |
| Full feature page with interactions | Screen/State/View | `_screen.dart` + `_state.dart` + `_view.dart` |
| Modal / dialog | Dialog + optional state | Dialog file (+ state if form) |

## Translation workflow

1. **Acquire** - read the design using the appropriate source workflow
   (<design-tool> tools, or `ls` + `Read` over the handoff bundle).
2. **Visual reference** - always get a screenshot or visual first for
   context. Without it, naming and layout intent are guesses.
3. **Identify structure** - page type? Sections? Cards? Tables? Navigation?
   What's repeatable, what's bespoke?
4. **Map to the repo's component vocabulary** - consult the master skill's
   component catalogue / cheatsheet. **Reuse existing components**; don't
   reinvent.
5. **Use design tokens** - the repo's token primitives (colors, spacing,
   typography). No raw hex colors, no raw px spacing, no raw font
   definitions.
6. **Flag gaps** - design elements without a component equivalent must be
   listed explicitly with a recommendation: raw Flutter widget, propose
   new component, or approximate with an existing one.
7. **Generate code** - at the correct depth, following master-skill +
   `utopia-hooks` conventions.

## <design-tool> acquisition

Standard sequence:

```
1. get_basic_info          → file name, artboards, dimensions
2. get_tree_summary        → full hierarchy of the target artboard/node
3. get_screenshot          → visual reference (save as context)
4. get_jsx                 → JSX + Tailwind code representation
5. get_computed_styles     → exact values for spot-checks
6. Compile into design brief
```

If the user has selected specific nodes in <design-tool>, use `get_selection`
first instead of `get_tree_summary`.

For typography work, call `get_font_family_info` before any styling so the
mapping to the design system's font tokens is accurate.

For image fills, `get_fill_image` returns the actual asset - copy into
`assets/` and reference via the repo's image-loading convention.

## claude.design acquisition

Standard sequence:

```
1. ls <bundle path>        → inventory what's in the bundle
2. Read PROMPT.md          → designer intent, hierarchy, instructions
3. Read tokens/            → design token definitions
4. Read components/        → component structure
5. List assets/            → referenced assets
6. Compile into design brief
```

## Design brief format

Compile the acquired design into a structured brief - this is what gets
passed into the architect and maintainer prompts in the
`/<prefix>-design` command:

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

## Rules

- Always consult the repo's component catalogue before writing custom
  widgets.
- Always use design tokens - no raw hex colors, px spacing, or font
  definitions.
- Flag gaps explicitly - never silently drop design elements or use raw
  widgets without calling it out.
- Buttons use theme variants from the design system, not direct color
  overrides.
- Full pages follow the master skill's layout primitives (responsive page
  wrappers, sliver-based scrolling if that's the convention).
- Full screens follow Screen/State/View from `utopia-hooks`.

## See also

- Sister skill: the repo's master skill - component vocabulary, design
  tokens, services, models. The primary source of component knowledge.
- Orchestration: [`/<prefix>-design`](../../commands/<prefix>-design.md) -
  full design→code pipeline with architect, maintainer, and reviewer.
- `utopia-hooks` plugin - Screen/State/View, hooks, async patterns.
- Always-on context: [`CLAUDE.md`](../../../CLAUDE.md).
