# Import Sources

## How to use this

Four external source types are supported. This doc covers what each looks
like on disk, where its values live, and how to extract them - stop here,
before any name matching. Turning what you extracted into edits against the
closed utopia tree is [mapping.md](mapping.md)'s job, not this one.

## Figma DTCG export

- **What it looks like:** a JSON file conforming to the same DTCG format
  module `design/tokens.json` itself uses, but produced by a Figma
  variables-to-DTCG export. Group names, nesting, and modes are Figma's own
  - they will not match the utopia tree's paths. It may carry foreign
  `$extensions` metadata (variable ids, collection, mode) alongside standard
  `$type`/`$value` per token; the exact key varies by exporter (SPEC.md uses
  `com.figma.*` as its illustrative vendor-namespace example, while e.g. the
  Figma Console MCP tool stamps the literal key `figma-console-mcp`).
- **Where the values live:** standard DTCG `$value` per token, nested under
  Figma's own group hierarchy rather than utopia's.
- **How to extract:** read it as a plain DTCG document (the same parsing
  habits as `design/tokens.json`). The challenge is never the format - it's
  that names don't line up with the utopia tree at all; every path needs
  explicit mapping (-> [mapping.md](mapping.md)).
- **Format notes:** preserve whatever foreign `$extensions` namespace is
  present, untouched - DTCG's round-trip rule plus the vendor-namespace
  clause (SPEC.md sections 2.1, 2.6). When a Figma variable id is present
  in such a namespace, it is a good
  candidate for the `sourceRef` recorded on apply (-> the tokens skill's
  edit loop), since it stays stable across re-exports of the same variable.
  There is no Figma write-API integration in v0 - this file-export path is
  the only supported way Figma data enters the protocol.

## Foreign tokens.css / Tailwind @theme

- **What it looks like:** a plain CSS file with `:root { --name: value; }`
  custom-property declarations, or a Tailwind v4 file with an `@theme { }`
  block.
- **Where the values live:** the custom-property declarations themselves;
  values are raw CSS - hex/rgb colors, `px` dimensions, `ms` durations, bare
  numbers for font weight, `box-shadow` strings.
- **How to extract:**
  - If the variables are already `--utopia-*` (i.e. this is a re-export of
    utopia's own generated twin, not a genuinely foreign file), use the
    SPEC.md section 4.2 reverse mapping: `--utopia-<path-kebab>` resolves
    directly back to the dotted path (`--utopia-spacing-md` ->
    `spacing.md`), with the special case
    `--utopia-text-style-<role>-color` -> `textStyle-colors.<role>` (not
    `textStyle-colors-<role>`, because the sibling color group folds into
    the typography prefix).
  - If the variables use a foreign naming scheme (a designer's own
    `tokens.css`, unrelated or absent prefix), there's no shortcut - match
    by role/semantics (-> [mapping.md](mapping.md)).
  - A Tailwind `@theme` block's namespaces follow SPEC.md section 4.3:
    `--color-*`, `--spacing-*`, `--radius-*`, `--shadow-*`,
    `--font-weight-*`, `--breakpoint-*`, and `--font-<role>` (typography
    family only). Special case: a `textStyle` color folds into the color
    namespace as `--color-text-style-<role>` -> `textStyle-colors.<role>`
    (NOT a `color.*` entry), mirroring the CSS-var special case above.
    `duration`, `border`, `theme.*` and `x` have no stable Tailwind
    namespace - if present at all they show up as comments and still need
    role-based mapping.
- **Format notes:** a `box-shadow` string parses into the shadow array form
  (`offsetX`/`offsetY`/`blur`/`spread`/`color`, SPEC.md section 2.3); a bare
  font-weight number maps straight to `fontWeight`. A CSS `box-shadow` can
  carry multiple comma-separated layers - each becomes one element of the
  shadow array - so split on TOP-LEVEL commas only; a naive comma split
  breaks inside `rgb(0 0 0 / 0.05)` / `rgba(...)` color arguments.

## Claude Design / claude.design handoff bundle

- **What it looks like:** a DIRECTORY, not a single file. Claude Design is a
  legitimate source-type name here, not an attribution note - treat it like
  any other named external tool. Don't assume one fixed internal schema
  beyond: it typically holds a tokens file (DTCG or CSS - handle via the two
  source types above) and/or a `DESIGN.md`, plus asset files.
- **Where the values live:** inside whichever tokens/CSS file and/or
  `DESIGN.md` the directory actually contains.
- **How to extract:** list the directory first to inventory what's actually
  present, then parse whichever of (tokens file, `DESIGN.md`) exists using
  the matching source-type handling above. Do not invent a bundle schema
  beyond what's actually on disk for this particular bundle.
- **Format notes:** asset files (images, icons) inside the bundle are out of
  scope for token import - they don't map onto `design/tokens.json`.

## DESIGN.md

- **What it looks like:** a markdown file with YAML front matter conforming
  to the [design.md spec](https://github.com/google-labs-code/design.md)
  (SPEC.md section 4.6): `name`, `colors`, `typography`, `rounded`,
  `spacing` keys, followed by the eight canonical prose sections.
- **Where the values live:** the YAML front matter block only. The prose
  sections (Overview, Colors, Typography, Layout, Elevation & Depth,
  Shapes, Components, Do's and Don'ts) are descriptive context, never a
  source of values to map.
- **How to extract:** parse the front matter; `colors` maps toward
  `color.*`, `typography` toward `textStyle.*` (plus its
  `textStyle-colors.*` sibling), `rounded` toward `radius.*`, `spacing`
  toward `spacing.*` (-> [mapping.md](mapping.md) for the exact role
  matching).
- **Format notes:** on the utopia side, `twin/DESIGN.md`'s own front matter
  is GENERATED from tokens (SPEC.md section 4.6) - when importing a foreign
  `DESIGN.md`, its front matter is the value source exactly the same way;
  its prose is never parsed for values.

## See also

- [mapping.md](mapping.md) - the closed-tree mapping rules these extracted
  values feed into
- [three-way-diff.md](three-way-diff.md) - the proposal, diff, and re-import
  conflict model that follows mapping
