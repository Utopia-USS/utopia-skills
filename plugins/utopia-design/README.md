<img src="docs/header.png" width="236" alt="Utopia Design"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-design

A Claude Code plugin that implements the Utopia Design Protocol for projects using utopia_ui: `design/tokens.json` (DTCG) as the single source of truth, a generated Flutter theme plus an HTML twin surface, imports from external design sources, and screens built from manifest components only.

## What's inside

Five skills:

- `utopia-design:tokens` - edit or rebrand a consumer app's `design/tokens.json`, the DTCG document everything else is generated from.
- `utopia-design:sync` - regenerate every generated surface after the tokens change. Validates first and refuses to regenerate when the token document fails validation.
- `utopia-design:import` - bring in an external design source: a Figma DTCG export, a foreign `tokens.css` or Tailwind `@theme` file, a Claude Design handoff bundle, or a `DESIGN.md`.
- `utopia-design:screen` - build or update a screen from a design input using only components from the component manifest (the merged manifest when the project registers custom ones).
- `utopia-design:component` - turn a reported component gap into a live manifest id: opt-in overlay YAML under `design/overlay/`, project and merged manifest regeneration, validation, then the namespaced id handed back to screen building.

Plus 15 reference files across the five skills, and two hooks: SessionStart project detection and a PostToolUse design gate. No commands and no agents.

## Installation

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-design@utopia-flutter-skills
```

### Requirements

- A project that resolves `utopia_ui`. This is the universal usage gate: every skill stops there and surfaces install guidance instead of acting.
- `utopia_design_tools` as a dev dependency, for the token validator and the generators:

  ```bash
  flutter pub add --dev utopia_design_tools
  ```

  Until it reaches pub.dev, `pub add` cannot find it: install it as a git dependency on `https://github.com/Utopia-USS/utopia-ui.git` (path `tool/utopia_design_tools`), with the required `dependency_overrides` entry for `utopia_ui`. The exact snippet lives in the `utopia-design:tokens` skill, `references/validation.md`.
- `jq`, for the PostToolUse hook. The hook no-ops without it.

## How it works

SessionStart scans the project's `pubspec.yaml` files (several levels deep, so melos monorepos are covered) for `utopia_ui`, declared directly or resolved transitively via the sibling `pubspec.lock`. On a hit it primes the session with the protocol and the five skills. With no hit it exits silently - zero noise outside the ecosystem.

PostToolUse on `Edit|Write|MultiEdit` does two things:

- Flags hardcoded theme values in the edit payload, not in the whole file: `Color(0x......)` literals, Material `Colors.<swatch>` references, and non-zero dimension literals in `EdgeInsets`, `BorderRadius.circular` and `SizedBox(width:/height:)`. Generated Dart (`*.g.dart`, `*.freezed.dart` and friends) is skipped.
- Sanity-checks `design/tokens.json` - parseable JSON, object at the top level - and escalates to the real validator when `dart` is on PATH and `utopia_design_tools` resolves:

  ```bash
  dart run utopia_design_tools:validate_tokens design/tokens.json
  ```

  Its `ERROR` and `WARN` lines become hook violations.

Two env vars control the gate: `UTOPIA_DESIGN_MODE` is `warn` (default), `block` or `silent`; `UTOPIA_DESIGN_VALIDATOR=off` disables only the `dart` validator call and leaves the rest of the gate running.

## Development

`tests/smoke/run_hook_smoke.sh` is a self-contained smoke suite for both hook scripts. It exercises them against the bundled fixtures with a fake `dart` PATH shim, so no real toolchain or `utopia_design_tools` install is needed, and prints PASS/FAIL per case plus a final tally.

## Related plugins

| Plugin | What it adds |
|---|---|
| [utopia-hooks](../utopia-hooks/) | The foundation - all five skills defer Screen/State/View and hook idioms to it |
| [utopia-cms](../utopia-cms/) | Admin panels consuming the same generated theme |
| [utopia-ai-arch](../utopia-ai-arch/) | Project-level `.claude/` layer conventions, including hook-script shape |
| [utopia-pubdev](../utopia-pubdev/) | The pub.dev README and brand-chip standard |

Built by [UtopiaSoftware](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - skills are designed to be forked: copy one into your own Claude Code or Codex setup, tweak the rules, ship it.

## License

BSD 2-Clause - see [LICENSE](../../LICENSE).

[license_badge]: https://img.shields.io/badge/license-BSD--2--Clause-2E8B57.svg
[license_link]: ../../LICENSE
