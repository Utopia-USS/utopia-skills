# Validating design/tokens.json

## What this covers

`validate_tokens` is the real gate on every `design/tokens.json` edit. This
doc is its CLI contract, the gates it enforces, and how it relates to the
lightweight PostToolUse hook that also touches this file.

## When this applies

After every edit made under [getting-started.md](getting-started.md)'s edit
loop or [rebranding.md](rebranding.md)'s rules - before considering an edit
done.

## Prerequisite: the tool must be installed

`validate_tokens` ships in the `utopia_design_tools` package, which is a
separate installable prerequisite from `utopia_ui` (the usage gate). Before
running it, confirm it resolves; if `dart run utopia_design_tools:validate_tokens`
fails with a package-resolution error, install it first as a dev dependency:

```bash
flutter pub add --dev utopia_design_tools
```

Until it is published to pub.dev this is a git dependency on the tools repo.
Do not assume the command is available - install-then-run.

## The validate_tokens contract

```
dart run utopia_design_tools:validate_tokens [<file>] [--json] [--schema <path>] [--fix]
```

- Default `<file>`: `design/tokens.json` if present, else
  `tokens/utopia.tokens.json`, else exit `2` with a bootstrap message giving
  the exact copy command (resolved `utopia_ui` pub-cache path - see
  [getting-started.md](getting-started.md) step 1-2 for how that path is
  resolved).
- Exit codes: `0` ok, `1` validation failure, `2` usage-or-IO error.
- Findings print on stdout, one per line: `ERROR <path>: <msg>` or
  `WARN <path>: <msg>`, with a summary line last: `N error(s), M warning(s)`.
- `--json` output shape:
  ```json
  {"status": "ok" | "fail", "errors": [{"path": "...", "message": "..."}],
   "warnings": [{"path": "...", "message": "..."}]}
  ```
- `--fix` is currently a STUB: it prints a not-implemented notice and behaves
  as a plain validate. Do not rely on it to auto-repair a document; fix
  findings by hand per the gates below.
- Install: see "Prerequisite" above.

`export_tokens` (the reverse direction - `UtopiaThemeData` -> token document)
is **maintainer-only**: it needs a checkout of the `utopia_ui` repo itself.
Never tell a consumer project to run it; consumers only ever run
`validate_tokens` (and, via `utopia-design-sync`, `generate_theme` /
`generate_twin`).

## The five validation gates (SPEC.md section 2.7, in order)

1. **Schema validity** - the document validates against
   `protocol/schemas/tokens.schema.json` (structure, types, units, the fixed
   naming table). *Fix:* correct the offending shape; re-run.
2. **Naming conformance** - every group/token name matches the canonical
   tree in [token-profile.md](token-profile.md) exactly; the schema encodes
   this, the validator reports the offending path. *Fix:* rename to a
   tree-legal path, or remove the token if it doesn't belong (see
   [token-profile.md](token-profile.md) "When to add a new entry").
3. **Alias resolvability** - every `{...}` reference resolves to an existing
   token of the expected type, with no circular chains. *Fix:* point the
   alias at a real path, or replace it with a literal value.
4. **Value coherence** - every `derivation`-carrying token matches
   `x * multiple` (SPEC.md 2.5), and every color's `hex` matches its
   `components` rounded to 8-bit channels. The error message states the
   expected value. *Fix:* re-derive the value (see
   [rebranding.md](rebranding.md) rule 2) or fix the `hex`/`components`
   mismatch (rule 1).
5. **Extension round-trip** - on any rewrite, unrecognized `$extensions`
   data is preserved byte-for-byte; the validator additionally warns on
   unknown keys inside the `io.utopiasoft.design` namespace. *Fix:* restore
   the dropped data (see [rebranding.md](rebranding.md) rule 5).

Violations of gates 1-4 are errors (exit `1`). Gate 5 issues are warnings
unless a rewrite would actually drop data, in which case it's an error too.

Two profile-specific checks ride along inside gates 1-4 rather than standing
as separate numbered gates: the typography **`colorToken` binding** (every
`textStyle.<role>` must have its `textStyle-colors.<role>` sibling, and the
binding must reference it - part naming conformance, part alias
resolvability) and the **8-bit `hex`/`components` cross-check** noted under
gate 4.

## profileVersion compatibility

Separate from the five gates above, `validate_tokens` also checks
`$extensions["io.utopiasoft.design"].profileVersion` at the document root
against its own protocol version (VERSIONING.md):

| Declared version vs validator | Result |
|---|---|
| same major | ok |
| newer minor than validator | warn |
| different major | **fail** (error) |
| missing `profileVersion` | warn (not an error) |

Keep `profileVersion` in sync with the protocol version the document
actually targets - see `SKILL.md` "Non-Negotiable Rules."

## Hook vs CLI - don't confuse the two

This plugin's PostToolUse hook (`quality_check.sh`) is a tripwire on
`design/*.tokens.json` edits, not the gate. It always runs a **structural
JSON sanity check** (`jq empty` plus "is the top level an object"), and when
the project actually resolves `utopia_design_tools` (pubspec or lockfile
entry plus a fetched `.dart_tool/package_config.json`) it also runs
`validate_tokens` on the edited file and surfaces the first findings (capped
at 8; needs `dart` on PATH; skipped when the structural check already flagged
the file; set `UTOPIA_DESIGN_VALIDATOR=off` to keep the hook
structural-only). It is
still not a substitute for running the CLI: the hook can be muted, truncates
findings, skips the validator when the tool is not fetched, and stays silent
on environment problems. Treat the hook as a tripwire and `validate_tokens`
as the actual gate. Always run the CLI yourself after an edit - do not rely
on hook silence as a validation pass.

## See also

- [token-profile.md](token-profile.md) - the tree gate 1-2 check against
- [rebranding.md](rebranding.md) - the edit rules gates 3-5 exist to enforce
