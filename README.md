# utopia-hooks-skills

Agent skills for **utopia_hooks** — the holistic Flutter state management architecture by [UtopiaSoftware](https://utopiasoft.io).


## What this is

A public, installable skill repository that teaches AI agents how to write Flutter apps using `utopia_hooks` as the primary architecture. Works across Claude Code, Cursor, Codex, Windsurf, and all `SKILL.md`-compatible tools.

## Skills

### `utopia-hooks`

Holistic guide: how to write Flutter with hooks.

| Reference | Impact   | Topic |
|-----------|----------|-------|
| [page-state-view.md](skills/utopia-hooks/references/page-state-view.md) | CRITICAL | Page / State hook / View screen architecture |
| [hooks-reference.md](skills/utopia-hooks/references/hooks-reference.md) | CRITICAL | Full hook API organized by use case |
| [global-state.md](skills/utopia-hooks/references/global-state.md) | CRITICAL     | Global state, HasInitialized, MutableValue, providers |
| [async-patterns.md](skills/utopia-hooks/references/async-patterns.md) | HIGH   | Download (useAutoComputedState) / Upload (useSubmitState) / Streams |
| [flutter-conventions.md](skills/utopia-hooks/references/flutter-conventions.md) | HIGH     | IList/IMap/ISet, lambdas, strict analyzer, widget extraction |
| [composable-hooks.md](skills/utopia-hooks/references/composable-hooks.md) | MEDIUM   | Widget-level hooks, lifted state, useIf, useMap |
| [testing.md](skills/utopia-hooks/references/testing.md) | MEDIUM   | Unit-testing hooks with SimpleHookContext |
| [di-services.md](skills/utopia-hooks/references/di-services.md) | MEDIUM   | Service registration and injection with useInjected |

## Installation

### Claude Code

```bash
claude mcp add-skill https://github.com/ArcaneArts/utopia-hooks-skills
```

### Cursor

Copy `skills/utopia-hooks/` into your project's `.cursor/skills/` directory.

## Packages

- [utopia_hooks](https://pub.dev/packages/utopia_hooks) — hooks framework
- [utopia_arch](https://pub.dev/packages/utopia_arch) — architecture layer (DI, preferences, error handling)
- [utopia_hooks_riverpod](https://pub.dev/packages/utopia_hooks_riverpod) — Riverpod bridge
- [fast_immutable_collections](https://pub.dev/packages/fast_immutable_collections) — IList, IMap, ISet

## License

MIT
