# Reading Design Inputs for Structure

## What this covers

Four kinds of outside design input this skill builds screens from - an HTML
mockup/web page, a screenshot or image, a design handoff bundle directory, and a
`DESIGN.md` file - plus the packaged HTML twin gallery as a fifth, special case. For
each: what to read, and what to read it **for**. Turning what gets read into actual
constructor calls is [component-mapping.md](component-mapping.md)'s job; reporting
what doesn't map is [gap-reporting.md](gap-reporting.md)'s.

## When this applies

At the start of any "build this screen" / "implement this design" request, before any
manifest lookup happens - this doc is where the element list that
[component-mapping.md](component-mapping.md) works from comes from.

## The values-vs-structure boundary

Stated once, prominently, because it is the single most important scoping decision this
skill makes: this skill reads a design input for **structure** - what elements exist,
how they're arranged, which manifest component each one becomes. It never reads a
design input for **values** - a color, a spacing number, a font choice. Those are
**utopia-design-import**'s job: it maps external values onto `design/tokens.json`
paths. A design input that carries both (most handoff bundles do) needs both skills,
run separately, in either order - but never one skill trying to also do the other's
job. If a design shows a button in a shade of blue, this skill decides "that's a
`button`"; utopia-design-import (if the blue is actually new to the app) decides
whether `color.primary` needs to change. This skill never edits `design/tokens.json`,
and utopia-design-import never decides which manifest component to construct.

## Layout is part of the structure

A design input is also a layout spec, not just an element list: preserve macro layout -
content anchoring (top-aligned scrolling content unless the design demonstrably centers
it), column max-width, and element order. Do not introduce `Center`/`Expanded` wrappers
the design does not show; a wrapper like that changes how the screen behaves on real
content (a short list, a tall list, a resize) in ways the source design never specified.
When alignment is genuinely ambiguous, default to top-anchored and note the assumption -
the same disclosure discipline [gap-reporting.md](gap-reporting.md) requires for any
other deviation or simplification.

## HTML mockup or web page

Read the markup for structure, not for its inline styles or colors: semantic tags
(`<header>`, `<nav>`, `<main>`, `<section>`, `<table>`, `<form>`, dialog/modal
containers) are the fastest signal for which manifest component a block of markup
represents - a `<nav>` with a list of links suggests `sidebar`; a `<table>` suggests
`table`; a `<dialog>` or a fixed-position overlay suggests `dialog` or
`confirm-dialog`.

When the mockup is itself **twin-derived** - copied or adapted from the packaged HTML
twin's own markup (`components.html` / `gallery.html`, see
[twin-gallery.md](twin-gallery.md)) - it already carries `data-utopia-id` attributes on
component roots (SPEC.md 4.4: every twin component root MUST carry
`data-utopia-id="<manifest id>"`). When present, that attribute **is** the component id
to use - no guessing, no candidate shortlist needed, just resolve straight to that id in
[component-mapping.md](component-mapping.md). Never ignore a `data-utopia-id` in favor
of re-guessing from the surrounding markup's shape. One exception before trusting an
element as screen content: a twin **note entry** - an element whose text reads
"no visual twin: <reason>" (see [twin-gallery.md](twin-gallery.md)) - is coverage
metadata, not a design element. Do not render its text as UI copy, do not instantiate
its component unprompted, and do not misread "no visual twin" as "no component exists"
(the component exists in the manifest; it just has no styled specimen).

## Screenshot or image

There is no markup to read, so start by identifying **layout regions** rather than
individual elements: a navigation rail/sidebar area, a header or title bar, a main
content area, a data-table region, a search/filter bar, a modal/dialog overlay, an
empty or loading state. Name each region in plain terms first, then run
[component-mapping.md](component-mapping.md)'s shortlist method **per region** - most
regions map to exactly one top-level manifest component (a sidebar region to
`sidebar`, a table region to `table`), with the region's internal details (a per-row
action, a column header, a trailing chip) becoming that component's own props or
composed sub-elements rather than separate top-level components. Do not assume a
screenshot's visual boundaries line up one-to-one with component boundaries - a "card
with a list inside" region might be one `card` composing several other components, not
a single new one.

## Design handoff bundle directory

A handoff bundle is a directory, not a single file, and does not follow one fixed
internal schema - inventory what is actually present before assuming anything. What it
typically holds (tokens file, `DESIGN.md`, asset files) and how to read the *tokens*
side of it is **utopia-design-import**'s
[sources.md](../../utopia-design-import/references/sources.md) - not repeated here. This
skill's job starts once the tokens side has been handed off: any HTML mockup, screenshot,
or `DESIGN.md` prose the bundle *also* contains is read for structure exactly as
described in the other sections of this doc. A bundle asset file (an image, an icon) is
itself just a screenshot/image input for this skill's purposes.

## DESIGN.md

`DESIGN.md` follows the [design.md spec](https://github.com/google-labs-code/design.md)
(SPEC.md 4.6): YAML front matter (`name`, `colors`, `typography`, `rounded`, `spacing`)
followed by eight canonical prose sections in order - Overview, Colors, Typography,
Layout, Elevation & Depth, Shapes, Components, Do's and Don'ts.

- The **front matter** is a value source, not a structure source - it goes to
  **utopia-design-import**, never read here for component decisions.
- The **Components** prose section is the one part of a `DESIGN.md` this skill reads:
  treat it as a **hint list**, not ground truth. It is human-authored prose describing
  what the design system's components are and how they're meant to be used - useful for
  narrowing a candidate shortlist quickly, but it can drift from what `utopia_ui`
  actually ships. Every id or prop it seems to reference still needs verifying against
  the real `manifest/utopia.manifest.json` (per
  [component-mapping.md](component-mapping.md)) before it is trusted; prose is a
  starting point for a search, never a substitute for the manifest.
- The other seven prose sections (Overview, Colors, Typography, Layout, Elevation &
  Depth, Shapes, Do's and Don'ts) are not structural inputs for this skill at all - they
  describe the visual system, which is **utopia-design-import**'s and
  **utopia-design-tokens**'s territory.

## The twin gallery as an input

The packaged HTML twin (`components.html`, `gallery.html` - see
[twin-gallery.md](twin-gallery.md)) is itself a usable design input in two ways: as a
literal source of markup to adapt (in which case it is read exactly like a twin-derived
HTML mockup above - trust its `data-utopia-id` attributes directly), and as a reference
for "what does the real `<id>` specimen actually look like" while mapping a screenshot
or a hand-drawn mockup element to a candidate id. [twin-gallery.md](twin-gallery.md)
covers its bundle structure, naming conventions, and the tier-1 specimen list in full;
this doc only establishes that it counts as an input type alongside the four above.

## See also

- [component-mapping.md](component-mapping.md) - what the extracted element list turns
  into: manifest ids and constructor calls
- [gap-reporting.md](gap-reporting.md) - what happens when an extracted element has no
  manifest answer
- [twin-gallery.md](twin-gallery.md) - the twin gallery's own structure, in full
- **utopia-design-import**'s
  [sources.md](../../utopia-design-import/references/sources.md) - the values side of a
  handoff bundle or a `DESIGN.md`'s front matter
