# Rebranding design/tokens.json

## What this pattern is

Rebranding is editing values inside the closed token tree - colors, the base
unit, aliases, typography - without breaking the coherence guarantees
`validate_tokens` enforces. The tree shape never changes; only values do.

## When this applies

Any edit to `design/tokens.json` after bootstrap (`getting-started.md`).
Applies to the whole tree in [token-profile.md](token-profile.md); does not apply to the
Flutter theme code or twin CSS - those are generated, never hand-edited.

## Rules

1. **A color edit sets `components`, `hex`, and `alpha` together.**
   `components` are `channel / 255` (at most 6 fractional digits), `hex` is
   the matching 6-digit lowercase form, `alpha` is explicit even at `1`.
   *Why:* `validate_tokens` cross-checks `hex` against `components` rounded
   to 8-bit channels (SPEC.md 2.3, 2.7 gate 4) - editing only one of the two
   representations produces a document that fails validation.

2. **Rescaling the whole system means changing `x` and re-deriving every
   `derivation`-carrying token, not just `x` itself.** Every base-derived
   token (all of `spacing.*`, `radius.*` except `radius.full`, plus
   `theme.fieldContentPadding.top/bottom` and `theme.fieldMinHeight` in the
   default theme) records its multiple as
   `$extensions["io.utopiasoft.design"].derivation: "x*<n>"`. *Why:* the
   validator's scale-coherence gate requires `value == x.value * multiple`
   (float tolerance 0.001, SPEC.md 2.5); changing `x` alone leaves every
   derived token stale and failing validation. If a token is deliberately
   edited away from its multiple, its `derivation` extension MUST be
   dropped or updated to match - a stale `derivation` string is worse than
   none, because the validator will flag the value as wrong when the value
   is actually a deliberate override.

3. **`theme.*` slots may be an alias or a literal - both are valid.** The
   default theme expresses several as aliases (`theme.borderRadius =
   {radius.sm}`, `theme.cardRadius = {radius.xl}`, `theme.pageTopPadding =
   {spacing.xxxl}`, `theme.fieldContentPadding.left/right = {spacing.lg}`).
   *Why:* an alias keeps the slot tracking its source token automatically
   (rescale `x`, the slot follows); a literal decouples it. Replacing an
   alias with a literal is a design decision, not drift - do it deliberately,
   not by accident when copy-pasting a value.

4. **A `textStyle.<role>` edit is two edits, not one.** Change the typing
   values on `textStyle.<role>` (`fontFamily`, `fontSize`, `fontWeight`,
   `letterSpacing`) and the color on its sibling `textStyle-colors.<role>`
   together; keep `$extensions["io.utopiasoft.design"].colorToken` pointing
   at that sibling's path. If the font ships inside a Flutter package (like
   the default theme's Sora inside `utopia_ui`), keep `fontPackage` set so
   generated Dart can rebuild `TextStyle(package: …)`. *Why:* DTCG
   `typography` has no color property - the sibling-token binding is how
   this profile carries `TextStyle.color` at all (SPEC.md 2.4). Editing only
   one side of the pair produces a color/type mismatch on the generated
   Flutter surface.

5. **Never drop `$extensions` data you don't recognize.** Any rewrite of
   `design/tokens.json` MUST preserve extension keys it doesn't understand,
   including foreign vendor namespaces (`com.figma.*`) and unknown keys
   inside `io.utopiasoft.design`. *Why:* `$extensions` MUST round-trip by
   DTCG rule (SPEC.md 2.1, 2.6); this is also how three-way import diffing
   (`lastSyncedValue` / `lastSyncedAt` / `sourceRef`) stays intact across
   edits made through this skill.

## How to apply

### A color change

Before (the canonical default-theme value):

```json
"primary": { "$type": "color", "$value": {
  "colorSpace": "srgb", "components": [0.32549, 0.427451, 0.996078],
  "alpha": 1, "hex": "#536dfe" } }
```

After (rebrand to a green primary; components stay `channel / 255` at up to
6 fractional digits so the `hex` cross-check keeps passing):

```json
"primary": { "$type": "color", "$value": {
  "colorSpace": "srgb", "components": [0.133333, 0.772549, 0.368627],
  "alpha": 1, "hex": "#22c55e" } }
```

### An `x` rescale

Before (`x = 4`, `spacing.md` at its `x*3` multiple):

```json
"x": { "$type": "number", "$value": 4 },
"spacing": { "md": { "$type": "dimension", "$value": { "value": 12, "unit": "px" },
  "$extensions": { "io.utopiasoft.design": { "derivation": "x*3" } } } }
```

After (`x = 5` - `spacing.md` re-derived to `5 * 3 = 15`, `derivation`
unchanged because the multiple itself didn't change):

```json
"x": { "$type": "number", "$value": 5 },
"spacing": { "md": { "$type": "dimension", "$value": { "value": 15, "unit": "px" },
  "$extensions": { "io.utopiasoft.design": { "derivation": "x*3" } } } }
```

Every other `derivation`-carrying token needs the same re-derive pass; run
`validate_tokens` afterwards to confirm nothing was missed
([validation.md](validation.md)).

## Anti-patterns

- **Adding a token name outside the closed tree** (e.g. a new `color.brand2`)
  because the design needs one more slot. The tree doesn't grow by editing;
  see [token-profile.md](token-profile.md) "When to add a new entry."
- **Changing a derived token's value without touching its `derivation`
  extension.** Either the value now satisfies a different multiple (update
  the string) or it's a deliberate one-off override (drop the extension) -
  leaving a stale `derivation` string makes the validator report a false
  scale-coherence failure.
- **Editing `textStyle.<role>` and forgetting `textStyle-colors.<role>`** (or
  vice versa). The pair is one logical unit.
- **Hand-editing generated theme Dart or twin CSS** to "fix" a rebrand
  faster. Both are regenerated wholesale by `utopia-design-sync` - a hand
  edit there is silently overwritten (or worse, papers over a
  `design/tokens.json` that's still wrong).

## See also

- [token-profile.md](token-profile.md) - the full closed tree these rules operate over
- [validation.md](validation.md) - `validate_tokens` is how you confirm a rebrand landed
  clean; run it after every edit described here
