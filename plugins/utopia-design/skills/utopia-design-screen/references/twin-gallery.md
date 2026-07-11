# The HTML Twin as a Design Input

## What this covers

The packaged HTML twin (`twin/` in the resolved `utopia_ui` package) as both a design
input in its own right and a visual reference while mapping a design element to a
manifest id. The structural contract documented here matches the shipped files; for a
specific component's actual rendered appearance, the shipped files themselves are the
truth - see "Reading specimen specifics" at the end of this doc.

## Status note: shipped

The real twin files ship in the `utopia_ui` package: `components.html` covers all 32
manifest ids (styled specimens for the tier-1 sixteen, explicit "no visual twin" /
deferred note entries for the rest), `gallery.html` carries the 11 example-app sections,
`components.css` is `var(--utopia-*)`-only, and `validate_twin` passes with zero
findings. The structural contract below matches the shipped files exactly - and the
files themselves, read from the resolved package root, are always the final truth for
any specific specimen's markup or CSS.

## The bundle

The bundle contract (`protocol/SPEC.md` 4.1/4.4; matches the shipped files):

> twin/ bundle: tokens.css + tokens.tailwind.css (both GENERATED - never edit),
> components.css (hand-authored, token-driven), components.html, gallery.html,
> DESIGN.md. Static HTML/CSS + minimal vanilla JS, no build step - files open directly
> in a browser.

For this skill's purposes: `tokens.css` / `tokens.tailwind.css` and `DESIGN.md`'s front
matter are **utopia-design-sync**'s regenerated output, never a structure source (there
are no components in a token document); `components.css` and `components.html` /
`gallery.html` are the parts this skill actually reads. Nothing in the bundle requires a
build step - if a twin needs viewing, open the file directly.

## `components.html` structure

The contract (matches the shipped files):

> components.html: one `<section data-utopia-id="<manifest id>">` per manifest
> component, in manifest order; inside, specimen roots ALSO carry data-utopia-id (e.g.
> `<button class="utopia-button" data-utopia-id="button">`). Components without a visual
> twin carry an explicit "no visual twin: <reason>" note element with the same
> data-utopia-id (so id coverage is 100% both directions - validate_twin enforces).

Two `data-utopia-id` occurrences per component, not one: the section wrapper, and the
specimen root inside it. Both always carry the *same* id - this is what lets
`validate_twin` check coverage in both directions (SPEC.md 4.4): every manifest id has a
twin section, and every twin section's id resolves to a real manifest component.

"In manifest order" is a real, checkable ordering - as of `packageVersion 0.1.0` (32
components) it runs: `button`, `card`, `check-row`, `chip`, `chip-list`, `collapsible`,
`confirm-dialog`, `copyable-text`, `date-picker`, `dialog`, `divider`, `dropdown-field`,
`field-wrapper`, `form-layout`, `gradient-background`, `labeled-field`, `loader`,
`mock-loading-box`, `multi-widget`, `overlay-anchor`, `page-wrapper`,
`remove-icon-button`, `search-field`, `sidebar`, `switch`, `switch-field`, `table`,
`table-empty`, `table-search-panel`, `text-field`, `three-bounce`, `title`.

## No-visual-twin note entries

Not every manifest component renders visible chrome of its own. SPEC.md 4.4 names
`multi-widget` as exactly this case - `UtopiaMultiWidget` "builds multiple nested
widgets from a flat list, innermost last": a pure composition helper with no rendered
surface to specimen. Components like this still get a `components.html` section (same
`data-utopia-id`, so coverage stays 100% both directions), but the section holds a
"no visual twin: <reason>" note instead of a styled specimen - `multi-widget` would read
something like "no visual twin: pure composition helper, renders no chrome of its own."
**Never assume a section has a styled specimen** - always check for the note-entry case
before treating a twin section as a rendering reference.

## CSS naming

The contract (matches the shipped files):

> CSS class naming: `.utopia-<id>`, modifiers `.utopia-<id>--<variant>` (e.g.
> --dense), state classes `.is-loading`, `.is-disabled`. All visual values via
> var(--utopia-*) per SPEC 4.2 naming.

`--utopia-*` custom property naming itself (the token-path-to-CSS-var derivation, the
typography composite expansion, the `textStyle-colors` fold) is fully specified in
`protocol/SPEC.md` section 4.2 - not re-derived here; that section is the single source
of truth for it. What matters for this skill: a specimen's classes tell you its variant
and state (`.utopia-button--dense`, `.is-loading`), and every value inside
`components.css` traces to a `var(--utopia-*)` reference, never a raw literal (the
literals linter in `validate_twin`, SPEC.md 4.5, enforces this on the authoring side -
not this skill's concern to run, just to know it exists when reading `components.css`).

## `gallery.html`

The contract (matches the shipped files):

> gallery.html mirrors example/lib/sections/* one-to-one, same order as the example
> components page: table, fields, buttons, selection, chips-text, dialogs, sidebar,
> loading, colors, typography, surfaces (11 sections); each section comments which
> example file it mirrors.

Use `gallery.html` when the reference point is "how does the example app arrange these
components together" rather than "what does one component's specimen look like in
isolation" (that's `components.html`'s job).

## Tier-1 specimens

The components with styled specimens today: `button`, `text-field`,
`search-field`, `labeled-field`, `card`, `chip`, `chip-list`, table shell (`table`),
`sidebar`, `dialog`, `confirm-dialog`, `switch`, `check-row`, `divider`, `loader`,
`title` - 16 components. Every other manifest id is covered by a note entry (the styled
tier-2 long tail is a deliberate deferral, not an omission - coverage stays 100% both
ways either way).

## The rule

Reference the twin by `data-utopia-id`, and never assume a component has a styled
specimen - always check for the note-entry case first. Today that check has a concrete
answer: everything outside the tier-1 list above IS a note entry (the tier-2 styled
long tail is deliberately deferred), so for those components the twin tells you the id
exists and why it has no specimen - the manifest entry, not the twin, is your
construction reference.

## Reading specimen specifics (shipped files are the truth)

For anything about a specific specimen - its exact markup, class list, or CSS - read the
shipped files directly from the resolved package root (`<utopia_ui root>/twin/`, same
resolution as [component-mapping.md](component-mapping.md) uses for the manifest). This
doc deliberately does not inline specimen markup: the files are versioned with the
package and would drift out of any copy here. Screenshot-based visual comparison between
the twin and the Flutter example app is the library's own release gate, not this
skill's concern.

## See also

- [design-inputs.md](design-inputs.md) - the twin gallery's place among other design
  input types
- [component-mapping.md](component-mapping.md) - what a twin-derived element resolves
  to once its `data-utopia-id` is known
- **utopia-design-sync** - regenerates `tokens.css` / `tokens.tailwind.css` / the
  `DESIGN.md` front matter inside the same bundle; not this skill's concern
