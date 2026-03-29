---
title: Hook Catalog
impact: CRITICAL
tags: hooks, useState, useMemoized, useEffect, useProvided, useInjected, useIf, useMap, useComputedState, async, streams, animation
---

# Skill: Hook Catalog

Complete reference for utopia_hooks, organized by what you're trying to do.

## Use-Case Index

| I need to… | Hooks |
|---|---|
| Store local mutable state | `useState` |
| Derive a value from other state | `useMemoized` |
| Subscribe to a Stream | `useMemoizedStream` / `useMemoizedStreamData`, `useStreamSubscription` |
| **Load / download data** (read operation) | `useAutoComputedState` (default), `useComputedState` (manual refresh) |
| **Save / upload / mutate** (write operation) | `useSubmitState` (default) |
| Build a form field with validation | `useFieldState` |
| Access global state | `useProvided<T>` |
| Access a service | `useInjected<T>` |
| Run a side effect | `useEffect`, `useImmediateEffect` |
| Conditionally run hooks | `useIf`, `useIfNotNull`, `useKeyed` |
| Run hooks for each item in a collection | `useMap` |
| Handle animations | `useAnimationController` |
| Manage a FocusNode / ScrollController | `useFocusNode`, `useScrollController` |
| React to Listenable / ValueListenable | `useListenable`, `useListenableListener` |
| Debounce a value | `useDebounced` |
| Track previous value | `usePreviousIfNull`, `usePreviousValue` |
| Persist state across app restarts | `usePersistedState` |

---

## 1. Local State

### useState\<T\>

Mutable local state. Returns `MutableValue<T>` — read `.value`, write `.value =`, or use `.modify()` for collections.

```dart
final count = useState(0);
final filter = useState(FilterType.all);
final items = useState<IList<Task>>(const IList.empty());

count.value++;
filter.value = FilterType.active;
items.modify((it) => it.add(newTask));
```

`listen: false` — creates state without triggering rebuilds (for use inside custom hooks):
```dart
final state = useState(value, listen: false);
```

### useMemoized

Cached derived value. Re-computes only when `keys` change. Prefer over `useEffect` for any derived state.

```dart
// ❌ useEffect to derive state — unnecessary indirection
final sorted = useState<IList<Task>?>(null);
useEffect(() {
  sorted.value = tasks?.sortedBy((it) => it.dueDate).toIList();
  return null;
}, [tasks]);

// ✅ useMemoized — direct, no extra state variable
final sorted = useMemoized(
  () => tasks?.sortedBy((it) => it.dueDate).toIList(),
  [tasks],
);
```

With optional dispose callback (for objects that need cleanup):
```dart
final path = useMemoized(() => computePath(points), [points]);

// Dispose previous result when keys change
final image = useMemoized(() => loadImage(url), [url], (img) => img.dispose());
```

---

## 2. Side Effects

### useEffect

Runs after build when `keys` change. Return value is an optional cleanup function.

```dart
// Once on mount
useEffect(() {
  analytics.trackScreen('product_detail');
  return null;
}, []);

// When value changes
useEffect(() {
  if (assessmentId != null) partIdsState.value = getDefaultPartIds(assessmentId);
  return null;
}, [assessmentId]);

// With cleanup
useEffect(() {
  final sub = eventBus.listen(handler);
  return sub.cancel;
}, []);
```

`useImmediateEffect` — runs synchronously during build (not after), same signature.

**Rule:** Only use `useEffect` for side effects (analytics, mutations, subscriptions). For derived values, use `useMemoized`.

### useIsMounted

Guards async callbacks against state updates after widget dispose:

```dart
final isMounted = useIsMounted();

Future<void> load() async {
  final result = await service.fetch();
  if (isMounted()) state.value = result;  // safe
}
```

---

## 3. Streams & Futures

### useMemoizedStream

Subscribes to a `Stream<T>`. Re-subscribes when `keys` change.

```dart
// Stream via injected service
final authService = useInjected<AuthService>();
final snap = useMemoizedStream(authService.streamUser);

// Parameterized stream — re-subscribes when userId changes
final ordersSnap = useMemoizedStream(
  () => orderService.streamOrders(userId),
  keys: [userId],
);

// Reading the snapshot
snap.data                                           // T? — null before first event
snap.connectionState == ConnectionState.active      // stream connected + data received
snap.hasError                                       // error state
```

### useMemoizedStreamData / useStreamData

Convenience wrappers that return `T?` directly instead of `AsyncSnapshot<T>`:

```dart
// Returns T? — null until first event. Logs errors via onError.
final orders = useMemoizedStreamData(
  () => orderService.streamOrders(userId),
  keys: [userId],
  onError: (e, st) => logger.error('Stream error', e, st),
);

// Same for one-shot stream
final data = useStreamData(someStream);
```

Equivalent to `useMemoizedStream(...).data` but with integrated error handling via `onError` callback.

Also available: `useMemoizedFutureData` / `useFutureData` — same pattern for futures:

```dart
final profile = useMemoizedFutureData(
  () => userService.loadProfile(userId),
  keys: [userId],
);
// profile is T? — null while loading
```

### useStreamSubscription

Subscribe and react to each event — use when you need side effects per event, not just the latest value.

```dart
useStreamSubscription(
  eventStream,
  (event) async => handleEvent(event),
  strategy: StreamSubscriptionStrategy.drop,  // drop new events while handling current
);
```

Strategies:
| Strategy | Behavior |
|----------|----------|
| `parallel` | Handle events concurrently |
| `pause` | Pause stream while handler runs |
| `drop` | Drop new events while handler runs |

### useStreamController

Auto-disposed `StreamController<T>`:

```dart
final controller = useStreamController<String>();
// controller.sink.add(event) / controller.stream
```

### useMemoizedFuture / useMemoizedFutureData

Low-level future hooks. **Prefer `useAutoComputedState` for loading data** — it provides `isInitialized`, state management, `shouldCompute` guards, and debouncing. Use `useMemoizedFuture` only when you specifically need raw `AsyncSnapshot<T>` semantics:

```dart
final snap = useMemoizedFuture(
  () => userService.loadProfile(userId),
  keys: [userId],
);
final profile = snap.data;  // null while loading
```

### useDebounced

Delays propagating a value change until the user stops for `duration`:

```dart
final query = useState('');
final debouncedQuery = useDebounced(query.value, duration: const Duration(milliseconds: 300));

// debouncedQuery only changes 300ms after user stops typing
final results = useAutoComputedState(
  () => searchService.search(debouncedQuery),
  keys: [debouncedQuery],
);
```

### usePeriodicalSignal

Periodic rebuild trigger:

```dart
final tick = usePeriodicalSignal(period: const Duration(seconds: 30));
final liveData = useMemoized(() => service.snapshot(), [tick]);
```

---

## 4. Async Operations — Download vs Upload

The two core async primitives map to a simple mental model:

| Direction | Hook | Trigger | Typical use |
|-----------|------|---------|-------------|
| **Download** (read) | `useAutoComputedState` | Automatic (keys change) | Load data, fetch lists, compute results |
| **Upload** (write) | `useSubmitState` | Manual (user action) | Save, delete, send, create — any mutation |

**Default rule:** reading data → `useAutoComputedState`. Writing/mutating data → `useSubmitState`.

### useAutoComputedState

**Your default "download" hook.** Auto-loads async data, re-fetches when `keys` change. Full coverage in [async-patterns.md](./async-patterns.md).

Use for any read operation: loading a screen's data, fetching a list, computing a result from an API.

### useSubmitState

**Your default "upload" hook.** Manages user-triggered write operations: save, delete, send, update. Full coverage in [async-patterns.md](./async-patterns.md).

Built-in protections:
- **Blocks duplicate requests** — `inProgress` prevents firing the same action twice; `skipIfInProgress` param silently drops
- **Retry support** — `isRetryable` parameter for failed operations
- **Typed error routing** — `mapError` converts raw exception to typed `E`, `afterKnownError` handles it

```dart
final saveState = useSubmitState();

void save() => saveState.runSimple<void, AppError>(
  submit: () async => service.save(data),
  afterSubmit: (_) => navigateBack(),
  mapError: (e) => e is AppError ? e : null,
  afterKnownError: (e) => showSnackbar(e.message),
);

saveState.inProgress       // bool — true while request is in flight
saveState.toButtonState(enabled: isValid, onTap: save)  // ButtonState for UI
```

### useAutoComputedState (continued)

Auto-loads async data, re-fetches when `keys` change.

```dart
final product = useAutoComputedState(
  () async => productService.load(productId),
  keys: [productId],
  shouldCompute: authState.isInitialized,
);

product.isInitialized   // false while loading
product.valueOrNull     // T? — null while loading
```

### useComputedState

Manual version of `useAutoComputedState` — you call `refresh()` yourself:

```dart
final state = useComputedState(() async => service.load());

// Trigger manually
state.refresh();

// States: notInitialized / inProgress / ready(T) / failed(Object)
state.value.when(
  notInitialized: () => const Loader(),
  inProgress: (_) => const Loader(),
  ready: (data) => DataView(data),
  failed: (e) => ErrorView(e.toString()),
);
```

### usePersistedState

Syncs local state with persistent storage (SharedPreferences, Hive, etc.):

```dart
final themePreference = usePersistedState<ThemeMode>(
  get: () async => prefs.getThemeMode(),
  set: (value) async => prefs.setThemeMode(value),
);

themePreference.isInitialized   // false until first load
themePreference.isSynchronized  // false while saving
themePreference.value           // current value
themePreference.value = ThemeMode.dark;  // triggers save
```

### usePreferencesPersistedState (from utopia_arch)

Convenience wrapper that combines `usePersistedState` with `PreferencesService` (SharedPreferences):

```dart
// Simple types (String, int, double, bool)
final locale = usePreferencesPersistedState<String>('locale', defaultValue: 'en');

// Enums
final theme = useEnumPreferencesPersistedState<ThemeMode>('theme', ThemeMode.values);

// Complex types with serialization
final config = useComplexPreferencesPersistedState<Config, String>(
  'config',
  toPreferences: (it) => jsonEncode(it.toJson()),
  fromPreferences: (it) => Config.fromJson(jsonDecode(it)),
);
```

Returns same `PersistedState<T>` as `usePersistedState`.

---

## 5. Forms & Buttons

### useFieldState / useGenericFieldState

Field with value + validation error. Integrates with form text fields.

Returns `MutableFieldState` (alias for `MutableGenericFieldState<String>`) which has:
- `.value` — current field value (read/write via `MutableValue<T>`)
- `.errorMessage` — validation error (type `ValidatorResult?` = `String Function(BuildContext)?`)
- `.hasError` — convenience getter
- `.validate(validator)` — runs validator and sets `.errorMessage`

```dart
final email = useFieldState(initialValue: user?.email ?? '');
final age = useGenericFieldState<int>(initialValue: 0);

// Validate manually
email.errorMessage = isValidEmail(email.value) ? null : (context) => 'Invalid email';

// Or use .validate() with a Validator<T>
email.validate((value) => isValidEmail(value) ? null : (context) => 'Invalid email');

// In View — error displayed automatically
CrazyTextField(state: state.email, label: const Text("Email"))
```

### useSubmitButtonState

Shorthand for submit + button wired together:

```dart
final saveButton = useSubmitButtonState(
  () async => service.save(data),
  enabled: nameState.value.isNotEmpty,
);

// saveButton is a ButtonState — pass directly to button
CrazySquashButton.withState(state: saveButton, child: const Text("Save"))
```

---

## 6. Global State Access

### useProvided\<T\>

Reads global state registered in `_providers`. Only valid in State hooks.

```dart
// ❌ In View
class TasksPageView extends StatelessWidget {
  Widget build(BuildContext context) {
    final auth = useProvided<AuthState>(); // WRONG
  }
}

// ✅ In State hook only
TasksPageState useTasksPageState() {
  final auth = useProvided<AuthState>();
  final tasks = useProvided<TasksState>();
  // ...
}
```

### useInjected\<T\>

Gets a registered service. Only valid in State hooks. See [di-services.md](./di-services.md).

```dart
final taskService = useInjected<TaskService>();
final analytics = useInjected<AnalyticsService>();
```

---

## 7. Composition & Conditionals

Hooks cannot be called inside `if` blocks or loops. These hooks solve that.

### useIf / useIfNotNull

```dart
// Run hooks only when condition is true
final details = useIf(isExpanded, () =>
  useAutoComputedState(() => service.loadDetails(id), keys: [id]),
);
// details is T? — null when condition is false

// Run hooks only when value is non-null
useIfNotNull(pupilId, (id) => useEnsureClassPupil(id, onNotPresent: () => pupilIdState.value = null));
```

### useKeyed

Re-runs the block (creating fresh hook state) when keys change:

```dart
// Fresh hook state whenever userId changes
final userHooks = useKeyed([userId], () {
  final profile = useAutoComputedState(() => service.load(userId));
  return profile;
});
```

### useMap

Runs a hook for each key in a `Set`. Keys can change dynamically.

```dart
// ❌ Hook inside loop — breaks ordering
for (final id in courseIds) {
  final state = useAutoComputedState(() => load(id), keys: [id]); // WRONG
}

// ✅ useMap — one hook instance per key, stable across rebuilds
final courseStates = useMap(
  courseIds.toSet(),
  (id) => useAutoComputedState(() => courseService.load(id), keys: [id]),
);
```

State survives key set changes — existing keys keep their state, new keys start fresh, removed keys are disposed.

---

## 8. Flutter Controllers

Auto-created and auto-disposed.

### useAnimationController

```dart
final controller = useAnimationController(
  duration: const Duration(milliseconds: 300),
  initialValue: 0,
);

// Staggered animations
final (fade, slide) = useAnimationController(duration: 400.ms).staggered([
  0.0.tweenTo(1.0),
  Offset(0, 32).tweenTo(Offset.zero),
]);

controller.forward();
FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: content))
```

### useFocusNode / useScrollController

```dart
final focus = useFocusNode();
final scroll = useScrollController(initialScrollOffset: 0);

TextField(focusNode: focus)
ListView(controller: scroll)
```

### useAppLifecycleState

```dart
useAppLifecycleState(
  onPaused: () => saveState(),
  onResumed: () => refreshData(),
);
```

---

## 9. Reactive / Listenable

### useListenable / useValueListenable

Rebuilds widget when a `Listenable` notifies:

```dart
final value = useValueListenable(someValueNotifier);
// Rebuilds only when value changes (uses shouldRebuild for fine control)
final value = useValueListenable(
  notifier,
  shouldRebuild: (prev, curr) => prev.id != curr.id,
);
```

### useListenableListener / useListenableValueListener

Side-effect on change (no rebuild):

```dart
useListenableValueListener(scrollController, (offset) {
  if (offset > threshold) showFloatingButton.value = true;
});
```

### useNotifiable

Trigger manual rebuilds without storing a value:

```dart
final notifiable = useNotifiable();
// somewhere in a callback:
notifiable.notify(); // triggers rebuild
```

---

## 10. Utilities

### usePreviousIfNull

Returns last non-null value — useful for keeping content visible during reload:

```dart
// Without: content disappears while refreshing
final data = useAutoComputedState(() => service.load(id), keys: [id]);
final display = data.valueOrNull; // null during refresh = blank screen

// With usePreviousIfNull: old content stays visible during refresh
final display = usePreviousIfNull(data.valueOrNull);
```

### usePreviousValue

```dart
final prev = usePreviousValue(currentPage);
final direction = prev != null && currentPage > prev ? 'forward' : 'back';
```

### useValueChanged

Detect a value change and compute something:

```dart
final scrollDelta = useValueChanged<double, double>(
  scrollOffset,
  (oldOffset, _) => scrollOffset - oldOffset,
);
```

### useMemoizedIf

Conditional `useMemoized` — returns null when condition is false:

```dart
final details = useMemoizedIf(isExpanded, () => computeDetails(item), [item]);
// details is T? — null when isExpanded == false
```

### useCombinedInitializationState

Wait for multiple global states to all be initialized:

```dart
final allReady = useCombinedInitializationState({AuthState, CoursesState, TeacherState});
if (!allReady.isInitialized) return const SplashScreen();
```

---

## Common Pitfalls

- **Calling hooks conditionally** — `if (x) useState(...)` breaks hook ordering; use `useIf` instead
- **Calling hooks in loops** — use `useMap` instead
- **useState for derived values** — if computable from other state, use `useMemoized`
- **Cascading useEffects** — effect A → sets state B → triggers effect B → ...; redesign with `useMemoized`
- **useProvided / useInjected in View** — `StatelessWidget` is not a hook context

## Related Skills

- [page-state-view.md](./page-state-view.md) — where hooks live (State hook)
- [global-state.md](./global-state.md) — global state registration and useProvided
- [async-patterns.md](./async-patterns.md) — useSubmitState and useAutoComputedState in depth
- [composable-hooks.md](./composable-hooks.md) — useMap and useIf in widget-level hooks
- [testing.md](./testing.md) — testing hooks with SimpleHookContext
