---
name: utopia-design-screen
description: >
  Build or update a Flutter screen/widget tree from an outside design input, in a
  project that resolves utopia_ui, using ONLY components from the component manifest -
  the merged manifest when the project registers custom components (SPEC 3.8), else the
  shipped library manifest. Also applies when the project does not resolve utopia_ui
  yet, where it stops at its usage gate and surfaces install guidance instead of
  acting. Applies when: implementing an HTML mockup or web page, a screenshot/image
  of a design, a design handoff bundle directory, a DESIGN.md, or the packaged HTML
  twin gallery, as utopia_ui screen code; deciding which utopia_ui component a given
  design element maps to; reporting a design element that has no manifest mapping as a
  gap instead of hand-rolling it. Concrete triggers: "build this screen", "implement
  this design", "from this mockup", "from this screenshot", "recreate this page with
  utopia_ui", "which utopia_ui component for". Does NOT cover editing
  design/tokens.json (-> utopia-design-tokens); importing external design VALUES -
  colors, spacing, typography (-> utopia-design-import; import maps VALUES onto
  tokens, this skill maps STRUCTURE onto components - the two are complementary, not
  overlapping); regenerating the Flutter theme or the HTML twin (-> utopia-design-sync);
  or state management, screen scaffolding, navigation conventions (-> utopia-hooks,
  defer entirely). Layered on top of the upstream utopia-hooks plugin - stays silent on
  Screen/State/View / hooks / Dart conventions (foundation concerns).
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_ui, design-protocol, component-manifest, screen-building, gap-reporting, html-twin, design-to-code
---

# Skill: Utopia Design Screen

## Overview

This skill turns an outside design input into Flutter screen code built exclusively from
the `utopia_ui` component manifest - the machine-readable API surface described in
`protocol/SPEC.md` section 3. It owns **which manifest component** a design element maps
to and **how it is constructed** (constructor, props, defaults). It does not own the
token document, regenerating generated surfaces, or app/state architecture - see the
frontmatter `description` above for the exact positive/negative boundary.

The one boundary worth stating twice: this skill maps **STRUCTURE** (an element in a
mockup/screenshot -> a manifest component id -> a constructor call). **utopia-design-import**
maps **VALUES** (a color/spacing/typography value in an external source -> a
`design/tokens.json` path). A design handoff bundle usually needs both: run
**utopia-design-import** for its token values, this skill for its structure. Never use
this skill to "fix" a color or spacing value, and never use utopia-design-import to
decide which widget to build.

## Usage Gate (do this first, non-negotiable)

Before touching anything, confirm the project actually resolves `utopia_ui`:
`pubspec.yaml` declares `utopia_ui:` directly, or `pubspec.lock` resolves it
transitively. This mirrors the plugin's own `SessionStart` / `PostToolUse` hook gate and
the identical check the other three design skills run - the manifest this skill builds
against does not exist without the library present.

- **If it resolves:** continue below.
- **If it does NOT resolve:** stop. Surface this install guidance to the user (show the
  commands; do not add the dependency to their pubspec yourself) instead of building
  anything:
  ```bash
  flutter pub add utopia_ui
  flutter pub get
  ```
  Only proceed with the rest of this skill once the project resolves the package.

## When to Apply

- Building a new screen or widget tree from an HTML mockup/web page, a screenshot or
  image of a design, a design handoff bundle directory, or a `DESIGN.md`
- Recreating or updating a page using only `utopia_ui` components
- Deciding which `utopia_ui` component (and which constructor/props) a given design
  element should use
- Reading the packaged HTML twin gallery as a reference input for a design
- Reporting a design element that has no manifest mapping as a GAP, rather than
  hand-rolling a lookalike

## Out of Scope

- Editing or rebranding `design/tokens.json` -> use **utopia-design-tokens**
- Mapping external design VALUES (colors, spacing, typography) onto the token tree ->
  use **utopia-design-import**; this skill only maps structure onto components
- Regenerating the Flutter theme or the HTML twin -> use **utopia-design-sync**
- Screen/State/View composition, hooks, dependency injection, navigation conventions,
  or `utopia_cli` scaffolding -> use **utopia-hooks**, deferred to entirely; this skill
  never restates any of it

## Priority-Ordered Guidelines

| Priority | Reference | Impact | Description |
|----------|-----------|--------|-------------|
| 1 | [component-mapping.md][component-mapping] | CRITICAL | Resolving the manifest from the pub cache; the component entry shape (props, portable types, defaults); `models`/`helpers`; `tokenBindings`; a worked design-to-constructor-call example |
| 2 | [gap-reporting.md][gap-reporting] | HIGH | Why gaps must stay visible (SPEC.md section 7); the fixed report format; the composition-first check; a fully worked GAP example; anti-patterns |
| 3 | [design-inputs.md][design-inputs] | MEDIUM | Reading each input type for structure - HTML mockup, screenshot, handoff bundle, `DESIGN.md`; the values-vs-structure boundary; the twin gallery as an input |
| 4 | [twin-gallery.md][twin-gallery] | MEDIUM | The HTML twin's frozen bundle contract, `components.html`/`gallery.html` structure, CSS naming, the tier-1 specimen list, and what still needs the real shipped files |

## Non-Negotiable Rules

- **Verify `utopia_ui` resolves before building anything** (the usage gate above).
- **Manifest-only components.** Every UI element in the generated code maps to a
  manifest component id - a bare library id (`button`) or, when the project registers
  custom components, a namespaced project id (`<package>:<kebab-name>`, SPEC.md
  3.3/3.8) - constructed per `components[].constructors[].props`: required props,
  verbatim defaults, and portable types exactly as documented (SPEC.md 3.5). Props typed `"model"` or a `list` of
  `model` resolve via `models[]` by `modelName`; `helpers[]` carries the exported
  functions/hooks a screen may need (e.g. `useUtopiaTableState`, `utopiaCardSliver`).
  **Never** invent a prop, **never** use a widget class absent from the manifest,
  **never** build from memory of "typical" `utopia_ui` API shape - the manifest
  matching the resolved package version is the only truth; drift is assumed (SPEC.md
  3.7). See [component-mapping.md][component-mapping].
- **Resolve the manifest from the resolved package root**, via
  `.dart_tool/package_config.json` (`utopia_ui` `rootUri` ->
  `manifest/utopia.manifest.json`) - the identical resolution technique
  **utopia-design-tokens**'s
  [getting-started.md](../utopia-design-tokens/references/getting-started.md) documents
  for the token document; do not re-derive or duplicate that snippet here, just point
  it at the manifest file instead of the token document. When the project has a merged
  manifest (`design/merged.manifest.json`, SPEC.md 3.8), prefer IT as the mapping
  target - it adds the project's own registered components; it is derived output:
  regenerate it, never edit it. See [component-mapping.md][component-mapping]. Optionally run
  `dart run utopia_design_tools:validate_manifest` with zero arguments as a freshness
  check (the `packageVersion` drift gate); its exact CLI contract and gates are
  **utopia-design-sync**'s
  [regeneration.md](../utopia-design-sync/references/regeneration.md), not re-specified
  here.
- **Gap reporting, never a hand-rolled lookalike.** Any design element with no manifest
  mapping is a reported GAP: element name/description; closest manifest candidate ids
  with why each was rejected; what the element needs that the candidates lack;
  suggested action (scaffold as a project component registered in the project manifest
  per SPEC.md 3.8, request the component upstream in `utopia_ui`, or ask the user); and
  a component-spec seed (proposed namespaced id, needed props, states, token bindings)
  so a scaffold decision can start immediately.
  Never a hand-rolled widget styled to imitate one, never a raw Material/Cupertino
  stand-in - except that a functionally-required element (the only way to cancel,
  submit, or dismiss) may get a minimal declared, unstyled stand-in, as defined in
  [gap-reporting.md][gap-reporting]. Gaps appear **both** in the final response **and**
  as a `// TODO` comment at the insertion point in the generated screen code.
  **Composition-first**: before declaring a GAP, check whether the element decomposes
  into existing manifest components - the manifest's `composes` hints point at exactly
  this. A GAP is for genuinely missing capability, not for an element that just needs
  assembling from parts that already exist. See [gap-reporting.md][gap-reporting].
- **Token discipline, one line.** Visual values (colors, spacing, radii, text styles)
  come from `UtopiaTheme`/context per the component's `tokenBindings` - never a
  hardcoded literal for a value that has a token. The plugin's `PostToolUse` hook (Rule
  B) already nudges exactly this on newly-edited Dart; this skill is the fix it points
  at.
- **Layout discipline, one line.** A design input is also a layout spec - preserve macro
  layout (content anchoring, column max-width, element order); never introduce
  `Center`/`Expanded` wrappers the design does not show. See
  [design-inputs.md][design-inputs].
- **Screen composition defers to utopia-hooks.** The Screen/State/View triad, hooks, DI,
  and navigation are **utopia-hooks**'s concern, not this skill's - invoke that skill
  for those. This skill only decides which manifest components a screen uses and how
  they are constructed; it restates zero utopia-hooks content. **utopia-hooks is a
  separate plugin and may be absent from a session.** When it is not available (no such
  skill listed, and the project does not already use `utopia_hooks`), do not substitute
  silently: implement with the plainest idiomatic Flutter as a DECLARED fallback, say so
  in the response, and leave a code comment naming the intended architecture - an
  undisclosed architecture fallback is the state-management version of an undeclared
  stand-in.

## Self-Audit Checklist

After building or updating a screen, verify:

1. Every widget used maps to a real `id` in `manifest/utopia.manifest.json` - the
   resolved package's manifest, not a remembered one.
2. Every constructor call only uses props that exist on that component's constructor,
   with required props supplied and non-default values set intentionally.
3. Every prop typed `model` / `list` of `model` resolves through `models[]` by
   `modelName` - not through an invented class.
4. Every color, spacing, radius, or text style traces to a token per the component's
   `tokenBindings` - no hardcoded literal where a token exists.
5. Every unmapped design element has a GAP report (in the response) and a matching
   `// TODO` comment (in the code) - never a hand-rolled lookalike or an UNDECLARED
   Material/Cupertino stand-in.
6. Composition was checked before any GAP was declared - `composes` hints reviewed for
   an existing-components answer first.
7. Screen architecture (Screen/State/View, hooks, navigation) was left to
   **utopia-hooks** - this skill did not invent its own state pattern.
8. Every list-typed prop's literal matches its verbatim `dartType` - wrapped
   `IList([...])` where the manifest says `IList`, a bare `List` literal only where it
   says `List`.
9. Every chat-disclosed gap OR deviation/simplification has a matching in-code
   TODO/comment - nothing is disclosed only in the conversation.

## See Also

- **utopia-design-component** - turns this skill's gap-report seeds into live namespaced
  ids, registered in the project manifest (SPEC.md 3.8).
- **utopia-design-tokens** - owns `design/tokens.json`; its
  [getting-started.md](../utopia-design-tokens/references/getting-started.md) is the
  resolution snippet this skill's manifest lookup reuses.
- **utopia-design-import** - maps external design VALUES onto the token tree; run it
  first when a handoff bundle carries both values and structure.
- **utopia-design-sync** - regenerates the Flutter theme and the HTML twin; its
  [regeneration.md](../utopia-design-sync/references/regeneration.md) is the
  `validate_manifest` contract this skill's freshness check reuses.
- **utopia-hooks** - owns app/state concerns (Screen/State/View, hooks, DI,
  navigation); this skill stays silent on all of it.

## Attribution

Built on [utopia_ui](https://pub.dev/packages/utopia_ui) and the Utopia Design
Protocol, by UtopiaSoftware.

[component-mapping]: references/component-mapping.md
[gap-reporting]: references/gap-reporting.md
[design-inputs]: references/design-inputs.md
[twin-gallery]: references/twin-gallery.md
