---
name: utopia-design-sync
description: >
  Regenerate every generated surface of the Utopia Design Protocol from
  design/tokens.json after it changes: the Flutter theme code (generate_theme)
  and the HTML twin (generate_twin: tokens.css, tokens.tailwind.css, DESIGN.md
  front matter). Runs validate_tokens first and never regenerates from a failing
  token document; runs a packageVersion drift check (validate_manifest);
  optionally runs validate_twin after. Applies when: design/tokens.json was just
  edited or imported and the surfaces need to catch up. Without utopia_ui
  resolved it stops at its usage gate and surfaces install guidance. Does NOT
  cover editing or rebranding design/tokens.json itself
  (-> utopia-design-tokens), importing an external design source
  (-> utopia-design-import), building screens (-> utopia-design-screen), or
  hand-editing the generated theme Dart or twin CSS (regenerated, never
  hand-patched). Layered on the upstream utopia-hooks plugin - silent on
  Screen/State/View, hooks, and Dart conventions.
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_ui, design-tokens, sync, regenerate, theme-codegen, html-twin, design-protocol
---

# Skill: Utopia Design Sync

## Overview

Sync is the fan-out step of the Utopia Design Protocol: one edited
`design/tokens.json`, regenerate every surface from it. Nothing is ever
generated from a token document that fails validation - a broken source
must never reach a rendered surface. See the frontmatter `description`
above for the exact positive/negative boundary. This skill owns the
regenerate workflow and the drift/verify checks around it; it does not own
editing the token document (that's **utopia-design-tokens**) and it does
not own the generated output's content (that's whatever `generate_theme` /
`generate_twin` write - never hand-edited).

## Usage Gate (do this first, non-negotiable)

Before touching anything, confirm the project actually resolves `utopia_ui`:
`pubspec.yaml` declares `utopia_ui:` directly, or `pubspec.lock` resolves it
transitively. This mirrors the plugin's own `SessionStart` / `PostToolUse`
hook gate and the same check **utopia-design-tokens** and
**utopia-design-import** run - the protocol is meaningless without the
library present.

- **If it resolves:** continue below.
- **If it does NOT resolve:** stop. Surface this install guidance to the
  user (show the commands; do not add the dependency to their pubspec
  yourself) instead of regenerating anything:
  ```bash
  flutter pub add utopia_ui
  flutter pub get
  ```
  Only proceed once the project resolves the package.

Second, separate prerequisite: every command this skill runs (`validate_tokens`,
`validate_manifest`, `generate_theme`, `generate_twin`, `validate_twin`) ships
in the `utopia_design_tools` package, not `utopia_ui` itself. Confirm it
resolves the same inspect-first way: `pubspec.yaml` (under `dev_dependencies`)
or `pubspec.lock` lists `utopia_design_tools`. If it does not - or if
`dart run utopia_design_tools:<command>` fails with a package-resolution
error anyway - install it first:

```bash
flutter pub add --dev utopia_design_tools
```

This is the identical prerequisite **utopia-design-tokens**'s
[validation.md](../utopia-design-tokens/references/validation.md) documents
for `validate_tokens`, including the pre-publish git-dependency fallback
when `pub add` cannot find the package - do not assume the tools are
available, install then run.

## The Regenerate Workflow (the spine)

Once both gates above pass, run this sequence in order. Full command
contracts, what each reads/writes, and exit-code handling live in
[regeneration.md][regeneration]; the why-first reasoning behind steps 1-2
and 5 lives in [drift-and-verify.md][drift-and-verify].

**Where `SPEC.md` / `VERSIONING.md` live** (cited by the steps below): the
protocol documents ship inside the `utopia_ui` package under `protocol/`
(hence the `protocol/SPEC.md` citations), alongside the `protocol/schemas/`
the validators check against. Resolve the installed copy the same way this
plugin resolves every packaged artifact: read
`.dart_tool/package_config.json` for `utopia_ui`'s `rootUri` (the snippet
lives in **utopia-design-tokens**'s `getting-started.md`), then open
`<root>/protocol/`. If it does not resolve, treat every `SPEC.md` /
`VERSIONING.md` citation in this skill as background rationale and continue -
never block on the missing file.

1. **`validate_tokens` FIRST.** If it fails (exit 1 or 2), **STOP** - refuse
   to regenerate from a broken source. Never propagate an invalid token
   document into the theme or the twin. This is the same gate
   **utopia-design-tokens** uses; do not re-run its full contract here, see
   [regeneration.md][regeneration] for the cross-link.
2. **Drift check: `validate_manifest`.** Confirms the manifest's
   `packageVersion` matches the resolved `utopia_ui` (SPEC.md 3.7). A
   mismatch means the generated artifacts would not match the resolved
   library - treat it as a real error, not a warning to shrug off. See
   [drift-and-verify.md][drift-and-verify].
3. **`generate_theme`.** Produces the app's Dart theme code
   (`buildUtopiaTheme()`) from `design/tokens.json`. On the FIRST sync, also
   confirm the app wires it - `UtopiaTheme(data: buildUtopiaTheme(),
   child: ...)` - or the rebrand silently changes nothing; see
   [regeneration.md][regeneration].
4. **`generate_twin` - conditional by presence.** Produces `twin/tokens.css`,
   `twin/tokens.tailwind.css`, and the `DESIGN.md` front matter from the same
   `design/tokens.json`. Run it when the project already HAS a `twin/`
   directory (it materialized the design surface) or when the user explicitly
   asks; creating the twin for the FIRST time is an explicit choice, never a
   rebrand side effect. "Regeneration fans out to every surface" (SPEC.md
   6.1) means every surface the consumer has - an app-only project has no
   twin surface, so writing one unasked is friction, not fan-out. Steps 3
   and 4 are independent - both read only `design/tokens.json`, so either
   order works.
5. **`validate_twin` (optional).** Literals linter + `data-utopia-id`
   coverage check against the manifest. Not required to consider the sync
   done, but recommended whenever the twin output is going to be viewed or
   shipped. On a generated-only project twin the coverage gate auto-skips
   (no `components.html` = the signal) while the literals + freshness gates
   still run - see [regeneration.md][regeneration] for the consumer-scope
   note.
6. **Done.** Do not hand-edit any generated output (the theme Dart file,
   `tokens.css`, `tokens.tailwind.css`, or the `DESIGN.md` front matter
   block). If something looks wrong, fix `design/tokens.json` and re-run
   this workflow instead.

## When to Apply

- `design/tokens.json` was just edited (via **utopia-design-tokens**) or
  imported (via **utopia-design-import**) and the Flutter theme and/or the
  HTML twin need to catch up
- Confirming there is no drift between the resolved `utopia_ui` and the
  manifest before trusting a regenerated surface
- Periodically re-running `validate_twin` to catch literal-value drift or
  missing `data-utopia-id` coverage in hand-authored twin markup
- Typical phrasings: "regenerate theme", "sync tokens", "generate theme",
  "regenerate twin", "rebuild design surfaces", "after editing tokens"

## Out of Scope

- Editing or rebranding `design/tokens.json` itself -> use
  **utopia-design-tokens**
- Importing an external design source (Figma, foreign `tokens.css` /
  Tailwind `@theme`, a handoff bundle, a `DESIGN.md`) -> use
  **utopia-design-import**
- Building or updating a screen from a design -> use **utopia-design-screen**
- Hand-editing the generated theme Dart file, `twin/tokens.css`,
  `twin/tokens.tailwind.css`, or the `DESIGN.md` front matter block - all
  four are regenerated outputs; re-run this skill's workflow instead

## Priority-Ordered Guidelines

| Priority | Reference | Impact | Description |
|----------|-----------|--------|-------------|
| 1 | [regeneration.md][regeneration] | CRITICAL | The validated fan-out: exact commands (where contracted), what each reads/writes, exit-code handling, the "no runtime sync, explicit step" principle |
| 2 | [drift-and-verify.md][drift-and-verify] | HIGH | Why-first: packageVersion drift, profileVersion compatibility, the literals linter + `data-utopia-id` coverage, and the refuse-on-failure rationale |

## Non-Negotiable Rules

- **Verify `utopia_ui` resolves, and that `utopia_design_tools` resolves,
  before running anything** (the two gates above).
- **`validate_tokens` runs BEFORE any regeneration, every time.** A failure
  means STOP - never regenerate the theme or the twin from a token document
  that fails validation.
- **Regeneration is an explicit, validated step - never a runtime sync.**
  There is no watching, no network call, no background process (SPEC.md
  6.1). A surface-side edit (a tweak in the twin's CSS, an external design
  tool change) only becomes durable by landing in `design/tokens.json` and
  re-running this workflow.
- **Never hand-edit generated output.** The theme Dart file, `tokens.css`,
  `tokens.tailwind.css`, and the `DESIGN.md` front matter block are all
  regenerated by `generate_theme` / `generate_twin`; a hand-edit is silently
  destroyed by the next regeneration and, in the meantime, lies about what
  `design/tokens.json` actually says.
- **A `packageVersion` mismatch (`validate_manifest`) is a real error.** It
  means the resolved `utopia_ui` and the manifest describing it disagree;
  do not regenerate against a moving target (SPEC.md 3.7).
- **Respect the round-trip guarantee.** Exporting `defaultTheme` and then
  running `generate_theme` on that export MUST reproduce `defaultTheme` up to
  8-bit color quantization - colors compare by their ARGB32 value
  (SPEC.md 5). Never "improve" or hand-tune generated theme code to work
  around an apparent mismatch - report it as a bug in the generator instead.

## Self-Audit Checklist

After running this skill's workflow, verify:

1. `validate_tokens` was run and passed (or every finding was fixed and it
   was re-run) before any generate step.
2. The theme was regenerated, and the twin was too IF the project has a
   `twin/` directory (or the user asked for one) - a present surface never
   stays stale, and an absent one is never created as a side effect.
3. No generated file (theme Dart, `tokens.css`, `tokens.tailwind.css`,
   `DESIGN.md` front matter) was hand-edited.
4. The `validate_manifest` drift check was run and passed (`packageVersion`
   matches the resolved `utopia_ui`).
5. `profileVersion` (on the token document) and `packageVersion` (on the
   manifest) are both coherent with what was actually resolved - see
   [drift-and-verify.md][drift-and-verify].
6. `validate_twin` was run whenever the twin output is going to be viewed or
   shipped (it stays optional for a purely app-side token change).

## See Also

- **utopia-design-tokens** - the edit-and-validate loop that precedes sync;
  its [validation.md](../utopia-design-tokens/references/validation.md) is
  the `validate_tokens` contract this skill refuses to skip.
- **utopia-design-import** - produces the token edits this skill's workflow
  propagates, when the change originates outside `design/tokens.json`.
- **utopia-design-screen** - builds screens from manifest components; not
  this skill's concern.
- **utopia-hooks** - owns app/state concerns (Screen/State/View, hooks, DI);
  this skill stays silent on all of it.

## Attribution

Built on [utopia_ui](https://pub.dev/packages/utopia_ui) and the Utopia
Design Protocol, by UtopiaSoftware.

[regeneration]: references/regeneration.md
[drift-and-verify]: references/drift-and-verify.md
