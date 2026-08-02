# The Mapping Proposal, Diff, and Re-Import Conflicts

## What this is

The non-silent contract for import (SPEC.md section 6.2): after mapping
(-> [mapping.md](mapping.md)), always produce a proposal and an explicit
diff, and stop for review, before writing anything to `design/tokens.json`.
This is a workflow document, not a pattern or a module - it walks through
the proposal step, the sync metadata written on apply, and how a second
import against the same source gets reconciled against local drift.

## When this applies

Every time, after mapping is complete and before any edit to
`design/tokens.json` - including the very first import of a source, not
just re-imports.

## The proposal and diff format

Before ANY write, show:

- a per-token list or table: current value -> proposed value -> which
  external source token it came from
- the gaps list (external tokens with no utopia slot, with the closest
  slot considered and why it was rejected - see
  [mapping.md](mapping.md))
- the uncovered-slots list (utopia paths this source doesn't touch, staying
  at their current value)
- any **coherence side-effect** a proposed value triggers, so the reviewer
  sees the full consequence, not just the raw value change. The common one:
  a value mapped onto a `derivation`-carrying token (e.g. importing `16px`
  into a `radius.lg` that has `derivation: "x*3"`) forces that `derivation`
  extension to be dropped or updated at apply time - flag it in the diff row.
  See [mapping.md](mapping.md) anti-patterns.

Stop here. Nothing is written until this is shown and the user approves it
(or picks a conflict mode, below, for any conflicted tokens). An import that
writes `design/tokens.json` before this proposal is shown is a bug, not a
shortcut - this is the headline rule of the whole skill.

## Sync metadata (written on apply, SPEC.md section 2.6)

On every token an import actually writes, record under
`$extensions["io.utopiasoft.design"]`:

- `sourceRef` - an opaque id from the external source (a Figma variable id
  when available; otherwise the source path or another stable identifier).
  Convention: for CSS-file sources use `<source-path>#<custom-property-name>`;
  for Figma DTCG use the variable id verbatim - a re-import can only make the
  first-priority `sourceRef` match if the convention is reproduced.
- `lastSyncedValue` - a snapshot of `$value` at the moment of this sync
- `lastSyncedAt` - an ISO 8601 timestamp, supplied by the agent doing the
  import, never read from the source - obtain it from the environment clock
  (e.g. `date -u +%Y-%m-%dT%H:%M:%SZ`); never invent a time of day. If only
  the date is trustworthy, a date-precision timestamp (`T00:00:00Z`) is
  acceptable, but prefer the real clock.

These three keys are what turn a second import against the same source into
a 3-way diff instead of a blind overwrite.

## Re-import 3-way diff (SPEC.md section 6.2)

When reconciling a new source snapshot against the current document,
matching priority is: `sourceRef` -> token path -> value fingerprint (first
match wins - `sourceRef` is [mapping.md](mapping.md) rule 1, the value
fingerprint is defined in [mapping.md](mapping.md) "Re-import value
fingerprint").

A token is **conflicted** when BOTH sides changed since `lastSyncedValue`:
the external source's current value differs from `lastSyncedValue`, AND the
local `design/tokens.json` value also differs from `lastSyncedValue`. A
token where only one side changed is not a conflict - it's a plain update
(source changed, local didn't) or a plain local edit to leave alone (local
changed, source didn't).

The four conflict modes, the conflict definition, and the
`lastSyncedValue` / `lastSyncedAt` advancement below are all normative
SPEC.md section 6.2: resolving via `theirs` or `ours` refreshes them to the
resolved value (the decision becomes the new merge base, so a resolved
conflict does not loop forever), while `skip` leaves them untouched, so a
deferred conflict deliberately resurfaces on the next import. One detail is
this skill's convention rather than a SPEC mandate: `sourceRef` is recorded
or refreshed on every applied resolution (`theirs` and `ours` alike) - the
binding to the matched external token survives whichever side won.

Conflict modes:

- **`ask` (default)** - report the conflict, write nothing for that token.
  Example: `color.primary` was `#536dfe` at last sync; the local file now
  has `#22c55e` (a manual rebrand) and the new export has `#3b82f6` (a
  designer change) - both differ from `lastSyncedValue`, so `ask` reports
  both values side by side and waits.
- **`theirs`** - take the source's new value, discarding the local edit.
  Same example: `theirs` writes `#3b82f6`, overwriting the local `#22c55e`,
  and refreshes `sourceRef` / `lastSyncedValue` / `lastSyncedAt` to record
  the resolution.
- **`ours`** - keep the local value, declining the source's incoming
  change for this token. Same example: the token stays `#22c55e`;
  `lastSyncedValue` / `lastSyncedAt` still refresh to record that this
  conflict was seen and resolved in favor of the local value, so the same
  diff doesn't resurface next time for no reason; `sourceRef` refreshes the
  same way it does under `theirs`, keeping the external binding intact.
- **`skip`** - leave this one token untouched entirely, including its sync
  metadata, and continue processing every other token normally. Same
  example: nothing changes for `color.primary` at all; because
  `lastSyncedValue` doesn't advance, this exact conflict resurfaces on the
  next import - which is the point of `skip`: it defers the decision rather
  than making one.

`theirs` / `ours` / `skip` only ever apply on an explicit per-conflict
choice - never as a silent fallback. Absent an explicit choice, every
conflicted token is reported under `ask` and nothing is written for it.

## Close

Once the proposal is approved (and any conflicts resolved), apply by
editing `design/tokens.json` per **utopia-design:tokens**'s
[token-profile.md](../../tokens/references/token-profile.md)
shapes, writing the sync metadata above, then run `validate_tokens` per
that skill's
[validation.md](../../tokens/references/validation.md). Once the
import lands and validates, hand off to **utopia-design:sync** to
regenerate the Flutter theme and the HTML twin - this skill's job ends at
the validated write.

## See also

- [mapping.md](mapping.md) - how the matches shown in the proposal were
  produced
- [sources.md](sources.md) - where the values being diffed came from
- [token-profile.md](../../tokens/references/token-profile.md) -
  the shapes the applied write must conform to
- [validation.md](../../tokens/references/validation.md) - the
  `validate_tokens` gate every applied import must pass
