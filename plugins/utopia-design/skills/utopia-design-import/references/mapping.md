# Mapping External Values onto the Closed Tree

## What this pattern is

Rules for turning parsed external values (-> [sources.md](sources.md)) into
matches against the closed utopia token tree, plus the gap-reporting
discipline for anything that doesn't fit. This is a pattern, not a
workflow step by itself: the output is a set of proposed matches, not an
edit - the edit only happens after the proposal and diff are shown and
approved (-> [three-way-diff.md](three-way-diff.md)).

## When this applies

After a source's values are parsed (-> [sources.md](sources.md)), before the
mapping proposal and diff are produced (-> [three-way-diff.md](three-way-diff.md)).
Never write `design/tokens.json` directly from this step.

## The mapping target

The target is the closed utopia tree, documented in full in
**utopia-design-tokens**'s
[token-profile.md](../../utopia-design-tokens/references/token-profile.md).
This doc does not repeat that tree - it only covers how an *external* value
gets matched onto a path in it.

## Rules

Rules 1-3 are the matching side (SPEC.md 6.2's priority: `sourceRef`, then
the token-path tier - split here into literal name/path and semantic role;
SPEC's third tier, the value fingerprint, applies only on re-import ->
[three-way-diff.md](three-way-diff.md)). Rules 4-5 govern value conversion
and scope, not matching.

1. **Match priority when re-importing an already-synced token: `sourceRef`
   first.** If an external token carries (or is known by) the same opaque
   id recorded in a utopia token's `$extensions["io.utopiasoft.design"].sourceRef`,
   that's the match - skip name/role matching entirely for it. *Why:* an id
   is stable across renames and value changes, so it is the only match that
   survives a designer reorganizing their source between exports.
2. **Otherwise match by name/path similarity.** A source path or variable
   name that closely mirrors a utopia path (`Primary/500` next to a
   `color.primary` slot, `radius-lg` next to `radius.lg`) is a strong
   candidate match. *Why:* names are the cheapest reliable signal on a first
   import, where no `sourceRef` has been recorded yet.
3. **Otherwise match by semantic role.** A source token named "brand" or
   "primary" maps to `color.primary` even with no literal name overlap; a
   source "radius-lg" maps to `radius.lg` by what it represents, not what
   it's called. Role matching is a judgment call - when two utopia slots are
   both plausible, prefer the more specific one and note the alternative
   considered in the gap/proposal output. *Why:* foreign sources rarely share
   utopia's names, so role is often the only bridge - and because it is
   inferential, the proposal/diff gate exists to confirm it before any write.
4. **Convert the value using the SPEC.md section 2.3 type-mapping table,
   exactly.** Hex/rgb colors become `srgb` components (`channel / 255`,
   at most 6 fractional digits) plus a matching lowercase 6-digit `hex`
   fallback; `px` values become `dimension` (`{value, unit: "px"}`); `ms`
   values become `duration`; a bare font-weight number maps straight to
   `fontWeight`; a CSS `box-shadow` string becomes the shadow array form;
   typography values become the `typography` composite plus its
   `textStyle-colors` sibling, with `$extensions["io.utopiasoft.design"].colorToken`
   pointing at that sibling's path. *Why:* this is the exact table
   `validate_tokens` gates 1 and 4 check against - a converted value that
   skips it produces a document that fails validation on the very next run.
5. **The SPEC.md section 4.2 reverse CSS-var mapping only applies to
   `--utopia-*` prefixed variables** (a twin re-export), never to a
   genuinely foreign `tokens.css`'s own naming - see
   [sources.md](sources.md) for the split. *Why:* applying the reverse
   mapping to a foreign var assumes utopia's naming scheme and silently
   mis-slots values; only the `--utopia-*` prefix proves the twin produced it.

## Re-import value fingerprint (the third matching tier)

SPEC.md section 6.2's re-import matching priority is `sourceRef` -> token
path -> **value fingerprint**. The fingerprint tier is the last resort: when
an external token has no `sourceRef` and no path/name match, an external
value equal to an existing utopia token's `lastSyncedValue` (or current
`$value`) is a *candidate* match for that token under a changed name. Treat
it as a candidate only - surface it in the proposal for explicit
confirmation, never auto-apply, because distinct tokens can legitimately
share a value (two greys, two 8px steps) and a fingerprint match may be
coincidental.

## GAP reporting

- **Any external token with no matching utopia slot is a gap**, never a
  silent drop and never an invented tree name. List it as: the external
  name/path, the closest utopia slot considered (if any), and why it was
  rejected as a match. (SPEC.md section 2.2 - the tree is closed by design;
  a name with no landing spot in `UtopiaThemeData` would be silently dead on
  the Flutter surface.)
- **Any utopia slot the source doesn't cover is listed separately** as
  "uncovered - left at current value." This isn't an error, just
  information the proposal must surface (-> [three-way-diff.md](three-way-diff.md)).
- This gap discipline mirrors **utopia-design-screen**'s component-gap
  reporting: the same "report it, don't paper over it" posture applied to
  tokens instead of components.
- Two gaps are predictable enough to have a scripted answer - a dark palette
  (single-context protocol, out of v0 by design) and success/warning
  semantic colors (no `UtopiaThemeColors` slot to land in). See
  **utopia-design-tokens**'s
  [token-profile.md](../../utopia-design-tokens/references/token-profile.md)
  "Known v0 limits" for the exact response; do not improvise one.

## Anti-patterns

- **Silently dropping an unmapped external token** instead of reporting it
  as a gap - the whole point of the closed tree is that nothing gets lost
  without a trace.
- **Inventing a tree name** (e.g. a new `color.brand2`) to give an unmatched
  external value somewhere to live. The tree doesn't grow by importing; see
  [token-profile.md](../../utopia-design-tokens/references/token-profile.md)
  "When to add a new entry."
- **Converting a color's `components` without updating its `hex`** (or vice
  versa) - produces a `validate_tokens` gate-4 failure immediately.
- **Importing a raw value into a `derivation`-carrying token** (one under
  `$extensions["io.utopiasoft.design"].derivation`) without fixing or
  dropping that extension to match - defer to **utopia-design-tokens**'s
  [rebranding.md](../../utopia-design-tokens/references/rebranding.md) rule 2
  for the exact re-derive mechanics; an import that skips this leaves the
  document scale-incoherent.

## See also

- [token-profile.md](../../utopia-design-tokens/references/token-profile.md) -
  the mapping target, the closed tree itself
- [rebranding.md](../../utopia-design-tokens/references/rebranding.md) - the
  value-conversion and derivation rules a mapped-in value must still respect
- [sources.md](sources.md) - where the values being mapped came from
- [three-way-diff.md](three-way-diff.md) - what happens after mapping: the
  proposal, the diff, and the eventual write
