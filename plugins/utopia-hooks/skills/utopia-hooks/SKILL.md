---
name: utopia-hooks
description: >
  Flutter state management with utopia_hooks. Applies when writing Flutter screens,
  adding shared app state, handling async operations, building paginated / infinite-scroll
  lists, composing tab / bottom-nav / multi-page shells, sequencing app startup and
  bootstrap, handling global and retryable errors, building form fields (useFieldState,
  TextEditingControllerWrapper), unit-testing hook states (SimpleHookContext), injecting
  services, or migrating away from StatefulWidget. Covers the Screen/State/View pattern,
  the hook catalog, global state registration, async / paginated / submit hooks,
  navigation conventions, and dependency injection. Does NOT cover BLoC/Cubit
  migration (use utopia-hooks-migrate-bloc) or admin/CMS table screens (use
  utopia-cms).
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_hooks, state-management, hooks, pagination, infinite-scroll, navigation, bootstrap, error-handling, testing, forms
---

# utopia_hooks - Flutter State Management

## Overview

Holistic state management for Flutter using hooks. Every screen follows the
**Screen → State → View** tripartite pattern. Shared app state lives in
**StateClass + hook + `_providers`**. All logic belongs in hooks - never in widgets.

`Crazy*` widgets in examples (`CrazyButton`, `CrazyTextField`, …) are stand-ins for your
app's design system - substitute your own components or Material equivalents.

## When to Apply

Reference these guidelines when:

- Building a new Flutter screen or adding a feature to an existing one
- Adding shared app-wide state (auth, settings, data caches, …)
- Handling async operations, form submissions, or loading states
- Building paginated / infinite-scroll lists, feeds, paginated search, or chat history
- Composing a tab / bottom-nav / multi-page shell screen
- Sequencing app startup (splash, SDK init, ordered providers) or wiring global error handling
- Declaring routes or navigating in reaction to state changes
- Injecting a service into a screen or registering a new dependency
- Unit-testing a hook state in isolation
- Reviewing Flutter code - looking for logic in View, widgets in State, or raw `setState` patterns
- Migrating from `StatefulWidget` (for BLoC/Cubit migration, use the dedicated `utopia-hooks-migrate-bloc` plugin)

## Priority-Ordered Guidelines

Full documentation with code examples in [references/][references].
Impact ratings: CRITICAL (always apply), HIGH (significant correctness/quality gain), MEDIUM (worthwhile improvement).

| Priority | File | Impact | Description |
|----------|------|--------|-------------|
| 1 | [screen-state-view.md][screen-state-view] | CRITICAL | 3-file screen pattern: Screen, State class + hook, View; lightweight tier; dialogs with results |
| 2 | [hooks-reference.md][hooks-reference] | CRITICAL | Full hook catalog: `useState`, `useMemoized`, `useEffect`, `useProvided`, `useInjected`, `useIf`, `useMap`, computed states, wrappers |
| 3 | [global-state.md][global-state] | CRITICAL | App-wide state: StateClass, `HasInitialized`, `MutableValue`, `_providers` registration, global-state idioms |
| 4 | [async-patterns.md][async-patterns] | HIGH | `useSubmitState`, `useAutoComputedState`, `useMemoizedStream`, `usePersistedState`, retryable errors, lifecycle effects, sticky values |
| 5 | [paginated.md][paginated] | HIGH | `usePaginatedComputedState` + `PaginatedComputedStateWrapper`: cursor/page/token schemes, loadMore, refresh, debounce, dedup, optimistic overlay |
| 6 | [app-bootstrap.md][app-bootstrap] | HIGH | Ordered `_providers`, `HasInitialized` chains, combined initialization state, splash gating, SDK init races, retryable bootstrap |
| 7 | [error-handling.md][error-handling] | HIGH | Where let-it-crash errors land: app-root catcher (zone + `FlutterError.onError`), error stream + root dialog, `Retryable` retry, typed errors to field errors |
| 8 | [navigation.md][navigation] | HIGH | Route declaration conventions, typed args, reactive navigation effects, status-driven redirects, screen-as-sheet/dialog with typed results, one-shot event fields |
| 9 | [multi-page-shell.md][multi-page-shell] | HIGH | Shell-with-N-pages composition: shell is Screen/State/View, each inner page is Screen/State/View; enum/index, IndexedStack/PageView/TabBarView, local/global index |
| 10 | [complex-state-examples.md][complex-state-examples] | HIGH | Five anonymised reference shapes for complex state (pipeline / dashboard / parent-owned list / per-item widget-level / multi-step flow) |
| 11 | [composable-hooks.md][composable-hooks] | HIGH | Widget-level hooks, composed hook state, screen hook decomposition, per-item state archetypes |
| 12 | [flutter-conventions.md][flutter-conventions] | HIGH | IList/IMap/ISet, `it` lambdas, strict analyzer, widget extraction, spacing, generated code, TextEditingController |
| 13 | [testing.md][testing] | HIGH | Unit testing hooks with SimpleHookContext and SimpleHookProviderContainer - no widget tree needed; mocking injected services |
| 14 | [di-services.md][di-services] | MEDIUM | utopia_injector, `useInjected`, DI bridge hooks, service types, get_it fallback |
| 15 | [utopia-cli.md][utopia-cli] | MEDIUM | utopia_cli agent surfaces: project inspection (`describe`), screen scaffolding (`add screen --json`), repo audit (`doctor`), `hooks analyze` variants, MCP server setup |

## Quick Reference - Top Patterns

A pointer-paragraph for the four most-common entry points. For everything else, jump
straight to the guidelines table above. Do not extrapolate from the summaries.

### Screen architecture → [screen-state-view.md][screen-state-view]

Every screen = **3 files**: `feature_screen.dart` (`HookWidget`, pure wiring - builds nav callbacks from `BuildContext`, calls exactly one `useXScreenState(...)`), `state/feature_screen_state.dart` (immutable State class + hook with all logic), `view/feature_screen_view.dart` (`StatelessWidget`, View receives only `state`).

### Global state registration → [global-state.md][global-state]

State class (often extends `HasInitialized`) + `useXState()` hook + entry in `_providers` map at app root. Consume with `useProvided<XState>()` inside any state hook. `ValueProvider` for static/already-computed values.

### Async - download / upload / stream → [async-patterns.md][async-patterns]

- **Download** (read, one-shot) → `useAutoComputedState` - auto-fetches, re-runs on `keys` change, `shouldCompute` gates prerequisites
- **Upload** (write) → `useSubmitState` - user-triggered; tracks in-flight runs but does NOT block duplicate calls (the three guards are in [async-patterns.md][async-patterns]); let errors crash by default
- **Stream** (reactive) → `useMemoizedStream` - subscribes continuously, re-subscribes on `keys` change
- **Persisted setting** (per-toggle get+set) → `usePersistedState` - one `MutableValue`-shaped object per setting: `.value` reads, `.value = x` writes optimistically then persists (`isSynchronized` flags an in-flight write). The shape for settings/preferences surfaces - never split them into a read snapshot plus setter wrappers

### Paginated lists → [paginated.md][paginated]

Any cursor-based list - feed, search results, chat history - uses `usePaginatedComputedState` + `PaginatedComputedStateWrapper` (scroll listener + pull-to-refresh). Never hand-roll `useState<List<T>>` + `hasMore` + `cursor`. Cursor is opaque (`int` for offset/page, `String?` for token). For confirmed optimistic edits/deletes, override the buffer with `updateValues(items, {cursor})` / `updateAt` / `deleteAt` (decrement the cursor on offset/page deletes to avoid skipping); reserve a render-time override layer for transient/uncommitted UI state.

## Searching References

All paths below are relative to the skill root (the directory containing this SKILL.md).
From elsewhere, use the absolute form, e.g.
`grep -rl "useSubmitState" /path/to/plugins/utopia-hooks/skills/utopia-hooks/references/`.

```bash
# Async / data-loading hooks
grep -rl "useAutoComputedState" references/
grep -rl "useComputedState" references/
grep -rl "useSubmitState" references/
grep -rl "usePersistedState" references/
grep -rl "useMemoizedStream" references/
grep -rl "usePaginatedComputedState\|PaginatedComputedStateWrapper" references/
grep -rl "useDebounced" references/

# Core / lifecycle hooks
grep -rl "useMemoized" references/
grep -rl "useEffect" references/
grep -rl "useMap" references/
grep -rl "useIf" references/
grep -rl "useKeyed" references/

# Form / input hooks
grep -rl "useFieldState" references/
grep -rl "useFocusNode" references/

# Global state + DI types
grep -rl "HasInitialized" references/
grep -rl "MutableValue" references/
grep -rl "useProvided" references/
grep -rl "useInjected" references/

# Bootstrap / errors / navigation
grep -rl "Retryable" references/
grep -rl "HasInitialized.all" references/
grep -rl "useCombinedInitializationState" references/
grep -rl "buildRoute" references/
```

## Validation - utopia_cli Quality Gate

The canonical utopia_hooks convention analyzer lives in `utopia_cli`, not in this skill's
shell scripts - Claude, Codex, CI, and pre-commit all run the same rules. The plugin's
PostToolUse hook validates every Dart edit via `utopia hooks analyze --hook-json`; for
manual / batch / changed-file / CI variants, repo-wide `utopia doctor` audits, project
inspection (`utopia describe`), scaffolding (`utopia add screen --json`), and the
`utopia mcp` server, see [utopia-cli.md][utopia-cli].

## Dart Tooling - Prefer Dart MCP

When analyzing, testing, formatting, or fixing Dart code, prefer Dart MCP tools over their
bash equivalents - they return structured results and pick up the active SDK (including
fvm-pinned versions) automatically.

| Task                | Dart MCP (preferred) | Bash fallback                       |
|---------------------|----------------------|-------------------------------------|
| Static analysis     | `analyze_files`      | `dart analyze` / `flutter analyze`  |
| Run tests           | `run_tests`          | `dart test` / `flutter test`        |
| Format code         | `dart_format`        | `dart format`                       |
| Apply dart fixes    | `dart_fix`           | `dart fix --apply`                  |
| Pub operations      | `pub`                | `dart pub get` / `flutter pub add`  |

Use bash only in shell-only contexts (CI, pre-commit hooks) or when no MCP equivalent
exists (`build_runner`, `melos`, `flutter build`, `ffigen`). Setup: if `claude mcp list`
doesn't show `dart`, run `claude mcp add -s user dart -- fvm dart mcp-server`
(drop `fvm` if the repo doesn't use it).

## Problem → Skill Mapping

| Problem                                                                     | Start With |
|-----------------------------------------------------------------------------|------------|
| Adding a new screen                                                         | [utopia-cli.md][utopia-cli] (`utopia add screen --json`) → [screen-state-view.md][screen-state-view] |
| What screens/routes/global states already exist in this project?            | [utopia-cli.md][utopia-cli] (`utopia describe`) |
| Repo-wide convention audit / CI gate                                        | [utopia-cli.md][utopia-cli] (`utopia doctor`) |
| Logic is leaking into the View                                              | [screen-state-view.md][screen-state-view] |
| Widget imports in a State class                                             | [screen-state-view.md][screen-state-view] |
| App-wide state (auth, config, data)                                         | [global-state.md][global-state] |
| Screen not reacting to state changes                                        | [global-state.md][global-state] → [hooks-reference.md][hooks-reference] |
| App startup / splash / boot sequencing                                      | [app-bootstrap.md][app-bootstrap] |
| Global states that depend on other global states                            | [app-bootstrap.md][app-bootstrap] |
| Firebase/SDK not initialized race                                           | [app-bootstrap.md][app-bootstrap] |
| Where do uncaught submit/compute errors go?                                 | [error-handling.md][error-handling] |
| Retry dialog for failed operations                                          | [error-handling.md][error-handling] |
| Map backend errors to form field messages                                   | [error-handling.md][error-handling] |
| Declaring routes / typed navigation                                         | [navigation.md][navigation] |
| Navigate in reaction to global state (post-login redirect)                  | [navigation.md][navigation] |
| Screen hosted in bottom sheet / dialog returning a result                   | [navigation.md][navigation] |
| Form submission with loading/error                                          | [async-patterns.md][async-patterns] |
| Settings/preferences screen with per-toggle persistence                     | [async-patterns.md][async-patterns] (`usePersistedState`) + [hooks-reference.md][hooks-reference] |
| Form with validation (multi-field, submit gating)                           | [async-patterns.md][async-patterns] |
| Async data with loading spinner                                             | [async-patterns.md][async-patterns] |
| Paginated list, infinite scroll, cursor/page/token pagination               | [paginated.md][paginated] |
| Pull-to-refresh on a list                                                   | [paginated.md][paginated] (`PaginatedComputedStateWrapper`) |
| Paginated search with debouncing                                            | [paginated.md][paginated] (`keys` + `debounceDuration`) |
| Optimistic updates on a paginated list                                      | [paginated.md][paginated] (optimistic overlay) or [complex-state-examples.md][complex-state-examples] shape 3 |
| Stream that should drive UI                                                 | [hooks-reference.md][hooks-reference] (`useMemoizedStream`) |
| Derived value from other state                                              | [hooks-reference.md][hooks-reference] (`useMemoized`) |
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
| Complex multi-domain or multi-step screen state - what should it look like? | [complex-state-examples.md][complex-state-examples] |
| Screen with bottom nav / tabs / sub-pages the user switches between                | [multi-page-shell.md][multi-page-shell] |
| Inner tab/page is a monolithic HookWidget with inline logic                         | [multi-page-shell.md][multi-page-shell] |
| Bottom nav / tab index needs to survive deep links or cross-screen jumps            | [multi-page-shell.md][multi-page-shell] + [global-state.md][global-state] |

[references]: references/
[screen-state-view]: references/screen-state-view.md
[hooks-reference]: references/hooks-reference.md
[global-state]: references/global-state.md
[async-patterns]: references/async-patterns.md
[paginated]: references/paginated.md
[app-bootstrap]: references/app-bootstrap.md
[error-handling]: references/error-handling.md
[navigation]: references/navigation.md
[composable-hooks]: references/composable-hooks.md
[complex-state-examples]: references/complex-state-examples.md
[testing]: references/testing.md
[flutter-conventions]: references/flutter-conventions.md
[di-services]: references/di-services.md
[multi-page-shell]: references/multi-page-shell.md
[utopia-cli]: references/utopia-cli.md

## Non-Negotiable Rules

- **View never calls hooks** - no `useState`, `useProvided`, `useInjected` in `*_view.dart`. View is always `StatelessWidget`.
- **View constructor takes ONLY `state`** - no extra `onBack`, `onNavigate`, or other parameters. All callbacks are fields on the State class.
- **Screen = pure wiring** - Screen's `build()` reads `BuildContext` (for navigation/dialogs/args) and calls exactly one hook: `useXScreenState(...)`. Screen must NOT call `useInjected`, `useProvided`, `useEffect`, `useState`, or any other hook (single exception: one `useEffect` whose only job is consuming one-shot event fields - see [navigation.md][navigation]).
- **Navigation flows Screen → State → View as callbacks** - never `useProvided<NavigatorKey>` or `useInjected<AppRouter>`. State hook receives navigation as `void Function()` / `Future<T?> Function()` parameters. See [navigation.md][navigation].
- **State never imports widgets** - no Flutter widget imports in `*_screen_state.dart`
- **`useProvided` / `useInjected` only in screen state hooks** - not in Screen, not in View, not passed down as parameters
- **No mutable collections in State classes** - always `IList`/`IMap`/`ISet`, never `List`/`Map`/`Set`, including static data (applies when the project declares `fast_immutable_collections`; brownfield exception in [flutter-conventions.md][flutter-conventions] §2)
- **No manual loading state** - never use `useState<bool>` + `try/catch/finally` for data loading. Always `useAutoComputedState`.
- **No hand-rolled pagination** - never use `useState<List<T>>` + `hasMore` + `cursor` for paginated lists. Always `usePaginatedComputedState` + `PaginatedComputedStateWrapper`. See [paginated.md][paginated].
- **Never construct `ButtonState` by hand for submit-backed buttons** - always `submitState.toButtonState(onTap: ...)` or `useSubmitButtonState` (only the latter guards re-entrant taps - see [async-patterns.md][async-patterns]).
- **Prefer `useMemoized` over `useEffect`** for derived state - effects cascade; memoized values don't
- **One State class per screen** - all screen data in one place, not scattered `useState` calls across the widget tree
- **Never wrap `TextEditingController` in `useMemoized` + `useListenable`** - always `useFieldState` in the state hook + `TextEditingControllerWrapper` in the View. See [flutter-conventions.md][flutter-conventions].
- **View files ≤ ~300 lines** - extract complex widgets to `widget/` folder, using widget-level hook pattern from [composable-hooks.md][composable-hooks] when they have own state
- **Screen files ≤ ~100 lines (soft redflag)** - Screen is pure wiring; if over ~100 it almost always holds Scaffold/layout chrome (belongs in View) or business logic (belongs in state hook). Typical Screen is 30-80 lines. See [screen-state-view.md][screen-state-view].
- **Global state hooks ≤ ~300 lines** - same threshold as screen state hooks. If over, the global is spanning multiple domains; split into separate globals (one per domain in `_providers`), or extract pure helpers/derivations to services. See [global-state.md][global-state].

**The one sanctioned exception - the lightweight tier.** A trivial, self-contained dialog
or component (roughly 30 lines, no navigation fan-out) may be a single-file `HookWidget`
calling `useInjected` / `useSubmitState` directly in `build`. The moment it grows - second
action, derived state, navigation, anything that smells like logic - promote it to the
full Screen/State/View split. Three files stays the default for every screen.
See [screen-state-view.md][screen-state-view] (lightweight tier).

## Self-Audit Checklist

After generating a screen, run down this list. Each item is a one-line check for a rule
above (or a reference pattern) - see the rule for the full rationale and fix:

1. View constructor takes anything beyond `state`? → "View constructor takes ONLY `state`"
2. Screen calls any hook other than `useXScreenState(...)`? → "Screen = pure wiring" (exception: one `useEffect` consuming one-shot event fields - see [navigation.md][navigation])
3. View extends `HookWidget` or calls hooks? → "View never calls hooks"
4. `useState<bool>(true)` / `useState<T?>(null)` for loading/error? → "No manual loading state"
5. Mutable `List`/`Map`/`Set` in the State class? → "No mutable collections in State classes"
6. `useState<List<T>>` + `hasMore` + `cursor` + manual load effect? → "No hand-rolled pagination"
7. Hand-built `ButtonState(...)` next to a submit state? → "Never construct `ButtonState` by hand"
8. `useProvided<NavigatorKey>` / `useInjected<AppRouter>` in a state hook? → "Navigation flows Screen → State → View as callbacks"
9. `useXScreenState(...)` signature accepts `BuildContext`? → same rule; replace with typed callbacks built in the Screen
10. `useMemoized(TextEditingController.new)` + `useListenable`? → "Never wrap `TextEditingController`"
11. Derived value via `useEffect` + `useState`? → "Prefer `useMemoized` over `useEffect`"
12. Two or more `*ScreenState` classes for one screen, or scattered `useState` in the View? → "One State class per screen"
13. Widget imports in `*_screen_state.dart` beyond `Color` / `Duration` / domain types? → "State never imports widgets"
14. View file > ~300 lines? → "View files ≤ ~300 lines"
15. Screen file > ~100 lines? → "Screen files ≤ ~100 lines (soft redflag)"
16. State hook > ~300 lines or > ~10 `useState`? → decompose; [composable-hooks.md][composable-hooks] Pattern 3
17. Global state hook > ~300 lines? → "Global state hooks ≤ ~300 lines"
18. More than 2 `useSubmitState()` in one hook? → group mutually exclusive actions; [async-patterns.md][async-patterns]
19. `widgets/*.dart` extending `HookWidget` and calling `useProvided`/`useInjected`? → mis-classified View; rename to `view/x_screen_view.dart`, see [screen-state-view.md][screen-state-view] Common Pitfalls

## Attribution

Built on [utopia_hooks](https://pub.dev/packages/utopia_hooks) by UtopiaSoftware.
