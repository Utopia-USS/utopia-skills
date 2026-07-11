# Regenerating the Theme and the Twin

## What this covers

The validated fan-out from `design/tokens.json` to every generated surface:
`validate_tokens` -> `validate_manifest` (drift) -> `generate_theme` +
`generate_twin` -> optionally `validate_twin`. For each command: what it
reads, what it writes, and how to handle its exit code. The "no runtime
sync, explicit step" principle (SPEC.md 6.1) runs through all of it.

## When this applies

After `design/tokens.json` changes - through
[getting-started.md](../../utopia-design-tokens/references/getting-started.md)'s
edit loop, [rebranding.md](../../utopia-design-tokens/references/rebranding.md)'s
rules, or an **utopia-design-import** run - and before treating the app's
theme or the HTML twin as reflecting that change.

## Prerequisite

`utopia_design_tools` must resolve (`flutter pub add --dev
utopia_design_tools`). See `SKILL.md`'s Usage Gate; this doc assumes it
already passed.

## The workflow

```
                     design/tokens.json
                             |
                    1. validate_tokens         <- STOP here on failure
                             |
                    2. validate_manifest       <- drift check, STOP on failure
                             |
              +--------------+--------------+
              v                             v
     3. generate_theme              4. generate_twin
        (Dart theme code)              (tokens.css, tokens.tailwind.css,
                                         DESIGN.md front matter)
              |                             |
              +--------------+--------------+
                             v
                  5. validate_twin (optional)
```

### 1. `validate_tokens` - the pre-regen gate

Fully contracted in **utopia-design-tokens**'s
[validation.md](../../utopia-design-tokens/references/validation.md). Do not
re-derive that contract here - link it. What matters for sync: exit `0`
means continue to step 2; exit `1` (validation failure) or `2` (usage/IO
error) means **STOP** - do not run `generate_theme` or `generate_twin`
against this document. Fix the reported findings (per
[rebranding.md](../../utopia-design-tokens/references/rebranding.md)) and
re-run `validate_tokens` until it passes before touching anything below.

### 2. `validate_manifest` - the drift check

Fully contracted (verbatim, ships in `utopia_design_tools`):

```
dart run utopia_design_tools:validate_manifest [<file>] [--json] [--schema <path>] [--sources <dir>]
```

- Default `<file>`: `manifest/utopia.manifest.json` under the resolved
  `utopia_ui` root (repo-checkout walk-up, else the pub-cache root via
  `.dart_tool/package_config.json`) - in a consumer project this means it
  validates the *shipped* manifest with **zero arguments**.
- The sources root defaults to the `utopia_ui` root resolved **from the
  manifest file's own location** (so a consumer run automatically checks
  against the pub-cache sources); `--sources` overrides. Source-dependent
  gates skip silently when no sources resolve.
- Gates it enforces: schema validity; **`packageVersion` == the resolved
  `utopia_ui` pubspec version - THE drift gate** (SPEC.md 3.7); id
  uniqueness (including exact duplicates) and correct kebab derivation;
  referential integrity (a prop's `modelName` resolves to a `models` entry,
  `composes` ids resolve to real component ids, twin bindings resolve when
  `twin/` exists); file existence plus a declaring-file cross-check;
  `tokenBindings` re-extraction in both directions (a stale binding left in
  the manifest, or a real binding missing from the manifest, are both
  errors); stale-class detection (the manifest names a class no longer
  present in sources).
- Exit codes, stdout finding format, and `--json` shape are identical to
  `validate_tokens`: `0` ok / `1` validation failure (`ERROR <path>: <msg>`
  / `WARN <path>: <msg>` lines, summary last) / `2` usage-or-IO error;
  `--json` = `{"status", "errors": [...], "warnings": [...]}`.

Run this with no arguments in a consumer project. A failure here means
**STOP** the same as step 1 - see
[drift-and-verify.md](drift-and-verify.md) for why a `packageVersion`
mismatch is treated as a hard error rather than something to note and
continue past.

### 3. `generate_theme` - Flutter theme code

Fully contracted (verbatim, ships in `utopia_design_tools`):

```
dart run utopia_design_tools:generate_theme [<tokens-file>] [-o <path>] [--json]
```

- Default `<tokens-file>`: `design/tokens.json` if present, else
  `tokens/utopia.tokens.json`, else exit `2` with the same bootstrap
  copy-command message as `validate_tokens`.
- Default `-o`: `lib/theme/utopia_theme.g.dart` under the current working
  directory (the consumer project); parent directories are created and the
  written path is printed.
- It VALIDATES the input first (the full `validate_tokens` gates): on any
  error it exits `1`, prints the findings (same format and `--json` envelope
  as `validate_tokens`) and writes NOTHING. Step 1 is still worth running
  separately - a broken document should stop the workflow before the drift
  check - but nothing slips past this second gate.
- Output: a `dart_style`-formatted Dart file exposing
  `UtopiaThemeData buildUtopiaTheme()`, built via `UtopiaThemeData.fromTokens`
  plus a minimal `copyWith` (only slots that differ from the `fromTokens`
  arithmetic) and minimal optional colors. Consequence worth knowing: a
  base-derived value that still matches its formula (e.g. `fieldMinHeight`
  after an `x` rescale) will usually NOT appear as a literal number in the
  generated file - it flows through `fromTokens` at runtime. Verify a rescale
  through the running theme (or the twin's `tokens.css`), not by grepping
  the generated Dart for the new number. Deterministic: the same input
  produces byte-identical output; the file's header comment carries the input
  path and the regeneration command.
- Exit codes and `--json`: the shared convention (`0`/`1`/`2`).
- Round-trip guarantee (SPEC.md 5): the theme generated from the canonical
  default-theme export equals `UtopiaThemeData.defaultTheme` up to 8-bit
  color quantization (colors compare by ARGB32 value).

**Wire it or nothing changes.** Generated code is inert until the app uses
it: the app must pass the generated theme explicitly, typically
`UtopiaTheme(data: buildUtopiaTheme(), child: ...)` at the top of the widget
tree. Without that wiring a completed rebrand shows NO visual change and no
error - `UtopiaTheme.of` silently falls back to `defaultTheme`.
`generate_theme` prints this next step after writing. Do not consider a
first sync done until the wiring exists (once wired, it stays wired - later
syncs only regenerate the file).

### 4. `generate_twin` - the HTML twin

Fully contracted (verbatim, ships in `utopia_design_tools`):

```
dart run utopia_design_tools:generate_twin [<tokens-file>] [-o <twin-dir>] [--json] [--skip-tailwind] [--skip-design-md]
```

- Default `<tokens-file>`: the same resolution and bootstrap message as
  `validate_tokens`. Default `-o`: `./twin` under the current working
  directory in a consumer project (inside the `utopia_ui` repo itself it
  targets the package's own `twin/`).
- It VALIDATES the input first: on an invalid token document it exits `1`
  with findings and writes NOTHING - the same double-gate posture as
  `generate_theme`.
- Writes `tokens.css` (every token as a `--utopia-*` custom property per
  SPEC.md 4.2, including the `textStyle-colors` fold), `tokens.tailwind.css`
  (the SPEC.md 4.3 `@theme` mapping; unmapped families kept as comments), and
  `DESIGN.md` - regenerating ONLY the front-matter block and preserving the
  prose body byte-for-byte (malformed front-matter markers fail safe with a
  stderr warning rather than losing the body).
- `--skip-tailwind` / `--skip-design-md` skip those two outputs.
- Deterministic (byte-identical reruns); exit codes and `--json` follow the
  shared convention.

This command produces the twin for a *consumer's* rebranded tokens, distinct
from the default-theme twin `utopia_ui` ships pre-generated in its own pub
tarball (SPEC.md section 1). Run this step CONDITIONALLY, by presence: when
the project already has a `twin/` directory, regenerate it on every sync (a
present surface never stays stale); when it does not, skip it unless the
user explicitly asks - materializing the twin for the first time is an
explicit product choice, never a rebrand side effect.

**Viewing a consumer twin.** `generate_twin` emits stylesheets + `DESIGN.md`
only - the browsable HTML (`gallery.html`, `components.html`, plus
`components.css`) is hand-authored and ships inside the resolved `utopia_ui`
package's `twin/`. To LOOK at a rebrand: copy those three files from
`<utopia_ui root>/twin/` (root resolved via `.dart_tool/package_config.json`,
the same resolution
[getting-started.md](../../utopia-design-tokens/references/getting-started.md)
documents) next to the project's regenerated `twin/tokens.css`, then open
`gallery.html` in a browser. Two caveats: the copied shell is
version-matched to the package - re-copy after a `utopia_ui` upgrade; and
once `components.html` is present in the project twin, `validate_twin`
applies the full-bundle contract again (the auto-partial coverage skip
described in step 5 below no longer applies).

### 5. `validate_twin` - optional post-check

Fully contracted (verbatim, ships in `utopia_design_tools`):

```
dart run utopia_design_tools:validate_twin [--twin-dir <dir>] [--manifest <path>] [--tokens <path>] [--json]
```

- Defaults: the twin directory and the manifest are resolved from the
  `utopia_ui` root (repo checkout, else the pub cache) - the same resolution
  style as every other tool in the family; the flags override. In a consumer
  project this means a NO-ARGS run validates the PACKAGE'S shipped twin, not
  your project-local `twin/` from step 4 - point it at yours explicitly
  (`--twin-dir twin --manifest <resolved manifest path>`) when that is what
  you mean to check.
- `--tokens` overrides the token document backing the `tokens.css` freshness
  gate (auto-discovered otherwise).
- Gates: the literals linter over hand-authored twin CSS AND inline
  `<style>` blocks in the twin HTML (full SPEC.md 4.5 rule set, including
  the `/* utopia-literal-ok: <reason> */` same-line exception), plus
  `style="..."` attributes (raw colors/fonts hard-fail there; raw dimensions
  are allowed as specimen scaffolding); `data-utopia-id` coverage in BOTH
  directions against the manifest (note entries count as covered); and
  tokens.css freshness (regenerate-and-byte-compare, invocation-independent).
- Exit codes and `--json`: the shared convention (`0`/`1`/`2`).

Scope note for consumer projects: the `data-utopia-id` coverage gate
presupposes `components.html` - which is hand-authored (maintainer-side),
never produced by `generate_twin`. The tool handles this itself
(AUTO-PARTIAL MODE): when `components.html` is absent from the target twin
directory - a generated-only consumer twin - the coverage gate auto-skips
with an info line on stderr, while the literals linter and the tokens.css
freshness gate still run. No flag needed; the presence of the hand-authored
surface is the signal. So running `validate_twin --twin-dir twin` against a
generated-only project twin is safe and still buys the freshness check.

See [drift-and-verify.md](drift-and-verify.md) for what each gate flags and
why. Not required to consider a sync run complete, but recommended before
the twin output is viewed or shipped.

## No runtime sync - regeneration is explicit

There is no watching, no file-system observer, no network call anywhere in
this workflow (SPEC.md 6.1). A change made on any other surface - a tweak
in the twin's CSS, a value edited in an external design tool - becomes
durable only by landing in `design/tokens.json` and running this workflow
again. Nothing here runs automatically in the background.

## Never hand-edit generated output

The Dart theme file, `twin/tokens.css`, `twin/tokens.tailwind.css`, and the
`DESIGN.md` front-matter block are all generated. A hand-edit to any of them
is silently overwritten the next time this workflow runs, and in the
meantime misrepresents what `design/tokens.json` says. If the output looks
wrong, the fix is always upstream: correct `design/tokens.json` (via
**utopia-design-tokens**) and re-run this workflow, never patch the
generated file directly.

## See also

- [validation.md](../../utopia-design-tokens/references/validation.md) -
  the full `validate_tokens` contract (step 1); not duplicated here.
- [drift-and-verify.md](drift-and-verify.md) - the why-first reasoning
  behind the drift check (step 2) and `validate_twin` (step 5).
