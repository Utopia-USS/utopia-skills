# Drift and Verify: Why the Gates Exist

## What this covers

Why [regeneration.md](regeneration.md)'s workflow refuses to continue past a
`validate_manifest` drift failure, how `profileVersion` and `packageVersion`
relate as two separate version streams, what `validate_twin`'s literals
linter and `data-utopia-id` coverage check actually flag, and the
refuse-on-failure rationale that ties all of it together. This doc is the
"why" and "what to do"; the exact invocations are in
[regeneration.md](regeneration.md) - not repeated here.

## packageVersion drift (validate_manifest, SPEC.md 3.7)

`manifest/utopia.manifest.json` stamps a `packageVersion` from the
`utopia_ui` `pubspec.yaml` it was generated against. `validate_manifest`
fails whenever that stamped `packageVersion` differs from the `utopia_ui`
version the current project actually resolves. That mismatch means the
manifest - and therefore the component API, token bindings, and twin
bindings it describes - no longer matches the library code the project
links against.

Why this blocks sync specifically: `generate_theme` and `generate_twin`
both trust that the resolved `utopia_ui` is the one the rest of the
tooling (and this skill's own guidance) was built to describe. Regenerating
the theme or the twin while that assumption is false means producing output
that *looks* fresh but is quietly stale relative to the actual library -
worse than not regenerating at all, because nothing else signals the
problem.

What a consumer does about it: `packageVersion` drift is **not** something
a consumer project fixes by editing the manifest - the manifest ships
inside the `utopia_ui` pub tarball and is regenerated maintainer-side, per
release. The only consumer-side fix is to resolve a version of `utopia_ui`
whose shipped manifest matches (typically: update the pubspec constraint,
run `flutter pub get`, and re-run `validate_manifest`). Never hand-edit the
resolved manifest to make the check pass.

## profileVersion and packageVersion are two independent streams (VERSIONING.md)

It is easy to conflate these two checks; they guard different things:

| | Lives on | Checked by | Guards |
|---|---|---|---|
| `profileVersion` | `design/tokens.json` root (`$extensions["io.utopiasoft.design"].profileVersion`) | `validate_tokens` (step 1) | the token document's own compatibility with the protocol version |
| `packageVersion` | the manifest (`packageVersion` field) | `validate_manifest` (step 2) | the manifest's compatibility with the resolved `utopia_ui` release |

(The manifest additionally carries its own `schemaVersion` field - the
protocol version stream, per VERSIONING.md - which is a separate concern
from the `packageVersion` drift gate this section is about.)

By the time step 2 runs, step 1 has already confirmed the token document
itself declares a compatible `profileVersion` (same major as the validator,
warn on newer minor, fail on a different major, warn if missing - see
**utopia-design-tokens**'s
[validation.md](../../utopia-design-tokens/references/validation.md) for
the full table; not repeated here). Step 2 asks the separate question:
does the manifest describing the *library* agree with the library actually
resolved? VERSIONING.md is explicit that these are independent streams - a
project can have a perfectly compatible `profileVersion` on its tokens and
still fail the manifest's `packageVersion` check, and vice versa. Sync's
refuse-on-failure logic treats both as real errors; neither is skippable
because the other one passed.

## validate_twin: literals linter + data-utopia-id coverage (SPEC.md 4.5, 4.4)

When run (step 5, optional but recommended), `validate_twin` checks two
independent things:

**The literals linter** flags raw values in `components.css` that have a
token equivalent, because a raw value there is a value that regeneration
cannot keep in sync with a token edit:

- **Hard-fail:** raw hex/rgb/hsl colors; raw `px` values that match any
  *current* spacing/radius/border token value; raw `font-family` or
  `font-weight` literals.
- **Warn:** any other raw `px`, `ms`, or unitless numeric literal.
- **Allowed exceptions (never flagged):** `9999px` / `--utopia-radius-full`
  usage (the `radius.full` token is deliberately not base-derived and is
  the one legitimate "raw-looking" 9999 value - see
  [rebranding.md](../../utopia-design-tokens/references/rebranding.md) and
  SPEC.md 2.5); bare `0`; percentage/fraction layout values; and any value
  annotated `/* utopia-literal-ok: <reason> */` on the same line - that
  annotation IS the documented-inline mechanism for CSS-only concerns such
  as a `1px` hairline tweak (SPEC.md 4.5).
- **Scope:** hand-authored `.css` files AND inline `<style>` blocks in the
  twin HTML get the full rule set; `style="..."` attributes are specimen
  scaffolding - raw dimensions are allowed there, raw colors and font
  literals still hard-fail (SPEC.md 4.5).

**`data-utopia-id` coverage** checks BOTH directions against the manifest:
every manifest component has a `components.html` section carrying
`data-utopia-id="<manifest id>"` (a "no visual twin" note entry counts as
covered), and every id used in the twin resolves to a real manifest
component (SPEC.md 4.4). A component missing this marker breaks the twin's
cross-surface contract - agents and tools that reference components by id
can no longer locate it in the rendered twin.

**tokens.css freshness** regenerates the twin's `tokens.css` from the token
document and byte-compares it against the shipped file (invocation-
independent) - a stale generated stylesheet is the exact drift the
regeneration workflow exists to prevent, caught at validation time.

Both checks exist because the twin's whole value proposition is that its
visual values resolve through `var(--utopia-*)` references generated from
the token document (SPEC.md 4.4) - a raw literal or a missing id is a spot
where that guarantee has silently broken.

## Refuse-on-failure, always

Every gate in this skill's workflow - `validate_tokens`, `validate_manifest`,
and (when run) `validate_twin` - exists for the same reason: a broken or
drifted source must never reach a rendered surface. "Refuse and report" is
always the correct response to a failing gate, never "regenerate anyway and
see if it looks fine" or "patch the generated output to compensate." The
fix is always upstream - the token document, the resolved package version,
or the twin's own hand-authored CSS - never downstream in generated files.

## See also

- [regeneration.md](regeneration.md) - the exact workflow and command
  invocations these gates sit inside.
- **utopia-design-tokens**'s
  [validation.md](../../utopia-design-tokens/references/validation.md) -
  the full `validate_tokens` contract and `profileVersion` compatibility
  table.
