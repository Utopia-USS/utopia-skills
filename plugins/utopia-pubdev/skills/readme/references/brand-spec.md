# Brand chip spec

The header image is a "chip": the Utopia mark + the package name on a soft light
pill ("Clay" style). One static asset that stays legible on both the pub.dev
light and dark themes - which a transparent single-tone wordmark does not (that's
why the old all-black headers vanished on dark).

Generate it with `scripts/` - never hand-draw. This file is the recipe the
generator encodes, kept so the look survives the tooling.

**Visual reference:** [`../docs/gallery.html`](../docs/gallery.html) renders the
chip across every package on pub.dev light + dark (self-contained; open in a browser).

## Logo

The colour standalone mark (`Group.svg`): black structural swoosh + arrow, with
the blue "flame" intact (`#7BCDF3` light, `#0B5EA2` dark, `#1F1E21` fold overlay
at 0.5). The icon is NOT monochrome - the flame is part of the brand.

## Wordmark

Ubuntu, black. Two lines, independent sizes:

- top "Utopia" - fixed 13px.
- package name - two modes: **27px** when < 8 characters (e.g. "Hooks", "REST"),
  else **24px** (e.g. "Collections", "Firebase Crashlytics"). Single line, no wrap.

Display name: strip the `utopia_` prefix, title-case words, uppercase known
acronyms (CMS, CLI, REST, GraphQL, API, SQL, HTTP, IO, UI).

## Chip (Clay)

- Surface `#F6F7F9`, border `2px rgba(255,255,255,.85)`, `border-radius: 999px`.
- Shadow: `inset -3px -3px 8px rgba(15,23,42,.05), inset 3px 3px 8px rgba(255,255,255,.9), 9px 9px 22px -8px rgba(16,24,40,.30)`.
- Mark 50px tall; gap 18px; inner padding `16px 30px 16px 20px`.

## Export

- Headless Chrome screenshot of the chip element, **transparent background**,
  `deviceScaleFactor: 2` → PNG at **2× the natural size**.
- The capture box uses padding `6px 30px 24px 0` (left = 0) so the pill's left
  edge sits flush against the image edge (aligns with README text); the down-right
  Clay shadow gets the room on the right/bottom.
- Placed at `<package>/docs/header.png`.

## Embedding in README

```
<img src="docs/header.png" width="<natural @1x width>" alt="Utopia <Name>"/>
```

- `width` = the natural @1x width the generator reports (the @2x PNG renders crisp
  at half its pixels). NEVER set `height`, `max-width`, or a full-width style - the
  chip shows at its own size, flush-left, not stretched.
- Use a **relative** `docs/header.png` when the package's pubspec `repository`
  points at the package subdir; otherwise an absolute raw URL on the default
  branch is fine (it resolves once merged/published). Existing Utopia READMEs use
  absolute raw URLs - match the repo's prevailing convention.

## Palette

`#7BCDF3` sky · `#0B5EA2` brand blue · `#0A2540` navy (derived) · `#1F1E21` ink ·
`#000000` black · `#FFFFFF` paper.
