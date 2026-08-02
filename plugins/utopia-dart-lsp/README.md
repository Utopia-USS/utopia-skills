<img src="docs/header.png" width="249" alt="Utopia Dart LSP"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-dart-lsp

A Claude Code plugin that runs the Dart language server for live code intelligence - analyzer diagnostics after every `.dart` edit, plus hover, go-to-definition, find-references, document/workspace symbols, and call hierarchy.

## What's inside

- **Diagnostics** - analyzer errors/warnings are injected into context automatically after every `.dart` edit (no `dart analyze` run needed).
- **Navigation and symbols** - hover, go-to-definition, find-references, document and workspace symbol search, incoming/outgoing call hierarchy.
- Wired through the `lspServers` key in `.claude-plugin/plugin.json` - the plugin's only runtime surface. No skills, hooks, commands, or agents.

## Installation

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-dart-lsp@utopia-flutter-skills
```

Then reload (`/reload-plugins`) or restart. The server spawns lazily on the first `.dart` file Claude touches; `/reload-plugins` then reports `1 plugin LSP server`.

### Requirements

A Dart SDK reachable by one of the three strategies described below. Nothing else to configure.

## SDK selection (fvm-aware)

`scripts/dart_lsp.sh` picks the Dart SDK per project, in order. No per-project configuration:

1. **Project-pinned fvm SDK** - `<project>/.fvm/flutter_sdk/bin/dart`, when that path is executable (typically a project where `fvm use <version>` has run).
2. **`fvm dart`** - when `fvm` is installed and the project is pinned (`.fvmrc` or legacy `.fvm/fvm_config.json`) but the SDK symlink isn't materialized yet.
3. **`dart` on PATH** - the fallback whenever neither fvm strategy matched; the script tests only that `dart` is on PATH.

So the same plugin works whether or not a project uses fvm.

## Companion

Complements the official `dart mcp-server` (run tests, hot reload, pub): LSP provides passive code intelligence, the MCP server provides invokable tools.

## Related plugins

| Plugin | What it adds |
|---|---|
| [utopia-hooks](../utopia-hooks/) | The Flutter foundation these diagnostics serve |
| [utopia-hooks-migrate-bloc](../utopia-hooks-migrate-bloc/) | Prefers fvm-aware Dart diagnostics for its migration exit gate |
| [utopia-design](../utopia-design/) | Its hook shells out to `dart` too, same SDK-resolution problem |

Built by [UtopiaSoftware](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - skills are designed to be forked: copy one into your own Claude Code or Codex setup, tweak the rules, ship it.

## License

BSD 2-Clause - see [LICENSE](../../LICENSE).

[license_badge]: https://img.shields.io/badge/license-BSD--2--Clause-2E8B57.svg
[license_link]: ../../LICENSE
