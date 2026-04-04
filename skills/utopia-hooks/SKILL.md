---
name: utopia-hooks
description: >
  Flutter state management with utopia_hooks. Applies when writing Flutter screens,
  adding shared app state, handling async operations, injecting services, or migrating
  away from StatefulWidget. Covers the Page/State/View pattern, hook catalog, global
  state registration, useSubmitState, useAutoComputedState, and dependency injection.
license: MIT
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_hooks, utopia_arch, state-management, hooks
---

# utopia_hooks — Flutter State Management

## Overview

Holistic state management for Flutter using hooks. Every screen follows the
**Page → State → View** tripartite pattern. Shared app state lives in
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
- Injecting a service into a screen or registering a new dependency
- Reviewing Flutter code — looking for logic in View, widgets in State, or raw `setState` patterns
- Migrating from `StatefulWidget`, BLoC, Riverpod, or Provider

## Priority-Ordered Guidelines

| Priority | Category                              | Impact   | Reference |
|----------|---------------------------------------|----------|-----------|
| 1        | Screen architecture (Page/State/View) | CRITICAL | [page-state-view.md][page-state-view] |
| 2        | Hook catalog & correct usage          | CRITICAL | [hooks-reference.md][hooks-reference] |
| 3        | Async patterns (download / upload)    | HIGH     | [async-patterns.md][async-patterns] |
| 4        | Flutter code conventions              | HIGH     | [flutter-conventions.md][flutter-conventions] |
| 5        | Global shared state                   | HIGH     | [global-state.md][global-state] |
| 6        | Dependency injection & services       | MEDIUM   | [di-services.md][di-services] |
| 7        | Composable & widget-level hooks       | MEDIUM   | [composable-hooks.md][composable-hooks] |
| 8        | Testing hooks in isolation            | MEDIUM   | [testing.md][testing] |

## Quick Reference

### Screen Architecture (CRITICAL)

Every screen = **3 files**. No exceptions.

```
feature_page.dart          ← HookWidget, zero logic
state/feature_page_state.dart   ← State class + hook
view/feature_page_view.dart     ← StatelessWidget, UI only
```

**Page** — connects callbacks, renders View:
```dart
class TaskPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTaskPageState(
      navigateToDetail: (id) => context.router.push(TaskDetailRoute(id: id)),
    );
    return TaskPageView(state: state);
  }
}
```

**State** — immutable data class + hook with all logic:
```dart
class TaskPageState {
  final IList<Task> tasks;
  final bool isLoading;
  final void Function(TaskId) onTaskTapped;
  const TaskPageState({required this.tasks, required this.isLoading, required this.onTaskTapped});
}

TaskPageState useTaskPageState({required void Function(TaskId) navigateToDetail}) {
  final tasksState = useProvided<TasksState>();
  return TaskPageState(
    tasks: tasksState.tasks ?? const IList.empty(),
    isLoading: !tasksState.isInitialized,
    onTaskTapped: navigateToDetail,
  );
}
```

**View** — pure UI, no hooks, no logic:
```dart
class TaskPageView extends StatelessWidget {
  final TaskPageState state;
  const TaskPageView({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const CrazyLoader();
    return ListView(children: state.tasks.map(_buildTask).toList());
  }
}
```

### Global State Registration (CRITICAL)

```dart
// 1. State class
class SettingsState extends HasInitialized {
  final ThemeMode themeMode;
  const SettingsState({required super.isInitialized, required this.themeMode});
}

// 2. Hook
SettingsState useSettingsState() {
  final snap = useMemoizedStream(settingsStream);
  return SettingsState(
    isInitialized: snap.connectionState == ConnectionState.active,
    themeMode: snap.data?.themeMode ?? ThemeMode.system,
  );
}

// 3. Register in app root — once
const _providers = {
  SettingsState: useSettingsState,
  // ...
};
```

### Async: Download vs Upload (HIGH)

```dart
// DOWNLOAD (read) → useAutoComputedState
final product = useAutoComputedState(
  () async => productService.load(productId),
  keys: [productId],
  shouldCompute: authState.isInitialized,
);
// product.isInitialized / product.valueOrNull

// UPLOAD (write) → useSubmitState — let errors crash by default
final submitState = useSubmitState();
void save() => submitState.runSimple<void, Never>(
  submit: () async => service.save(data),
  afterSubmit: (_) => navigateBack(),
);
// submitState.inProgress — blocks duplicate requests
// submitState.toButtonState(enabled: isValid, onTap: save)
```

## References

Full documentation with code examples in [references/][references]:

| File | Impact | Description |
|------|--------|-------------|
| [page-state-view.md][page-state-view] | CRITICAL | 3-file screen pattern: Page, State class + hook, View |
| [hooks-reference.md][hooks-reference] | CRITICAL | Full hook catalog: useState, useMemoized, useEffect, useProvided, useInjected, useIf, useMap, useComputedState |
| [global-state.md][global-state] | CRITICAL | App-wide state: StateClass, HasInitialized, MutableValue, _providers registration |
| [async-patterns.md][async-patterns] | HIGH | useSubmitState, useAutoComputedState, useMemoizedStream, loading guards |
| [composable-hooks.md][composable-hooks] | HIGH | Widget-level hooks (expand/animate/lazy-load) and composed hook state (paging, reusable fields) |
| [testing.md][testing] | HIGH | Unit testing hooks with SimpleHookContext and SimpleHookProviderContainer — no widget tree needed |
| [flutter-conventions.md][flutter-conventions] | HIGH | IList/IMap/ISet, `it` lambdas, strict analyzer, widget extraction, spacing, generated code |
| [di-services.md][di-services] | MEDIUM | Injector registration, useInjected, service types (Firebase/Api/Data) |

## Searching References

```bash
# Find patterns by hook name
grep -rl "useSubmitState" references/
grep -rl "useMemoizedStream" references/
grep -rl "HasInitialized" references/
grep -rl "MutableValue" references/
grep -rl "useInjected" references/
grep -rl "useProvided" references/
```

## Problem → Skill Mapping

| Problem | Start With |
|---------|------------|
| Adding a new screen | [page-state-view.md][page-state-view] |
| Logic is leaking into the View | [page-state-view.md][page-state-view] |
| Widget imports in a State class | [page-state-view.md][page-state-view] |
| App-wide state (auth, config, data) | [global-state.md][global-state] |
| Screen not reacting to state changes | [global-state.md][global-state] → [hooks-reference.md][hooks-reference] |
| Form submission with loading/error | [async-patterns.md][async-patterns] |
| Async data with loading spinner | [async-patterns.md][async-patterns] |
| Stream that should drive UI | [hooks-reference.md][hooks-reference] (useMemoizedStream) |
| Derived value from other state | [hooks-reference.md][hooks-reference] (useMemoized) |
| Widget with expand/collapse, animation, lazy load | [composable-hooks.md][composable-hooks] (widget-level hook) |
| Reusable widget used N times on one screen | [composable-hooks.md][composable-hooks] (composed hook state) |
| Screen state polluted with per-tile logic | [composable-hooks.md][composable-hooks] (widget-level hook) |
| Paging, specialized text field, reusable control | [composable-hooks.md][composable-hooks] (composed hook state) |
| Testing a page state hook | [testing.md][testing] |
| Testing global state and state interactions | [testing.md][testing] |
| Injecting a service into a screen | [di-services.md][di-services] |
| Registering a new service or state | [di-services.md][di-services] |
| Using `List` / `Map` / `Set` instead of immutable | [flutter-conventions.md][flutter-conventions] |
| Lambda style, naming, widget extraction | [flutter-conventions.md][flutter-conventions] |
| Generated code out of date | [flutter-conventions.md][flutter-conventions] |
| Replacing StatefulWidget | [page-state-view.md][page-state-view] + [hooks-reference.md][hooks-reference] |

[references]: references/
[page-state-view]: references/page-state-view.md
[hooks-reference]: references/hooks-reference.md
[global-state]: references/global-state.md
[async-patterns]: references/async-patterns.md
[composable-hooks]: references/composable-hooks.md
[testing]: references/testing.md
[flutter-conventions]: references/flutter-conventions.md
[di-services]: references/di-services.md

## Non-Negotiable Rules

- **View never calls hooks** — no `useState`, `useProvided`, `useInjected` in `*_view.dart`. View is always `StatelessWidget`.
- **View constructor takes ONLY `state`** — no extra `onBack`, `onNavigate`, or other parameters. All callbacks are fields on the State class.
- **Page = pure wiring** — Page must not call `useInjected` or contain business logic. Only `useProvided<NavigatorKey>` / context-dependent values to build navigation callbacks passed to the state hook.
- **State never imports widgets** — no Flutter widget imports in `*_page_state.dart`
- **`useProvided` / `useInjected` only in page state hooks** — not in View, not passed down as parameters
- **No mutable collections in State classes** — always `IList`/`IMap`/`ISet`, never `List`/`Map`/`Set`, including static data
- **No manual loading state** — never use `useState<bool>` + `try/catch/finally` for data loading. Always `useAutoComputedState`.
- **Prefer `useMemoized` over `useEffect`** for derived state — effects cascade; memoized values don't
- **One State class per screen** — all screen data in one place, not scattered `useState` calls across the widget tree
- **View files ≤ ~150 lines** — extract complex widgets to `widget/` folder, using widget-level hook pattern from [composable-hooks.md](references/composable-hooks.md) when they have own state

## Self-Audit Checklist

After generating a screen, verify:

1. Does the View constructor take anything beyond `state`? → Move it to the State class
2. Does the Page call `useInjected` or `useProvided` (beyond `NavigatorKey`)? → Move to state hook
3. Are there `useState<bool>(true)` / `useState<T?>(null)` for loading/error? → Use `useAutoComputedState`
4. Are there mutable `List<T>`, `Map<K,V>`, `Set<T>` in the State class? → Use `IList`/`IMap`/`ISet`
5. Are there more than 2 `useSubmitState()` in one hook? → Group mutually exclusive actions
6. Is any view file > 150 lines? → Extract widgets to `widget/` folder
7. Does the View extend `HookWidget`? → Must be `StatelessWidget`

## Attribution

Built on [utopia_hooks](https://pub.dev/packages/utopia_hooks) and [utopia_arch](https://pub.dev/packages/utopia_arch) by UtopiaSoftware.
