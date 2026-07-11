# Token Profile - The Canonical Tree

## How to use this

`design/tokens.json` is a **closed** tree: only the paths below are valid,
and `validate_tokens` rejects any name it does not recognize (SPEC.md section
2.2). Before adding or renaming anything, check it against this table -
never invent a name or type. This is the map to grep while editing; condensed
from SPEC.md section 2.2 (tree) and 2.3 (type mapping), which stays the source
of truth - if this table and the running validator ever disagree, SPEC.md wins.

## The canonical tree

| Path | `$type` | Constraints | Note |
|---|---|---|---|
| `x` | `number` | > 0 | Base unit, logical px. Everything base-derived scales off this. |
| `spacing.{xxs,xs,sm,md,lg,xl,xxl,xxxl}` | `dimension` | unit `px`; base-derived | 8 steps |
| `radius.{xs,sm,md,lg,xl}` | `dimension` | unit `px`; base-derived | 5 steps |
| `radius.full` | `dimension` | unit `px`; **NOT** base-derived (value `9999`) | never carries a `derivation` extension |
| `border.{hairline,thin,thick}` | `dimension` | unit `px` | 3 steps |
| `shadow.{sm,md,lg}` | `shadow` | array form, even for a single layer | 3 steps |
| `fontWeight.{regular,medium,semiBold,bold}` | `fontWeight` | numeric, 100..900 step 100 | 4 steps |
| `duration.{xs,sm,md,lg,xl}` | `duration` | unit `ms` | 5 steps |
| `breakpoint.{tablet,web,sidebar}` | `dimension` | unit `px` | 3 steps |
| `color.<name>` | `color` | sRGB with hex fallback | 18 names total (17 required + `divider` OPTIONAL) - see below |
| `textStyle.{header,label,text,title,caption,button}` | `typography` | see "The typography wrinkle" below | 6 roles |
| `textStyle-colors.{header,label,text,title,caption,button}` | `color` | one per `textStyle` role, no exceptions | 6 roles |
| `theme.borderRadius` | `dimension` | literal value or alias | |
| `theme.cardRadius` | `dimension` | literal value or alias | |
| `theme.fieldContentPadding.{top,right,bottom,left}` | `dimension` | literal value or alias | 4 sub-members |
| `theme.fieldMinHeight` | `dimension` | literal value or alias | |
| `theme.pageTopPadding` | `dimension` | literal value or alias | |
| `theme.tileHeight` | `dimension` | literal value or alias | |

Top-level name `custom` is reserved for a possible future consumer-extension
group (would land as an additive minor-version change per VERSIONING.md);
protocol 0.1 documents stay closed to unknown names, `custom` included.

## The `color.<name>` group

| Name | Required? |
|---|---|
| `primary` | required |
| `accent` | required |
| `field` | required |
| `canvas` | required |
| `error` | required |
| `disabled` | required |
| `text` | required |
| `surface` | required |
| `border` | required |
| `rowAlt` | required |
| `hover` | required |
| `chipBackground` | required |
| `chipForeground` | required |
| `hint` | required |
| `onColoredContent` | required |
| `onColoredSelected` | required |
| `onColoredHover` | required |
| `divider` | **OPTIONAL** |

An absent `color.divider` is meaningful, not missing data: it means "derive a
contrast-safe divider colour from `color.text` over `color.surface` at paint
time." Never invent a concrete value to fill it in.

## The typography wrinkle

DTCG `typography` has no color property, but `TextStyle` needs one, so the
profile pairs every typography token with a sibling color token:

- Every `textStyle.<role>` MUST have a matching `textStyle-colors.<role>`.
- The typography token's `$extensions["io.utopiasoft.design"].colorToken`
  records the sibling's reference path (e.g. `"textStyle-colors.header"`).
- `typography` `$value` contains exactly: `fontFamily` (string or array of
  strings), `fontSize` (dimension px), `fontWeight` (number), `letterSpacing`
  (dimension px). `lineHeight` is **NOT** part of the profile in v0 -
  `utopia_ui` does not set it.
- A packaged font family (the default theme's Sora ships inside `utopia_ui`)
  records `$extensions["io.utopiasoft.design"].fontPackage` (e.g.
  `"utopia_ui"`) so generated Dart can reconstruct `TextStyle(package: …)`.
  Twin generators ignore this key.

## Type-mapping rules (Flutter <-> DTCG)

| Flutter value | DTCG shape |
|---|---|
| `double` logical px | `{"value": <number>, "unit": "px"}` (`dimension`) |
| `Duration` | `{"value": <ms>, "unit": "ms"}` (`duration`) |
| `FontWeight.w<N>` | `<N>` as a bare number (`fontWeight`) |
| `Color` | `{"colorSpace": "srgb", "components": [r, g, b], "alpha": a, "hex": "#rrggbb"}`, components = channel / 255 |
| `List<BoxShadow>` | array of shadow objects: `color`, `offsetX`, `offsetY`, `blur`, `spread` (all `dimension` px; `spread` is `0` when unset) |
| `TextStyle` | `typography` composite + sibling color token (see above) |
| `BorderRadius.all(Radius.circular(r))` | a single `dimension` of `r` |
| `EdgeInsets.fromLTRB(l, t, r, b)` | group of four `dimension` tokens: `top` / `right` / `bottom` / `left` |

The profile assumes **uniform corner radii** for `theme.borderRadius` and
`theme.cardRadius` (`BorderRadius.all` only) - non-uniform `BorderRadius` is
out of scope in v0.

### Color rules

- `colorSpace` MUST be `"srgb"` in v0.
- `hex` MUST be present: 6-digit lowercase CSS hex of the RGB channels
  (alpha is never encoded in `hex`).
- `alpha` SHOULD be emitted explicitly even when `1`, for stable diffs;
  readers MUST treat an absent `alpha` as `1`.
- Component values are `channel / 255`, at most 6 fractional digits.

## The `io.utopiasoft.design` extension namespace

| Key | On | Type | Meaning |
|---|---|---|---|
| `derivation` | token | string `"x*<n>"` | base-unit multiple (see `rebranding.md`) |
| `colorToken` | typography token | string | reference path of the sibling color token |
| `fontPackage` | typography token | string | Flutter package bundling the font family |
| `profileVersion` | document root | string | protocol version the document targets (see `validation.md`) |
| `lastSyncedValue` | token | any | snapshot of `$value` at last external sync |
| `lastSyncedAt` | token | string (ISO 8601) | timestamp of last external sync |
| `sourceRef` | token | string | opaque identity in the external source (e.g. a Figma variable id) |

Unknown keys under this namespace MUST be preserved on any rewrite and
SHOULD be warned about by the validator. Foreign vendor namespaces (e.g.
`com.figma.*`) MUST be preserved untouched.

## When to add a new entry

Never. The tree is closed by design (SPEC.md section 2.2): a token with no
landing spot in `UtopiaThemeData` would be silently dead on the Flutter
surface. If a design needs a value this tree has no slot for, that is a
protocol gap to raise upstream, not something to patch around by inventing a
token name.

## Known v0 limits (say this, don't improvise)

Two collisions come up in almost every real brand kit - both are known,
deliberate v0 limits, and the correct response is to state them plainly:

- **Dark mode / theme modes.** The token document is single-context by
  design (SPEC.md 2.1: no modes, no themes-in-one-file; the DTCG Resolver
  module is out of scope in v0). Do not attempt to encode a dark palette
  into this tree - not as a second file wired into the protocol, not as
  invented `dark*` names. Tell the user dark mode is outside protocol v0
  and leave their dark values untouched wherever they live today. A
  dark-ONLY brand is legal, though - it is simply a rebrand of the single
  context (edit the existing tree to dark values); what v0 cannot do is
  carry light AND dark palettes simultaneously.
- **success / warning semantic colors.** `color.*` has no success or
  warning slot because `UtopiaThemeColors` has no such fields - the tree
  cannot land what the theme cannot hold (a known library gap, already
  raised upstream). Map `error` (the slot that exists); report success /
  warning values as unmapped gaps (via **utopia-design-import**'s gap
  reporting when importing), never shoehorn them into unrelated slots.

## See also

- [rebranding.md](rebranding.md) - the rules for changing values inside this tree safely
- [validation.md](validation.md) - how `validate_tokens` enforces this tree's shape
