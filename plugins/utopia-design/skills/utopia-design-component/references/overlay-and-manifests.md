# The Overlay Schema and the Three-Document Manifest Model

## What this covers

The overlay YAML key reference (grounded in the real shipped `overlay/*.yaml` files and
the loader that reads them), and the library/project/merged manifest model SPEC.md 3.8
introduces for project components - what each document is, what marks it, and what
`validate_manifest` enforces once a project registers its own components.

## The overlay key reference

All four keys are optional - include only the ones that apply to the component.
An overlay file carries curated facts the static analyzer cannot derive on its own
(SPEC.md 3.7: "a hand-maintained per-component overlay... carrying facts that cannot be
derived statically"). Project overlays at `design/overlay/<local-part>.yaml` use the
**same schema and drift gates as** the library overlay at
`tool/utopia_design_tools/overlay/<id>.yaml` (SPEC.md 3.8). That schema is exactly four
keys - no others are read by the loader:

| Key | Shape | Real example |
|---|---|---|
| `states` | list of strings, from a **closed** vocabulary | `button.yaml`: `states: [hover, loading, disabled]`; `table.yaml`: `states: [empty, loading, hover]`; `date-picker.yaml`: `states: [open]` |
| `notes` | free-text block | `card.yaml`: "A raised, rounded, hairline-bordered surface..."; `divider.yaml`: "A hairline divider drawn in the theme's divider colour..." |
| `examples` | list of repo-relative paths | `button.yaml`: `[example/lib/sections/buttons_section.dart, example/lib/sections/dialogs_section.dart]` |
| `tokenBindingsAdd` | list of dotted binding paths (SPEC.md 3.6 vocabulary) | not exercised by any shipped library overlay today - see below |

`tokenBindingsAdd` is real, shipped machinery even though no current library overlay file
happens to use it: it is a first-class field in the loader
(`tool/utopia_design_tools/lib/src/manifest/overlay.dart`), documented there as "a
`tokenBindingsAdd` escape hatch" for "a token binding the AST extractor missed." It exists
because the extractor is a single-file AST visitor (SPEC.md 3.6: bindings must "appear in
the component's implementation") - a binding read through a helper defined in a
**different** file is invisible to it, and `tokenBindingsAdd` is how that gap gets closed
by hand. See [scaffold-and-register.md](scaffold-and-register.md) Step 3 for a worked
scenario.

### Generation-time drift gates on the overlay (SPEC.md 3.7/3.8, verbatim mechanics)

The same `overlay.dart` loader enforces, at `generate_manifest` time:

- An overlay whose filename matches no extracted component id **fails generation**
  (rename or remove the overlay file).
- Any `states` entry outside the closed vocabulary - `hover`, `focus`, `pressed`,
  `loading`, `disabled`, `selected`, `error`, `empty`, `readOnly`, `expanded`, `open` -
  **fails generation**. This is exactly why a data-driven visual variant (gain/loss
  coloring, a rating value, anything computed from a prop rather than user interaction)
  must never be encoded as a `states` entry - it has no landing spot in this vocabulary
  and generation will reject it.
- Any `examples` path that does not exist in the repo **fails generation**.
- Any `tokenBindingsAdd` entry the extractor already found on its own **fails
  generation** as a stale escape hatch - remove it instead of leaving it redundant.

Write the overlay, then run `generate_manifest --project` (Step 4 of
[scaffold-and-register.md](scaffold-and-register.md)) expecting these same gates to run
against the project's own overlay directory.

## The three-document model (SPEC.md 3.8)

| Artifact | Location (consumer project) | Truth status |
|---|---|---|
| Library manifest | pub cache (`manifest/utopia.manifest.json`) | source of truth (shipped, SPEC.md 3.7) |
| Project manifest | `design/project.manifest.json` | source of truth (generated from project source + overlays) |
| Merged manifest | `design/merged.manifest.json` | DERIVED - regenerate, never edit, never treat as source |

The project manifest contains **only** custom components, curated **opt-in**: a
component exists in it exactly when the project has an overlay YAML for it - a project
never auto-exports every private widget. `generate_manifest --project` runs the same
analyzer + overlay extraction over the consumer project and emits BOTH files in one run
(exact CLI: [scaffold-and-register.md](scaffold-and-register.md)'s pin section).

### Flavor markers (schema 0.2.0)

Manifest documents carry three markers distinguishing which of the three documents is in
hand:

- `package` - the described Dart package: the project's own package name on the project
  and merged manifests, `utopia_ui` on the library manifest.
- `utopiaUiVersion` - the resolved `utopia_ui` version the document was generated
  against. **Required** on the project and merged manifests; absent on the library
  manifest (its own `packageVersion` field already carries this role there, per SPEC.md
  3.7).
- `merged: true` - present only on the merged view.

### Namespace enforcement (`validate_manifest`)

- In the **project manifest**, every component id's namespace MUST equal the document's
  own `package` - a bare id there is an error (SPEC.md 3.3/3.8: bare ids are reserved for
  `utopia_ui` library components forever).
- In the **library manifest**, a namespaced id is an error (bare ids only).
- In the **merged view**, both flavors legitimately coexist, and each id MUST carry the
  namespace of its origin document.
- `utopiaUiVersion` presence (required on project/merged, absent on library) is enforced
  by the validator, not the schema.

### `file` path roots

A bare-id entry's `file` resolves against the `utopia_ui` package root; a namespaced
entry's `file` resolves against the **project** root. Do not resolve a project
component's `file` path against the pub cache - it lives in the consumer's own source
tree.

### Freshness gates on the merged view

- Recorded `utopiaUiVersion` MUST equal the resolved `utopia_ui` pubspec version.
- The embedded library entries MUST equal the shipped library manifest.
- Byte-identical regeneration is a **determinism guarantee** on `generate_manifest
  --project` itself (verified by its own tests, the same principle as the twin's
  `tokens.css` freshness) - it is NOT a `validate_manifest`-side gate. `validate_manifest`
  never re-runs project extraction just to diff bytes; staleness on the project half is
  instead caught by the same source-backed gates SPEC.md 3.7 already runs
  (`tokenBindings` re-extraction, stale-class detection, file cross-checks), applied
  against the project's own sources.
- A stale merged view is an **error**, not a warning - embedding a copy of the library
  manifest that no longer matches the resolved package is exactly the silent upgrade
  drift the `packageVersion` gate (SPEC.md 3.7) exists to prevent in the first place.

### Models, helpers, and referential integrity across the merge

Project manifests MAY carry their own `models` and `helpers` sections, same shape as the
library manifest's (SPEC.md 3.2's exclusion rule + 3.5's portable type vocabulary, with
"exported `utopia_ui` class" read as "class exported/declared by the describing
package"). `modelName` resolves within its own containing document; in the **merged**
view, model names MUST be unique **across both halves** - a flat, merge-unique model
namespace in MVP - and `generate_manifest --project` MUST fail the merge outright on a
collision. A custom component's `composes` list and a prop's `modelName` MAY point at
library ids/models (not just its own project's); `validate_manifest` enforces that every
such reference actually resolves on the merged view.

### What stays out of scope (explicit, protocol v0)

- No twin entries for project components: twin bindings are schema-optional, and the
  shipped HTML twin/gallery covers library components only - a project component's
  manifest entry carries no twin section.
- No custom-token codegen, and no opening of the closed token tree (see
  **utopia-design-tokens**'s
  [token-profile.md](../../utopia-design-tokens/references/token-profile.md) "When to
  add a new entry").
- No multi-layer namespace implementation - the grammar reserves it (SPEC.md 3.3), but
  MVP tooling implements a single project layer only.

## See also

- [scaffold-and-register.md](scaffold-and-register.md) - the loop this schema is written
  into, worked end-to-end, including the single `H5: READY` pin spot for the
  `generate_manifest --project` CLI itself
- **utopia-design-tokens**'s
  [token-profile.md](../../utopia-design-tokens/references/token-profile.md) - why a
  project-specific visual value is a constant, never a new token
