---
name: tokens
description: >
  Edit or rebrand a consumer app's design/tokens.json - the DTCG design-tokens
  document that is the single source of truth for the Utopia Design Protocol on
  top of utopia_ui. Applies when: bootstrapping design/tokens.json from the
  packaged utopia_ui default theme; changing theme colors, the spacing/radius
  scale (rescaling the base unit x), typography (textStyle roles and their
  textStyle-colors siblings), or semantic theme.* slots; running validate_tokens
  after an edit. Without utopia_ui resolved it stops at its usage gate and
  surfaces install guidance. Does NOT cover regenerating the Flutter theme or
  the HTML twin (-> utopia-design:sync), importing external design sources
  (Figma exports, foreign tokens.css / Tailwind @theme files, handoff bundles)
  (-> utopia-design:import), building screens from a design
  (-> utopia-design:screen), or editing utopia_ui library internals. Layered on
  the upstream utopia-hooks plugin - silent on Screen/State/View, hooks, and
  Dart conventions.
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_ui, design-tokens, dtcg, tokens-json, rebrand, theming, design-protocol
---

# Skill: Utopia Design Tokens

## Overview

The Utopia Design Protocol keeps one artifact as the single source of truth
for an app's visual theme: `design/tokens.json`, a
[DTCG](https://www.designtokens.org/tr/2025.10/format/) document. The
Flutter theme (`UtopiaThemeData`) and the HTML twin's CSS are both
**generated** from it - this skill owns editing that one file; it does not
own the generation step or anything downstream of it. See the frontmatter
`description` above for the exact positive/negative boundary.

## Usage Gate (do this first, non-negotiable)

Before touching anything, confirm the project actually resolves `utopia_ui`:
`pubspec.yaml` declares `utopia_ui:` directly, or `pubspec.lock` resolves it
transitively. This mirrors the plugin's own `SessionStart` / `PostToolUse`
hook gate - the protocol is meaningless without the library present.

- **If it resolves:** continue below.
- **If it does NOT resolve:** stop. Surface this install guidance to the user
  (show the commands; do not add the dependency to their pubspec yourself)
  instead of editing anything:
  ```bash
  flutter pub add utopia_ui
  flutter pub get
  ```
  Only proceed with the rest of this skill once the project resolves the
  package.

## Start Here: Bootstrap design/tokens.json

**This is the first-hour make-or-break step - do it before any other edit.**
If `design/tokens.json` does not exist yet, create it by copying the
packaged default theme from the resolved `utopia_ui` pub cache: read
`.dart_tool/package_config.json` to find `utopia_ui`'s `rootUri`, then copy
`<root>/tokens/utopia.tokens.json` to `design/tokens.json`. Once it exists,
it is consumer-owned - a package upgrade never overwrites it (SPEC.md
section 1) - so this step runs at most once per project.

The exact resolution + copy commands are in
[getting-started.md][getting-started] - read that before bootstrapping,
don't guess the pub-cache path.

**Where `SPEC.md` / `VERSIONING.md` live:** the protocol documents ship inside
the `utopia_ui` package under `protocol/` (hence the `protocol/SPEC.md`
citations), alongside the `protocol/schemas/` the validators check against.
Resolve the installed copy the same way this skill resolves every packaged
artifact: read `.dart_tool/package_config.json` for `utopia_ui`'s `rootUri`
(snippet in [getting-started.md][getting-started]), then open
`<root>/protocol/`. If it does not resolve, treat every `SPEC.md` /
`VERSIONING.md` citation in this skill as background rationale and continue -
never block on the missing file.

## When to Apply

- Bootstrapping `design/tokens.json` for the first time in a project that
  resolves `utopia_ui`
- Rebranding: colors, the spacing/radius scale, border/shadow/duration/
  breakpoint values, typography, or `theme.*` semantic slots
- Running `validate_tokens` after any of the above
- Typical phrasings: "design tokens", "rebrand", "tokens.json", "DTCG",
  "theme colors", "spacing scale", "radius scale"

## Out of Scope

- Regenerating the Flutter theme or the HTML twin from tokens -> use
  **utopia-design:sync**
- Importing an external design source (Figma, foreign `tokens.css` /
  Tailwind `@theme`, a handoff bundle, a `DESIGN.md`) -> use
  **utopia-design:import** first, then this skill's edit loop
- Building or updating a screen from a design -> use **utopia-design:screen**
- Editing `utopia_ui` library internals - this skill only ever touches the
  consumer's `design/tokens.json`

## Priority-Ordered Guidelines

| Priority | Reference | Impact | Description |
|----------|-----------|--------|-------------|
| 1 | [getting-started.md][getting-started] | CRITICAL | The first-hour flow: usage gate, resolving packaged artifacts via `.dart_tool/package_config.json`, bootstrapping `design/tokens.json`, the edit -> validate -> regenerate loop |
| 2 | [token-profile.md][token-profile] | CRITICAL | The closed canonical tree - every valid path, `$type`, and constraint; the `color.*` group; the typography wrinkle; the `io.utopiasoft.design` extension namespace |
| 3 | [rebranding.md][rebranding] | HIGH | Why-first rules for editing values safely: colors, the `x` rescale + `derivation`, `theme.*` aliases vs literals, `textStyle` siblings, extension round-trip |
| 4 | [validation.md][validation] | HIGH | The `validate_tokens` CLI contract, the five validation gates, `profileVersion` compatibility, hook vs CLI |

## Non-Negotiable Rules

- **Verify `utopia_ui` resolves before editing anything** (the usage gate
  above) - there is nothing to rebrand without the library.
- **`design/tokens.json` is consumer-owned.** A package upgrade never
  overwrites it (SPEC.md section 1); don't regenerate or reset it as part of
  an unrelated upgrade.
- **The token tree is closed.** Only the canonical names in
  [token-profile.md][token-profile] (SPEC.md 2.2) are valid; unknown names
  are rejected, not accepted-and-ignored.
- **Names MUST NOT contain `.`, `{`, `}` or start with `$`.** Dotted
  identifiers like `spacing.md` are reference paths expressed as nested JSON
  groups, not literal token names.
- **Every base-derived token carries `$extensions["io.utopiasoft.design"].derivation`
  as `"x*<n>"` and MUST satisfy `value == x * n`.** Rebranding `x` means
  re-deriving every `derivation`-carrying token, not just `x` itself
  (SPEC.md 2.5; see [rebranding.md][rebranding]).
- **Every `textStyle.<role>` has a sibling `textStyle-colors.<role>`** and
  records the binding via `colorToken` (SPEC.md 2.4).
- **`$extensions` MUST round-trip.** Never drop unknown extension data -
  including foreign vendor namespaces - on an edit (SPEC.md 2.1, 2.6).
- **Run `validate_tokens` after any edit.** Never hand-edit generated theme
  Dart or twin CSS - those are regenerated by `utopia-design:sync`.
- **Keep `$extensions["io.utopiasoft.design"].profileVersion` at the
  document root in sync** with the protocol version the document targets
  (VERSIONING.md).

## Self-Audit Checklist

After any edit to `design/tokens.json`, verify:

1. The file is still valid JSON.
2. Every name used is in the closed tree ([token-profile.md][token-profile]) -
   nothing invented.
3. Every `derivation`-carrying token still satisfies `value == x * n`.
4. Every `textStyle.<role>` still has its `textStyle-colors.<role>` sibling,
   with `colorToken` pointing at it.
5. Every color's `hex` still matches its `components`.
6. `$extensions` data - including anything this skill doesn't recognize - is
   preserved.
7. `validate_tokens` passes (or every reported finding has been addressed).
8. `profileVersion` is set at the document root.
9. If the user's goal was a REBRAND (a visible change), the loop is NOT
   complete at validate-clean: continue into **utopia-design:sync** in the
   same session, or state explicitly that the app keeps rendering the old
   brand until sync runs. Never report a rebrand "complete" while generated
   surfaces are stale.

## See Also

- **utopia-design:sync** - regenerate the Flutter theme and the HTML twin
  after a token edit lands and validates; REQUIRED before a rebrand is
  user-visible, not merely the natural next step - do not stop between the
  two skills when the ask was a rebrand.
- **utopia-design:import** - bring in an external design source and map it
  onto this tree before editing.
- **utopia-design:screen** - build screens from manifest components; not
  this skill's concern.
- **utopia-hooks** - owns app/state concerns (Screen/State/View, hooks, DI);
  this skill stays silent on all of it.

## Attribution

Built on [utopia_ui](https://pub.dev/packages/utopia_ui) and the Utopia
Design Protocol, by UtopiaSoftware.

[getting-started]: references/getting-started.md
[token-profile]: references/token-profile.md
[rebranding]: references/rebranding.md
[validation]: references/validation.md
