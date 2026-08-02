<img src="docs/header.png" width="302" alt="Utopia Migrate BLoC"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-hooks-migrate-bloc

A Claude Code plugin that migrates Flutter BLoC/Cubit codebases to utopia_hooks: two-phase (global states first, then screens), one commit per migrated unit, driven by an orchestrator command and five sub-agents.

## What's inside

- Skill `migrate-bloc-to-utopia-hooks`, plus 8 references covering state translation, widget translation, complex Cubit patterns, global-state migration, the step sequence, screen migration flow, pubspec migration, and a post-migration refactor checklist.
- Command `/utopia-hooks-migrate-bloc:migrate` - the orchestrator.
- Five agents:
  - `migrate-inventory` - read-only scanner. Builds the screen inventory, the global-state dependency graph and the next-wave plan, and regenerates `MIGRATION.md`.
  - `migrate-foundation` - one-time setup: pubspec dependency, `_providers.dart`, a `useInjected` bridge to existing DI, and `HookProviderContainerWidget` at the app root alongside the existing `MultiBlocProvider`.
  - `migrate-global-state` - migrates one Cubit/Bloc to a parallel hook-based global state with no screen changes, and marks the original `@Deprecated`. One diff, one commit. When domain logic lives in the Cubit itself, it extracts a service first (behavior-preserving commit) instead of duplicating the logic into the hook. Registration in `_providers.dart` is deferred to the first migrated consumer screen, so the hook never runs side by side with the live Cubit.
  - `migrate-screen` - migrates one screen plus any global states it still needs. Produces the diff, does not commit. Oversized screens get a staged multi-commit plan instead of a one-shot rewrite.
  - `migrate-review` - independent review against the exit gate, with fresh context that never sees the migration agent's reasoning.
- A PostToolUse migration gate (`scripts/screen_gate.sh`).

## Installation

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-hooks-migrate-bloc@utopia-flutter-skills
```

### Requirements

- The `utopia-hooks` plugin. It carries the target architecture; the skill stops and asks you to install it if it is missing.
- The Dart MCP server (`dart mcp-server`, or `fvm dart mcp-server` in fvm projects). The orchestrator stops and asks you to set it up rather than silently falling back to bash.
- `jq`, for the PostToolUse gate. Without it the gate exits silently.

## Usage

```
/utopia-hooks-migrate-bloc:migrate --budget 5
```

Flags: `[--budget N] [--screens a,b,c] [--status] [--finalize]`, plus `--allow-bash-fallback` to proceed without the Dart MCP server (expect brittler reviews). `--finalize` runs the endgame cleanup (delete deprecated Cubits, drop BLoC packages, repo-wide exit-gate sweep) once every screen is migrated. If the project has a test suite, the orchestrator captures a `flutter test` baseline and enforces "zero new failures" per batch.

The orchestrator does not migrate code itself; it coordinates the sub-agents and commits their work per screen. Every run runs `migrate-inventory` before any migration work; it regenerates `MIGRATION.md` at the repo root while preserving the Skipped section you edited by hand.

### The migration gate

The gate is active only while the pubspec declares BOTH `utopia_hooks` and a bloc package (`flutter_bloc`, `bloc`, `hydrated_bloc`, `bloc_concurrency`) - that combination is the mid-migration signal, so the hook stays quiet before and after the migration.

On every Dart edit it classifies the file as state, screen or view, then flags the leftovers for that role: bloc imports, BLoC widgets, `context.read/watch/select`, `emit(`, `extends Equatable`, `extends StatefulWidget` in a screen, hook calls from a view, and size budgets per file kind.

`UTOPIA_MIGRATE_MODE=warn` (the default) surfaces the violations to the model as additional context on every edit; `block` rejects the edit until fixed. Both use the PostToolUse JSON contract, so the feedback always reaches the model - not just the terminal.

## Related plugins

| Plugin | What it adds |
|---|---|
| [utopia-hooks](../utopia-hooks/) | Required companion - the target architecture this migration writes toward |
| [utopia-dart-lsp](../utopia-dart-lsp/) | Live analyzer diagnostics on every `.dart` edit while migrating |
| [utopia-cms](../utopia-cms/) | Admin panels on the same utopia_hooks foundation |
| [utopia-ai-arch](../utopia-ai-arch/) | The project-level `.claude/` layer around all of this |

Built by [UtopiaSoftware](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - skills are designed to be forked: copy one into your own Claude Code or Codex setup, tweak the rules, ship it.

## License

BSD 2-Clause - see [LICENSE](../../LICENSE).

[license_badge]: https://img.shields.io/badge/license-BSD--2--Clause-2E8B57.svg
[license_link]: ../../LICENSE
