# Scaffolding and Registering a Project Component

## What this covers

The full loop end-to-end, worked through one example: a stock-market tile - the
canonical case `protocol/SPEC.md` 3.8 is built around (a component that composes library
primitives, reads the theme, and carries project-specific values the closed token tree
has no slot for). Every step below is anchored to `protocol/SPEC.md` 3.8's
production loop: "a screen-building gap report names a missing component -> the
component is scaffolded in the project (theme via context) -> an overlay YAML registers
it -> project + merged manifests regenerate -> the design tool re-imports the merged
manifest -> the id is live in every later development cycle."

## When this applies

Whenever `SKILL.md`'s "When to Apply" fires: a `utopia-design:screen` gap report's
component-spec seed needs turning into a live id, or an explicit ask to scaffold/register
a project-specific component.

## Step 1 - the input: a component-spec seed

The loop starts from a **component-spec seed**, part 5 of `utopia-design:screen`'s fixed
GAP report format (its
[gap-reporting.md](../../screen/references/gap-reporting.md)): a proposed
namespaced id, the props it needs, its interaction states, and the token bindings it
would read. Nothing here is invented by this skill - it is handed the seed (or an
equivalent explicit user ask) and starts scaffolding from it.

Worked seed, for a project named `stock_app` (the exact illustrative id `SPEC.md` 3.3
itself uses):

- Proposed id: `stock_app:market-tile`
- Props: `symbol` (string, required), `companyName` (string, required), `price`
  (number, required), `changePercent` (number, required), `onTap` (callback, optional)
- Interaction states: none identified yet (tap-only; see the states note in Step 3 below
  for why the gain/loss coloring is deliberately NOT listed here)
- Token bindings it would read: a themed title/caption pairing and standard spacing -
  refined once the component actually exists, in Step 3

## Step 2 - scaffold in project code

Compose library primitives; read every theme-derived visual value from
`UtopiaTheme`/context (`context.colors`, `context.textStyles`, `context.spacing`,
`context.tokens`, `context.radius` - the shorthand extensions `utopia_ui` puts on
`BuildContext`); keep project-specific values that have no
token equivalent as plain project constants "on the side." This is a legal, documented
pattern (SPEC.md 3.8: "Project-specific visual values (e.g. gain/loss
colors on a stock tile) live in project code as constants - a legal, documented pattern,
not a smell"), not a reason to invent a token - the tree stays CLOSED (SPEC.md 3.8; see
[overlay-and-manifests.md](overlay-and-manifests.md) and
**utopia-design:tokens**'s
[token-profile.md](../../tokens/references/token-profile.md) "When to add
a new entry").

Illustrative sketch (structure matters here - the exact widget tree is yours to build,
this shows the theme-context-read / constants-on-the-side shape, not a prescribed API):

```dart
// lib/src/widgets/market_tile.dart  (project code, NOT utopia_ui)
import 'package:flutter/widgets.dart';
import 'package:utopia_ui/utopia_ui.dart';

class MarketTile extends StatelessWidget {
  const MarketTile({
    super.key,
    required this.symbol,
    required this.companyName,
    required this.price,
    required this.changePercent,
    this.onTap,
  });

  final String symbol;
  final String companyName;
  final double price;
  final double changePercent;
  final VoidCallback? onTap;

  // Project-specific values with NO token equivalent - "on the side"
  // constants per SPEC.md 3.8. Never smuggled into
  // design/tokens.json; never read off UtopiaThemeData because they are
  // not theme members.
  static const _gainColor = Color(0xFF1E8E3E);
  static const _lossColor = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    final isGain = changePercent >= 0;
    return GestureDetector(
      onTap: onTap,
      child: UtopiaCard(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(companyName, style: context.textStyles.title),
              Text(symbol, style: context.textStyles.caption),
              Text('\$${price.toStringAsFixed(2)}', style: context.textStyles.title),
              Text(
                '${isGain ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                style: context.textStyles.caption.copyWith(
                  color: isGain ? _gainColor : _lossColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Two things worth naming: `MarketTile` composes `UtopiaCard` (a library primitive) rather
than hand-rolling a decorated `Container` - composition-first applies to scaffolding just
as it does to the gap check that got here. And widget-authoring/state concerns beyond
this - whether `MarketTile` needs its own hooks, how a screen wires its data - are
**utopia-hooks**'s territory, deferred to entirely; this skill does not restate any of
that.

## Step 3 - write the overlay YAML

A component exists in the project manifest **exactly when** its overlay file exists, at
`design/overlay/<local-part>.yaml` (SPEC.md 3.8) - same schema and drift gates as the
library overlay (SPEC.md 3.7). The `<local-part>` is the id's local part per SPEC.md
3.3: kebab-case of the Dart class name (`MarketTile` -> `market-tile`), with NO prefix
stripping in v0. To register under a DIFFERENT local part than the class derivation,
name the file as desired and bind it explicitly with a `class: <ClassName>` key inside
the overlay - the SPEC.md 3.3 local-part override (the reference fixture registers
`DemoRatingStars` as `star-rating` exactly this way). A filename that matches no class
derivation and carries no `class:` binding is a generation-time error. The real house
shape has five keys: `states`, `notes`, `examples`, `tokenBindingsAdd`, plus the
optional `class` binding - all optional, include only what applies (full reference in
[overlay-and-manifests.md](overlay-and-manifests.md)).

`design/overlay/market-tile.yaml`:

```yaml
notes: >-
  A compact stock-quote surface: company name, symbol, current price, and
  percent change. changePercent's sign drives the gain/loss color, which is a
  project-specific constant (see MarketTile._gainColor/_lossColor) - not a
  token, and not listed under states below.
```

(`examples` is deliberately omitted here: it points at files that DEMONSTRATE the
component - a screen that renders it - not at the component's own declaring file,
which the manifest already carries in its analyzer-derived `file` field. Add an
`examples` entry once a consuming screen exists.)

Note what is deliberately **absent**: no `states: [positive, negative]` entry. The
manifest `states` field is the closed interaction-state vocabulary generation enforces
(`hover`, `focus`, `pressed`, `loading`, `disabled`, `selected`, `error`, `empty`,
`readOnly`, `expanded`, `open` - see
[overlay-and-manifests.md](overlay-and-manifests.md)) - a data-driven visual variant like
gain/loss coloring is not an interaction state and does not belong there, however tempting
the name overlap. If `MarketTile` later grows real interactive states (e.g. a `hover` lift
on desktop), add exactly that word to `states` then - never a name outside the closed set.

`tokenBindingsAdd` is not needed here: the analyzer's AST extractor reads the whole
declaring file (including private helpers in the same file), so every
`context.spacing`/`context.textStyles` read in the sketch above is found automatically
(SPEC.md 3.6 - "bindings are verified against source"). `tokenBindingsAdd` earns its
keep only for a binding read through a **different file** the single-file extractor
cannot see - e.g. if `MarketTile` called a shared `_marketTileLabelStyle(BuildContext)`
helper defined in another project file that reads `context.colors.text` internally, that
binding would need `tokenBindingsAdd: [colors.text]` here. Do not add speculative entries
"just in case" - the drift gate fails generation if an entry duplicates something the
extractor already found (`overlay.dart`'s stale-escape-hatch check).

## Step 4 - regenerate the project + merged manifests

**This is the one pin spot in this skill.** Conceptually: run
`generate_manifest --project`, which emits BOTH `design/project.manifest.json` and
`design/merged.manifest.json`, deterministically, never hand-edited (SPEC.md 3.8). The
exact CLI - flags, defaults, exit messages beyond that - is pinned below; see "Step 4's
exact CLI" below, the single place this skill tracks that detail.

## Step 5 - validate

Run `validate_manifest design/merged.manifest.json` (explicit argument - a zero-arg run
validates the shipped library manifest instead, a pass that says nothing about your
merge) and confirm every SPEC.md 3.8 gate passes:

- **Namespace enforcement** - in the project manifest, `market-tile`'s id MUST carry the
  document's own `package` as its namespace (`stock_app:market-tile`); a bare id there is
  an error. In the merged view both flavors coexist and each id carries its origin's
  namespace.
- **`utopiaUiVersion` freshness** - required on the project and merged documents; MUST
  equal the resolved `utopia_ui` pubspec version.
- **Embedded-library equality** - the merged view's embedded library section MUST equal
  the shipped library manifest byte-for-byte in content; a stale copy is an error, not a
  warning (same reasoning as the `packageVersion` gate, SPEC.md 3.7).
- **Referential integrity across the merge** - if `MarketTile` composed a project model
  or a library id, that reference must resolve on the merged view.
- **Flat model-name uniqueness** - if `MarketTile` introduced its own model class, its
  name must not collide with a library model name; the merge fails on a collision (flat
  model namespace in MVP).

Full detail on each gate: [overlay-and-manifests.md](overlay-and-manifests.md).

## Step 6 - the id is live

`stock_app:market-tile` now resolves through `design/merged.manifest.json`. Hand it back
to screen building - **utopia-design:screen**'s
[component-mapping.md](../../screen/references/component-mapping.md)
documents the merged manifest as the preferred mapping target once it exists. This
skill's job ends here; it does not itself wire the component into a screen.

## Step 4's exact CLI: `generate_manifest --project`

Fully contracted (verbatim, ships in `utopia_design_tools`):

```
dart run utopia_design_tools:generate_manifest --project [--project-dir <dir>] [--overlay-dir <dir>] [--json] [--timestamp]
```

- Run from inside the consumer project. Default `--project-dir`: walk-up to
  the nearest `pubspec.yaml` that is not `utopia_ui`; exit `2` with guidance
  when none is found, when `utopia_ui` is not resolvable from it, or when NO
  overlay files exist (that message explains the opt-in model - an empty
  overlay dir is a usage error, not an empty manifest).
- Default `--overlay-dir`: `design/overlay/` under the project root.
  Registration and the `class:` override work exactly as Step 3 describes.
- Writes BOTH fixed-path files (SPEC.md 3.8): `design/project.manifest.json`
  (only custom components, namespaced ids, own models/helpers,
  `utopiaUiVersion` stamped from the resolved `utopia_ui`) and
  `design/merged.manifest.json` (`merged: true`; the library half is
  byte-faithful from the pub-cache manifest, never re-extracted; the project
  half is appended; a model-name collision across the halves FAILS the
  merge). It self-validates both before writing: exit `1` plus findings and
  NOTHING written on failure. Deterministic byte-identical reruns.
- On success it may print WARN lines to stderr when a project class shadows
  a library component class name (`composes` resolution is parse-only) -
  heed them and rename the class if the shadowing is accidental.
- Exit codes and `--json`: the shared convention (`0`/`1`/`2`).

A live, committed reference exists: `tool/utopia_design_tools/test/fixtures/
project_consumer/` in the utopia-ui repo - a real mini package (`demo_consumer`) with a
`MarketTile` (composes `card` + `chip`, a `Quote` model, project-local color constants:
the values-on-the-side pattern), a `DemoRatingStars` registered via the `class:`
override as `demo_consumer:star-rating`, and an `UnregisteredWidget` proving opt-out.
Run the CLI against a COPY of that fixture to see live output end-to-end.

## See also

- [overlay-and-manifests.md](overlay-and-manifests.md) - the overlay key reference in
  full, the three-document model, and what `validate_manifest` enforces
- **utopia-design:screen**'s
  [gap-reporting.md](../../screen/references/gap-reporting.md) - where the
  component-spec seed this loop starts from comes from
- **utopia-design:screen**'s
  [component-mapping.md](../../screen/references/component-mapping.md) -
  how the resulting namespaced id gets used in a screen
