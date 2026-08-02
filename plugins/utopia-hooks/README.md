<img src="docs/header.png" width="230" alt="Utopia Hooks"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-hooks

A Claude Code and Codex plugin that teaches AI agents Flutter state management with [utopia_hooks](https://pub.dev/packages/utopia_hooks) - the Screen/State/View pattern, hook catalog, global state, async/pagination patterns, and hook-state testing - and enforces the conventions on every Dart edit.

## What's inside

- The `utopia-hooks` skill, plus 15 reference files: Screen/State/View, the hook catalog, global state registration, async patterns, pagination and infinite scroll, app bootstrap, global error handling, navigation conventions, multi-page shells, complex state examples, composable hooks, Flutter conventions, hook-state testing, DI and services, and utopia_cli integration.
- A SessionStart hook for project detection.
- A PostToolUse hook that gates every Dart edit against the conventions.

No commands and no agents.

## Installation

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-hooks@utopia-flutter-skills
```

```bash
# Codex
codex plugin marketplace add Utopia-USS/utopia-flutter-skills --ref main
codex plugin install utopia-hooks@utopia-flutter-skills
```

### Requirements

The PostToolUse gate shells out to the `utopia` CLI, so it has to be on PATH:

```bash
dart pub global activate utopia_cli   # ensure $HOME/.pub-cache/bin is on PATH
```

Without it the gate cannot run (the skill still works). Optional: expose the same rule engine as MCP tools with `claude mcp add -s user utopia -- utopia mcp`.

## How it works

**SessionStart** scans the repo's `pubspec.yaml` files for `utopia_hooks` or `utopia_arch`. No match means a silent `exit 0`, so there is zero noise outside the ecosystem. On a match it primes the session to load the skill before writing screens, state hooks, global state, async and pagination code, DI, or hook tests.

**PostToolUse** fires on `Edit|Write|MultiEdit` and is a thin wrapper around one command:

```bash
utopia hooks analyze --hook-json
```

The rule engine lives in `utopia_cli`, not in the hook script, and the same engine is exposed as the MCP tools `analyze_hooks_files` and `analyze_hooks_changed`.

**The skill defers deterministic surfaces to the CLI** instead of re-deriving them by reading source:

```bash
utopia describe -o -              # project structure as JSON (--routes-only for routes)
utopia add screen profile --json  # scaffold a Screen/State/View triple
utopia doctor                     # setup checks
```

The conventions are enforceable, not advisory. The one most edits trip over: the View never calls hooks - no `useState`, `useProvided`, or `useInjected` in `*_view.dart`, and the View is always a `StatelessWidget`.

## Related plugins

| Plugin | What it adds |
|---|---|
| [utopia-hooks-migrate-bloc](../utopia-hooks-migrate-bloc/) | Migrates BLoC/Cubit codebases to utopia_hooks, one commit per unit |
| [utopia-cms](../utopia-cms/) | Admin panels and CMS screens on the same foundation |
| [utopia-ai-arch](../utopia-ai-arch/) | The project-level `.claude/` layer that sits on top of this foundation |
| [utopia-dart-lsp](../utopia-dart-lsp/) | Live analyzer diagnostics on every `.dart` edit |

Built by [UtopiaSoftware](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - skills are designed to be forked: copy one into your own Claude Code or Codex setup, tweak the rules, ship it.

## License

BSD 2-Clause - see [LICENSE](../../LICENSE).

[license_badge]: https://img.shields.io/badge/license-BSD--2--Clause-2E8B57.svg
[license_link]: ../../LICENSE
