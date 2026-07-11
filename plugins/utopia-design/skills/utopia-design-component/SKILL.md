---
name: utopia-design-component
description: >
  Turn a reported component GAP (or any need for a project-specific component) into a
  LIVE manifest id in a project that resolves utopia_ui: scaffold the component in
  project code as a composition of library primitives, write its opt-in overlay YAML at
  design/overlay/<local-part>.yaml, regenerate the project + merged manifests
  (generate_manifest --project, protocol SPEC.md 3.8), validate, and hand the namespaced
  id back to screen building. Applies when: scaffolding a custom/project-specific
  component, registering a component in the project manifest, turning a
  utopia-design-screen gap report's component-spec seed into a live component. Concrete
  triggers: "scaffold a component", "custom component", "register a component", "project
  manifest", a "component gap" follow-up, "make <thing> a reusable component". Does NOT
  cover deciding whether something is a gap and reporting it (-> utopia-design-screen);
  building screens (-> utopia-design-screen); editing design/tokens.json (->
  utopia-design-tokens); regenerating the Flutter theme or the HTML twin (->
  utopia-design-sync); widget-authoring and state conventions (-> utopia-hooks, defer
  entirely); or contributing the component UPSTREAM into utopia_ui itself (a maintainer
  conversation, out of scope for this loop). Layered on top of the upstream utopia-hooks
  plugin - stays silent on Screen/State/View / hooks / Dart conventions (foundation
  concerns).
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_ui, design-protocol, component-manifest, project-manifest, overlay, scaffolding, custom-component
---

# Skill: Utopia Design Component

## Overview

Every real project outgrows the `utopia_ui` primitive set - the canonical example is a
stock-market tile that composes library widgets, reads the theme, and also needs
project-specific values (gain/loss colors) the closed token tree has no slot for
(SPEC.md 3.8). This skill owns the **one loop** that turns such a
need into a live, namespaced component manifest id: scaffold in project code, write the
overlay YAML that opts the component into the project manifest, regenerate the project +
merged manifests, validate, and stop. It does not decide whether an element is a gap
(that's **utopia-design-screen**), does not touch tokens or the theme/twin, and does not
own widget-authoring or state conventions (**utopia-hooks**, deferred to entirely). See
the frontmatter `description` above for the exact positive/negative boundary.

SPEC.md 3.8 states the loop this skill implements almost verbatim: "a screen-building gap
report names a missing component -> the component is scaffolded in the project (theme
via context) -> an overlay YAML registers it -> project + merged manifests regenerate ->
the design tool re-imports the merged manifest -> the id is live in every later
development cycle." This skill is that loop, start to finish.

## Usage Gate (do this first, non-negotiable)

Before touching anything, confirm the project actually resolves `utopia_ui`:
`pubspec.yaml` declares `utopia_ui:` directly, or `pubspec.lock` resolves it
transitively. This mirrors the plugin's own `SessionStart` / `PostToolUse` hook gate and
the identical check every other design skill in this plugin runs - the manifest this
skill writes into does not mean anything without the library present.

- **If it resolves:** continue below.
- **If it does NOT resolve:** stop. Surface this install guidance to the user (show the
  commands; do not add the dependency to their pubspec yourself) instead of scaffolding
  anything:
  ```bash
  flutter pub add utopia_ui
  flutter pub get
  ```
  Only proceed with the rest of this skill once the project resolves the package.

Second, separate prerequisite: regenerating and validating the project/merged manifests
(steps 4-5 of the loop below) needs `utopia_design_tools`, not `utopia_ui` itself.
Confirm it resolves the same inspect-first way - `pubspec.yaml` (under
`dev_dependencies`) or `pubspec.lock` lists it - and install it first if not:

```bash
flutter pub add --dev utopia_design_tools
```

This is the identical prerequisite **utopia-design-tokens**'s
[validation.md](../utopia-design-tokens/references/validation.md) documents for
`validate_tokens`, including the pre-publish git-dependency + `dependency_overrides`
fallback for when `pub add` cannot yet find the package on pub.dev - do not assume the
tools are available, install then run. That doc is the single cross-link for the
fallback block; it is not re-derived here.

## When to Apply

- A `utopia-design-screen` gap report's component-spec seed needs turning into a real,
  namespaced component (the most common entry point)
- An explicit user ask to scaffold, register, or make reusable a project-specific
  component
- A component already exists in project code but has no overlay YAML / manifest entry
  yet and needs registering

## Out of Scope

- Deciding **whether** a design element is a gap, and reporting it -> **utopia-design-screen**
  (this skill's INPUT is that skill's gap-report component-spec seed, not a decision of
  its own)
- Building or updating screens from a design -> **utopia-design-screen**
- Editing or rebranding `design/tokens.json` -> **utopia-design-tokens**
- Regenerating the Flutter theme or the HTML twin -> **utopia-design-sync**
- Widget-authoring conventions, Screen/State/View, hooks, DI, navigation -> **utopia-hooks**,
  deferred to entirely; this skill never restates any of it
- Contributing the component **upstream** into `utopia_ui` itself - that path is a
  maintainer conversation, not this loop; this skill only ever produces a project
  (namespaced) component

## Priority-Ordered Guidelines

| Priority | Reference | Impact | Description |
|----------|-----------|--------|-------------|
| 1 | [scaffold-and-register.md][scaffold-and-register] | CRITICAL | The loop end-to-end, worked through the stock-market-tile example: seed -> scaffold -> overlay YAML -> regenerate -> validate -> screen usage; the single `H5: READY` pin spot |
| 2 | [overlay-and-manifests.md][overlay-and-manifests] | HIGH | The overlay key reference (from the real `overlay/*.yaml` files); the three-manifest-document model and truth table; flavor markers; freshness gates; what `validate_manifest` enforces on the merged view |

## Non-Negotiable Rules

- **Verify `utopia_ui` resolves, and that `utopia_design_tools` resolves, before doing
  anything** (the two gates above).
- **The loop is six steps, in order** (SPEC.md 3.8's production loop, see
  [scaffold-and-register.md][scaffold-and-register] for the worked walkthrough):
  1. Input is a component-spec seed (from **utopia-design-screen**'s gap report part 5)
     or an explicit user ask.
  2. Scaffold the component in **project** code: composition of library primitives, with
     every theme-derived visual value read from `UtopiaTheme`/context (the plugin's
     `PostToolUse` hook nudges exactly this on newly-edited Dart) - never a hardcoded
     literal where a token exists. Project-specific values (SPEC.md 3.8's stock-tile
     gain/loss colors) live as project constants "on the side" - a legal, documented
     pattern, **not** a smell, and **not** a reason to invent a token (the tree stays
     closed; see [overlay-and-manifests.md][overlay-and-manifests] and
     **utopia-design-tokens**'s
     [token-profile.md](../utopia-design-tokens/references/token-profile.md) "When to
     add a new entry"). Widget style itself - Screen/State/View, hooks, DI - defers
     entirely to **utopia-hooks**; this skill never restates any of it.
  3. Write the opt-in overlay YAML at `design/overlay/<local-part>.yaml`. A component
     exists in the project manifest **exactly when** its overlay file exists - there is
     no other registration mechanism.
  4. Regenerate the project + merged manifests:
     `dart run utopia_design_tools:generate_manifest --project` from inside the
     project. It emits BOTH `design/project.manifest.json` and
     `design/merged.manifest.json` (fixed paths), self-validates before writing
     (exit `1` + findings, nothing written, on failure) and reruns
     byte-identically. Exact flags, defaults, and the shadow-class warning:
     [scaffold-and-register.md][scaffold-and-register].
  5. Validate: run `validate_manifest` pointed at `design/merged.manifest.json`
     (a ZERO-ARG run validates the shipped library manifest instead - not what
     you want here) and confirm the SPEC.md 3.8 gates pass - namespace
     enforcement, `utopiaUiVersion` freshness, embedded-library equality,
     referential integrity across the merge, flat model-name uniqueness. See
     [overlay-and-manifests.md][overlay-and-manifests].
  6. The namespaced id is now live - screen building maps to it via the merged manifest
     (**utopia-design-screen**'s
     [component-mapping.md](../utopia-design-screen/references/component-mapping.md)).
- **Namespace rule (SPEC.md 3.3), no exceptions.** A project component id MUST be
  `<projectPackageName>:<kebab-name>`. Bare ids (`button`) are reserved for `utopia_ui`
  library components forever - **never** fake a bare id for a project component, and
  never omit the namespace "just this once."
- **Generated artifacts are derived, never hand-edited.** `design/project.manifest.json`
  and `design/merged.manifest.json` are regenerated by `generate_manifest --project`, the
  same discipline **utopia-design-sync** enforces for the theme Dart file and the twin's
  CSS. A hand-edit is silently overwritten the next regeneration and, in the meantime,
  misrepresents what the overlay + source actually say.
- **The merged manifest is DERIVED, never a source of truth.** If it disagrees with what
  regeneration would produce, the fix is always upstream (project source or overlay),
  never a patch to the merged file itself.
- **The theme stays closed.** This skill scaffolds components, not tokens - a
  project-specific visual value is a project constant, not a new token tree entry. See
  **utopia-design-tokens**'s
  [token-profile.md](../utopia-design-tokens/references/token-profile.md).

## Self-Audit Checklist

After running this skill's loop, verify:

1. The component's visual values that have a token equivalent are read from
   `UtopiaTheme`/context - none hardcoded.
2. Any project-specific value with no token equivalent (e.g. gain/loss colors) is a
   plainly-named project constant, documented as project-specific - not smuggled into
   the token tree, not left as an unexplained magic literal.
3. An overlay YAML exists at `design/overlay/<local-part>.yaml` for the component, using
   only the real overlay keys (`states`, `notes`, `examples`, `tokenBindingsAdd`, and
   the optional `class:` binding when the filename is not the class's kebab
   derivation) - see [overlay-and-manifests.md][overlay-and-manifests].
4. The component's id is namespaced `<projectPackageName>:<kebab-name>` - never bare.
5. Both `design/project.manifest.json` and `design/merged.manifest.json` were
   regenerated (never hand-edited) after the overlay changed.
6. `validate_manifest` was run and passed - namespace enforcement, `utopiaUiVersion`
   freshness, embedded-library equality, referential integrity, flat model-name
   uniqueness.
7. The resulting namespaced id was handed back to screen building rather than the
   component being wired into a screen ad hoc.

## See Also

- **utopia-design-screen** - reports the GAP whose component-spec seed feeds this
  skill's loop (its
  [gap-reporting.md](../utopia-design-screen/references/gap-reporting.md)), and maps
  screens to the resulting namespaced id via the merged manifest (its
  [component-mapping.md](../utopia-design-screen/references/component-mapping.md)).
- **utopia-design-tokens** - owns the closed token tree; a project-specific visual value
  this skill's scaffold needs stays a project constant, never a new token (its
  [token-profile.md](../utopia-design-tokens/references/token-profile.md)).
- **utopia-design-sync** - regenerates the Flutter theme and the HTML twin from
  `design/tokens.json`; unrelated artifacts to this skill's project/merged manifests, but
  the same "generated, never hand-edited" discipline applies to both.
- **utopia-hooks** - owns app/state concerns (Screen/State/View, hooks, DI, navigation);
  this skill stays silent on all of it.

## Attribution

Built on [utopia_ui](https://pub.dev/packages/utopia_ui) and the Utopia Design
Protocol, by UtopiaSoftware.

[scaffold-and-register]: references/scaffold-and-register.md
[overlay-and-manifests]: references/overlay-and-manifests.md
