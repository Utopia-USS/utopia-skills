---
name: utopia-hooks
description: >
  Flutter state management with utopia_hooks. Applies when writing Flutter screens,
  adding shared app state, handling async operations, building paginated / infinite-scroll
  lists, injecting services, or migrating away from StatefulWidget. Covers the
  Screen/State/View pattern, hook catalog, global state registration, useSubmitState,
  useAutoComputedState, usePaginatedComputedState + PaginatedComputedStateWrapper,
  and dependency injection.
license: MIT
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_hooks, state-management, hooks, pagination, infinite-scroll
---

# utopia_hooks — Flutter State Management

## Overview

Holistic state management for Flutter using hooks. Every screen follows the
**Screen → State → View** tripartite pattern. Shared app state lives in
**StateClass + hook + `_providers`**. All logic belongs in hooks — never in widgets.

## Skill Format

Each reference file follows a hybrid format for fast lookup and deep understanding:

- **Quick Pattern**: ❌ Incorrect / ✅ Correct Dart code for immediate pattern matching
- **Deep Dive**: Full context — When to Use, Prerequisites, Step-by-Step, Common Pitfalls
- **Impact ratings**: CRITICAL (always apply), HIGH (significant correctness/quality gain), MEDIUM (worthwhile improvement)

## When to Apply

Reference these guidelines when:

- Building a new Flutter screen or adding a feature to an existing one
- Adding shared app-wide state (auth, settings, data caches, …)
- Handling async operations, form submissions, or loading states
- Building paginated / infinite-scroll lists, feeds, paginated search, or chat history
- Injecting a service into a screen or registering a new dependency
- Reviewing Flutter code — looking for logic in View, widgets in State, or raw `setState` patterns
- Migrating from `StatefulWidget`, BLoC, Riverpod, or Provider

## Priority-Ordered Guidelines

| Priority | Category                                | Impact   | Reference |
|----------|-----------------------------------------|----------|-----------|
| 1        | Screen architecture (Screen/State/View) | CRITICAL | [screen-state-view.md][screen-state-view] |
| 2        | Hook catalog & correct usage          | CRITICAL | [hooks-reference.md][hooks-reference] |
| 3        | Async patterns (download / upload)    | HIGH     | [async-patterns.md][async-patterns] |
| 4        | Paginated lists & infinite scroll     | HIGH     | [paginated.md][paginated] |
| 5        | Flutter code conventions              | HIGH     | [flutter-conventions.md][flutter-conventions] |
| 6        | Global shared state                   | HIGH     | [global-state.md][global-state] |
| 7        | Dependency injection & services       | MEDIUM   | [di-services.md][di-services] |
| 8        | Composable & widget-level hooks       | MEDIUM   | [composable-hooks.md][composable-hooks] |
| 9        | Testing hooks in isolation            | MEDIUM   | [testing.md][testing] |

## Quick Reference

Each pattern is a one-paragraph pointer — follow the link for the full contract. Do not extrapolate from the summary.

### Screen architecture → [screen-state-view.md][screen-state-view]

Every screen = **3 files**: `feature_screen.dart` (`HookWidget`, pure wiring — builds nav callbacks from `BuildContext`, calls exactly one `useXScreenState(...)`), `state/feature_screen_state.dart` (immutable State class + hook with all logic), `view/feature_screen_view.dart` (`StatelessWidget`, View receives only `state`).

### Global state registration → [global-state.md][global-state]

State class (often extends `HasInitialized`) + `useXState()` hook + entry in `_providers` map at app root. Consume with `useProvided<XState>()` inside any state hook. `ValueProvider` for static/already-computed values.

### Async — download / upload / stream → [async-patterns.md][async-patterns]

- **Download** (read, one-shot) → `useAutoComputedState` — auto-fetches, re-runs on `keys` change, `shouldCompute` gates prerequisites
- **Upload** (write) → `useSubmitState` — user-triggered; blocks duplicates; let errors crash by default; `toButtonState()` for UI
- **Stream** (reactive) → `useMemoizedStream` — subscribes continuously, re-subscribes on `keys` change

### Paginated lists → [paginated.md][paginated]

Any cursor-based list — feed, search results, chat history — uses `usePaginatedComputedState` + `PaginatedComputedStateWrapper` (scroll listener + pull-to-refresh). Never hand-roll `useState<List<T>>` + `hasMore` + `cursor`. Cursor is opaque (`int` for offset/page, `String?` for token). Optimistic mutations go in a local override layer, not into `items`.

## References

Full documentation with code examples in [references/][references]:

| File | Impact | Description |
|------|--------|-------------|
| [screen-state-view.md][screen-state-view] | CRITICAL | 3-file screen pattern: Screen, State class + hook, View |
| [hooks-reference.md][hooks-reference] | CRITICAL | Full hook catalog: useState, useMemoized, useEffect, useProvided, useInjected, useIf, useMap, useComputedState |
| [global-state.md][global-state] | CRITICAL | App-wide state: StateClass, HasInitialized, MutableValue, _providers registration |
| [async-patterns.md][async-patterns] | HIGH | useSubmitState, useAutoComputedState, useMemoizedStream, loading guards |
| [paginated.md][paginated] | HIGH | `usePaginatedComputedState` + `PaginatedComputedStateWrapper`: cursor/page/token schemes, loadMore, refresh, debounce, dedup, optimistic overlay |
| [composable-hooks.md][composable-hooks] | HIGH | Widget-level hooks, composed hook state, screen hook decomposition, per-item state (three archetypes) |
| [complex-state-examples.md][complex-state-examples] | HIGH | Five anonymised reference shapes for complex state (pipeline / dashboard / parent-owned list / per-item widget-level / multi-step flow) — what good looks like |
| [multi-page-shell.md][multi-page-shell] | HIGH | Shell-with-N-pages composition: shell is Screen/State/View, each inner page is Screen/State/View. Spectrum of impls (enum/index, IndexedStack/PageView/TabBarView, local/global index) |
| [testing.md][testing] | HIGH | Unit testing hooks with SimpleHookContext and SimpleHookProviderContainer — no widget tree needed |
| [flutter-conventions.md][flutter-conventions] | HIGH | IList/IMap/ISet, `it` lambdas, strict analyzer, widget extraction, spacing, generated code, TextEditingController |
| [di-services.md][di-services] | MEDIUM | DI bridge hook, useInjected pattern, service types (Firebase/Api/Data) |

## Searching References

```bash
# Find patterns by hook name
grep -rl "useSubmitState" references/
grep -rl "useMemoizedStream" references/
grep -rl "usePaginatedComputedState" references/
grep -rl "HasInitialized" references/
grep -rl "MutableValue" references/
grep -rl "useInjected" references/
grep -rl "useProvided" references/
```

## Dart Tooling — Prefer Dart MCP

When analyzing, testing, formatting, or fixing Dart code, prefer Dart MCP tools over their bash equivalents. MCP returns structured results (typed diagnostics, test summaries) and picks up the active SDK — including fvm-pinned versions — automatically.

| Task                | Dart MCP (preferred) | Bash fallback                       |
|---------------------|----------------------|-------------------------------------|
| Static analysis     | `analyze_files`      | `dart analyze` / `flutter analyze`  |
| Run tests           | `run_tests`          | `dart test` / `flutter test`        |
| Format code         | `dart_format`        | `dart format`                       |
| Apply dart fixes    | `dart_fix`           | `dart fix --apply`                  |
| Pub operations      | `pub`                | `dart pub get` / `flutter pub add`  |

Use bash **only** when:

- CI pipeline or pre-commit hook (shell-only context — e.g. `dart format --output=none --set-exit-if-changed .`)
- No MCP equivalent: `build_runner`, `melos`, `flutter build`, `ffigen`, `docker build`
- Dart MCP not configured in the current session

### Setup (once)

If `claude mcp list` doesn't show `dart`, pick a scope:

```bash
# User scope — recommended for dev tools; works across all your repos
claude mcp add -s user dart -- fvm dart mcp-server

# Project scope — writes .mcp.json; shared with team via git
claude mcp add -s project dart -- fvm dart mcp-server

# Local scope — this project, your machine only
claude mcp add -s local dart -- fvm dart mcp-server
```

If the target repo doesn't use fvm, drop it: `claude mcp add -s user dart -- dart mcp-server`.

## Problem → Skill Mapping

| Problem                                                                     | Start With |
|-----------------------------------------------------------------------------|------------|
| Adding a new screen                                                         | [screen-state-view.md][screen-state-view] |
| Logic is leaking into the View                                              | [screen-state-view.md][screen-state-view] |
| Widget imports in a State class                                             | [screen-state-view.md][screen-state-view] |
| App-wide state (auth, config, data)                                         | [global-state.md][global-state] |
| Screen not reacting to state changes                                        | [global-state.md][global-state] → [hooks-reference.md][hooks-reference] |
| Form submission with loading/error                                          | [async-patterns.md][async-patterns] |
| Async data with loading spinner                                             | [async-patterns.md][async-patterns] |
| Paginated list, infinite scroll, cursor/page/token pagination               | [paginated.md][paginated] |
| Pull-to-refresh on a list                                                   | [paginated.md][paginated] (`PaginatedComputedStateWrapper`) |
| Paginated search with debouncing                                            | [paginated.md][paginated] (`keys` + `debounceDuration`) |
| Optimistic updates on a paginated list                                      | [paginated.md][paginated] (optimistic overlay) or [complex-state-examples.md][complex-state-examples] shape 3 |
| Stream that should drive UI                                                 | [hooks-reference.md][hooks-reference] (useMemoizedStream) |
| Derived value from other state                                              | [hooks-reference.md][hooks-reference] (useMemoized) |
| Widget with expand/collapse, animation, lazy load                           | [composable-hooks.md][composable-hooks] (widget-level hook) |
| Reusable widget used N times on one screen                                  | [composable-hooks.md][composable-hooks] (composed hook state) |
| Screen state polluted with per-tile logic                                   | [composable-hooks.md][composable-hooks] (widget-level hook) |
| Paging, specialized text field, reusable control                            | [composable-hooks.md][composable-hooks] (composed hook state) |
| TextEditingController / FocusNode handling                                  | [flutter-conventions.md][flutter-conventions] |
| Testing a screen state hook                                                 | [testing.md][testing] |
| Testing global state and state interactions                                 | [testing.md][testing] |
| Injecting a service into a screen                                           | [di-services.md][di-services] |
| Registering a new service or state                                          | [di-services.md][di-services] |
| Using `List` / `Map` / `Set` instead of immutable                           | [flutter-conventions.md][flutter-conventions] |
| Lambda style, naming, widget extraction                                     | [flutter-conventions.md][flutter-conventions] |
| Generated code out of date                                                  | [flutter-conventions.md][flutter-conventions] |
| Replacing StatefulWidget                                                    | [screen-state-view.md][screen-state-view] + [hooks-reference.md][hooks-reference] |
| State hook is too large (>300 lines, >10 useState)                          | [composable-hooks.md][composable-hooks] (screen hook decomposition, Pattern 3) |
| Per-item state (list tile with expand / async / drafts)                     | [composable-hooks.md][composable-hooks] (per-item state archetypes) |
| Complex multi-domain or multi-step screen state — what should it look like? | [complex-state-examples.md][complex-state-examples] |
| Screen with bottom nav / tabs / sub-pages the user switches between                | [multi-page-shell.md][multi-page-shell] |
| Inner tab/page is a monolithic HookWidget with inline logic                         | [multi-page-shell.md][multi-page-shell] |
| Bottom nav / tab index needs to survive deep links or cross-screen jumps            | [multi-page-shell.md][multi-page-shell] + [global-state.md][global-state] |

[references]: references/
[screen-state-view]: references/screen-state-view.md
[hooks-reference]: references/hooks-reference.md
[global-state]: references/global-state.md
[async-patterns]: references/async-patterns.md
[paginated]: references/paginated.md
[composable-hooks]: references/composable-hooks.md
[complex-state-examples]: references/complex-state-examples.md
[testing]: references/testing.md
[flutter-conventions]: references/flutter-conventions.md
[di-services]: references/di-services.md
[multi-page-shell]: references/multi-page-shell.md

## Non-Negotiable Rules

- **View never calls hooks** — no `useState`, `useProvided`, `useInjected` in `*_view.dart`. View is always `StatelessWidget`.
- **View constructor takes ONLY `state`** — no extra `onBack`, `onNavigate`, or other parameters. All callbacks are fields on the State class.
- **Screen = pure wiring** — Screen's `build()` reads `BuildContext` (for navigation/dialogs/args) and calls exactly one hook: `useXScreenState(...)`. Screen must NOT call `useInjected`, `useProvided`, `useEffect`, `useState`, or any other hook.
- **Navigation flows Screen → State → View as callbacks** — never `useProvided<NavigatorKey>` or `useInjected<AppRouter>`. State hook receives navigation as `void Function()` / `Future<T?> Function()` parameters.
- **State never imports widgets** — no Flutter widget imports in `*_screen_state.dart`
- **`useProvided` / `useInjected` only in screen state hooks** — not in Screen, not in View, not passed down as parameters
- **No mutable collections in State classes** — always `IList`/`IMap`/`ISet`, never `List`/`Map`/`Set`, including static data
- **No manual loading state** — never use `useState<bool>` + `try/catch/finally` for data loading. Always `useAutoComputedState`.
- **No hand-rolled pagination** — never use `useState<List<T>>` + `hasMore` + `cursor` for paginated lists. Always `usePaginatedComputedState` + `PaginatedComputedStateWrapper`. See [paginated.md][paginated].
- **Prefer `useMemoized` over `useEffect`** for derived state — effects cascade; memoized values don't
- **One State class per screen** — all screen data in one place, not scattered `useState` calls across the widget tree
- **Never wrap `TextEditingController` in `useMemoized` + `useListenable`** — always `useFieldState` in the state hook + `TextEditingControllerWrapper` in the View. See [flutter-conventions.md][flutter-conventions].
- **View files ≤ ~300 lines** — extract complex widgets to `widget/` folder, using widget-level hook pattern from [composable-hooks.md](references/composable-hooks.md) when they have own state

## Self-Audit Checklist

After generating a screen, verify:

1. Does the View constructor take anything beyond `state`? → Move it to the State class
2. Does the Screen call any hook other than `useXScreenState(...)` (e.g., `useInjected`, `useProvided`, `useEffect`)? → Move to state hook
3. Are there `useState<bool>(true)` / `useState<T?>(null)` for loading/error? → Use `useAutoComputedState`
4. Are there mutable `List<T>`, `Map<K,V>`, `Set<T>` in the State class? → Use `IList`/`IMap`/`ISet`
5. Are there more than 2 `useSubmitState()` in one hook? → Group mutually exclusive actions
6. Is any view file > 300 lines? → Extract widgets to `widget/` folder
7. Does the View extend `HookWidget`? → Must be `StatelessWidget`
8. Is any state hook > ~300 lines or > ~10 useState? → Decompose into sub-hooks (see [composable-hooks.md][composable-hooks] Pattern 3)
9. Any `useProvided<NavigatorKey>` / `useInjected<AppRouter>` / `useMemoized(TextEditingController.new)`? → All three are forbidden; see [screen-state-view.md][screen-state-view] and [flutter-conventions.md][flutter-conventions]
10. Paginated list built from `useState<List<T>>` + `hasMore` + `cursor` + manual `useEffect` load? → Use `usePaginatedComputedState` + `PaginatedComputedStateWrapper`. See [paginated.md][paginated]

## Attribution

Built on [utopia_hooks](https://pub.dev/packages/utopia_hooks) by UtopiaSoftware.
