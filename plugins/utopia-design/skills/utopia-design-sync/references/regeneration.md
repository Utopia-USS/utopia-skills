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

Role-level (see the stub below for the exact CLI): reads `design/tokens.json`
and emits a Dart file exposing a `UtopiaThemeData` factory built via
`UtopiaThemeData.fromTokens` plus `copyWith` for the semantic slots
(SPEC.md 5). Round-trip guarantee: exporting `defaultTheme` and then running
`generate_theme` on that export MUST produce a theme equal to `defaultTheme`
up to 8-bit color quantization (colors compare by ARGB32 value). Exact
output path is not yet contracted - do not guess it; invoke the tool per its
own `--help`/contract once available.

### 4. `generate_twin` - the HTML twin

Role-level (see the stub below for the exact CLI): reads
`design/tokens.json` and emits `twin/tokens.css`, `twin/tokens.tailwind.css`,
and the `DESIGN.md` front-matter block (SPEC.md 5, 4.1-4.3). CSS custom
property naming, the Tailwind `@theme` mapping, and the `DESIGN.md` front
matter shape are all specified in SPEC.md section 4 - this command is what
produces them for a *consumer's* rebranded tokens, distinct from the
default-theme twin `utopia_ui` ships pre-generated in its own pub tarball
(SPEC.md section 1). Exact output location and flags are not yet
contracted - do not guess them.

### 5. `validate_twin` - optional post-check

Role-level (see the stub below for the exact CLI): the literals linter plus
`data-utopia-id` coverage check against the manifest (SPEC.md 4.5, 4.4). See
[drift-and-verify.md](drift-and-verify.md) for what it actually flags and
why. Not required to consider a sync run complete, but recommended before
the twin output is viewed or shipped.

## Exact generate CLI (pin when A4/A5/A6 land - RFC-B3)

`generate_theme`, `generate_twin`, and `validate_twin` are contracted today
only at the role level above (SPEC.md section 5) - their tool executables
are not yet published. Do **not**
invent specific flags, defaults, or output paths for them. Once their CLI
lands, invoke each per its own contract or `--help` output, following the
shared convention already locked for every command in this family: exit `0`
success / `1` validation-or-generation failure / `2` usage-or-IO error,
`--json` for machine-readable output, installed via
`flutter pub add --dev utopia_design_tools`. This section is the single
place to update once that CLI is published.

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
