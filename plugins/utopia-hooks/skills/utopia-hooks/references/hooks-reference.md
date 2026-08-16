---
title: Hook Catalog
impact: CRITICAL
tags: hooks, useState, useStateLazy, useMemoized, useEffect, useProvided, useInjected, useIf, useMap, useComputedState, useSubmitState, ComputedStateWrapper, Retryable, async, streams, animation
---

# Skill: Hook Catalog

Complete reference for utopia_hooks, organized by what you're trying to do.

## Use-Case Index

| I need to… | Hooks |
|---|---|
| Store local mutable state | `useState`, `useStateLazy` (expensive initial value) |
| Derive a value from other state | `useMemoized` |
| Subscribe to a Stream | `useMemoizedStream` / `useMemoizedStreamData`, `useStreamSubscription` |
| **Load / download data** (read operation) | `useAutoComputedState` (default), `useComputedState` (manual refresh) |
| **Render a ComputedState in the View** | `ComputedStateWrapper`, `RefreshableComputedStateWrapper` (+ iterable variants) |
| **Save / upload / mutate** (write operation) | `useSubmitState` (default) |
| **Paginated / infinite-scroll list** (cursor/page/token) | `usePaginatedComputedState` + `PaginatedComputedStateWrapper` |
| Make failed operations retryable | `isRetryable` param + `Retryable.tryGet` (see [error-handling.md](./error-handling.md)) |
| Build a form field with validation | `useFieldState` |
| Access global state | `useProvided<T>` |
| Access a service | `useInjected<T>` |
| Run a side effect | `useEffect`, `useImmediateEffect` |
| Conditionally run hooks | `useIf`, `useIfNotNull`, `useKeyed` |
| Run hooks for each item in a collection | `useMap` |
| Handle animations | `useAnimationController` |
| Manage a FocusNode / ScrollController | `useFocusNode`, `useScrollController` (0.4.25: not exported - see section 8) |
| React to Listenable / ValueListenable | `useListenable`, `useListenableListener` |
| Debounce a value | `useDebounced` |
| Track previous value | `usePreviousIfNull`, `usePreviousValue` |
| Persist state across app restarts | `usePersistedState` |

---

## 1. Local State

### useState\<T\>

Mutable local state. Signature: `StateHookState<T> useState<T>(T initialValue, {bool listen = true, HookKeys keys})`. `StateHookState<T>` implements `MutableValue<T>` - read `.value`, write `.value =`, or use `.modify()` for collections.

The setter early-returns when the new value `==` the current one - no rebuild, no notification. Records compare structurally, so writing an identical record is a silent no-op. If a repeated identical write must still trigger downstream work (e.g. re-reading a source that changed externally), do not rely on the write - call the computed state's `refresh()` or include a changing component in the key.

```dart
final countState = useState(0);
final filterState = useState(FilterType.all);
final itemsState = useState<IList<Task>>(const IList.empty());

countState.value++;
filterState.value = FilterType.active;
itemsState.modify((it) => it.add(newTask));
```

`listen: false` - creates state without triggering rebuilds (for use inside custom hooks):
```dart
final dataState = useState(value, listen: false);
```

`keys:` - resets the state back to `initialValue` when the keys change:
```dart
final selectionState = useState<ItemId?>(null, keys: [categoryId]);  // cleared when category changes
```

`StateHookState` also exposes `mounted` and `setIfMounted(value)` - use them in async callbacks that may complete after dispose (setting `.value` on an unmounted state throws in debug mode):
```dart
final progressState = useState(0.0);
Future<void> track(Stream<double> events) async {
  await for (final p in events) {
    if (!progressState.setIfMounted(p)) return;  // stop when unmounted
  }
}
```

### useStateLazy\<T\>

Same as `useState`, but the initial value is built by a function on first use - for expensive-to-construct initial values:

```dart
final draftState = useStateLazy(() => buildInitialDraft(template));  // runs once, not on every build
```

Signature: `StateHookState<T> useStateLazy<T>(T Function() init, {bool listen = true, HookKeys keys})`.

### useMemoized

Cached derived value. Re-computes only when `keys` change. Prefer over `useEffect` for any derived state.

```dart
// ❌ useEffect to derive state - unnecessary indirection
final sortedState = useState<IList<Task>?>(null);
useEffect(() {
  sortedState.value = tasks?.sortedBy((it) => it.dueDate).toIList();
  return null;
}, [tasks]);

// ✅ useMemoized - direct, no extra state variable
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

When the compute body is non-trivial, give it a **named local function** instead of a private top-level helper - it captures the hook's params by closure and reads better. The local function must stay pure compute (no hook calls). See [flutter-conventions.md](./flutter-conventions.md) §7.

```dart
int useCustomState(int a) {
  int computeNext() => a + 1;
  return useMemoized(computeNext, [a]);
}
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
  if (courseId != null) sectionIdsState.value = getDefaultSectionIds(courseId);
  return null;
}, [courseId]);

// With cleanup
useEffect(() {
  final sub = eventBus.listen(handler);
  return sub.cancel;
}, []);
```

`useImmediateEffect` - runs synchronously during build (not after), same signature.

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

// Parameterized stream - re-subscribes when userId changes
final ordersSnap = useMemoizedStream(
  () => orderService.streamOrders(userId),
  keys: [userId],
);

// Reading the snapshot
snap.data                                           // T? - null before first event
snap.connectionState == ConnectionState.active      // stream connected + data received
snap.hasError                                       // error state
```

### useMemoizedStreamData / useStreamData

Convenience wrappers that return `T?` directly instead of `AsyncSnapshot<T>`:

```dart
// Returns T? - null until first event. Logs errors via onError.
final orders = useMemoizedStreamData(
  () => orderService.streamOrders(userId),
  keys: [userId],
  onError: (e, st) => logger.error('Stream error', e, st),
);

// Same for one-shot stream
final data = useStreamData(someStream);
```

Equivalent to `useMemoizedStream(...).data` but with integrated error handling via `onError` callback.

Also available: `useMemoizedFutureData` / `useFutureData` - same pattern for futures:

```dart
final profile = useMemoizedFutureData(
  () => userService.loadProfile(userId),
  keys: [userId],
);
// profile is T? - null while loading
```

### useStreamSubscription

Subscribe and react to each event - use when you need side effects per event, not just the latest value. Accepts `Stream<T>?` - null stream is a no-op. **Re-subscribes automatically** when the stream reference changes (internally uses `useEffect` with `[stream]`).

```dart
useStreamSubscription(
  eventStream,
  (event) async => handleEvent(event),
  strategy: StreamSubscriptionStrategy.drop,  // drop new events while handling current
  onDone: () => isComplete.value = true,
  onError: (e, st) => logger.error(e),
);

// Nullable stream - no subscription until stream is available
final stream = useMemoizedIf(isReady, () => buildStream(), [dep]);
useStreamSubscription(stream, (event) async => handle(event));
```

Strategies:
| Strategy | Behavior |
|----------|----------|
| `parallel` | Handle events concurrently (default) |
| `pause` | Pause stream while handler runs |
| `drop` | Drop new events while handler runs |

### useStreamController

Auto-disposed `StreamController<T>`:

```dart
final controller = useStreamController<String>();
// controller.sink.add(event) / controller.stream
```

### useMemoizedFuture / useMemoizedFutureData

Low-level future hooks. **Prefer `useAutoComputedState` for loading data** - it provides `isInitialized`, state management, `shouldCompute` guards, and debouncing. Use `useMemoizedFuture` only when you specifically need raw `AsyncSnapshot<T>` semantics:

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
final queryState = useState('');
final debouncedQuery = useDebounced(queryState.value, duration: const Duration(milliseconds: 300));

// debouncedQuery only changes 300ms after user stops typing
final resultsState = useAutoComputedState(
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

## 4. Async Operations - Download vs Upload

The two core async primitives map to a simple mental model:

| Direction | Hook | Trigger | Typical use |
|-----------|------|---------|-------------|
| **Download** (read) | `useAutoComputedState` | Automatic (keys change) | Load data, fetch lists, compute results |
| **Upload** (write) | `useSubmitState` | Manual (user action) | Save, delete, send, create - any mutation |
| **Paginated download** (cursor) | `usePaginatedComputedState` | Automatic first page + scroll/button `loadMore` | Feeds, search results, chat history, any paged list |

**Default rule:** reading one-shot data → `useAutoComputedState`. Writing/mutating → `useSubmitState`. Cursor-paginated data → `usePaginatedComputedState`.

### useAutoComputedState

**Your default "download" hook.** Auto-loads async data on first build, re-fetches when `keys` change. Use for any read operation: loading a screen's data, fetching a list, computing a result from an API. Returns `MutableComputedState<T>` - you can not only read it, but also drive it manually. Full coverage in [async-patterns.md](./async-patterns.md).

```dart
final productState = useAutoComputedState(
  () async => productService.load(productId),
  keys: [productId],
  shouldCompute: authState.isInitialized,
);

// Reading
productState.isInitialized   // false until first ready value
productState.valueOrNull     // T? - null while loading / not initialized
productState.value           // ComputedStateValue<T> - notInitialized / inProgress / ready(T) / failed(e)

// Driving it manually: refresh() / updateValue(next) / clear()
// In-flight semantics + the parallel-useState anti-pattern: async-patterns.md "Driving it manually"
```

Signature:

```dart
MutableComputedState<T> useAutoComputedState<T>(
  Future<T> Function() compute, {
  bool shouldCompute = true,
  HookKeys keys = hookKeysEmpty,
  Duration debounceDuration = Duration.zero,
  bool isRetryable = false,
});
```

- `shouldCompute: false` skips computing AND clears the state immediately; when it flips back to `true`, data is re-fetched.
- `debounceDuration` delays the compute after `keys` change - useful for search-as-you-type.
- `isRetryable: true` wraps errors thrown by `compute` via `Retryable.make`, so an app-level handler can re-run the compute with `Retryable.tryGet(error)?.retry()`. Opt-in (default `false`). See [error-handling.md](./error-handling.md).

### useComputedState

Manual version of `useAutoComputedState` - nothing runs until you call `refresh()` yourself. Signature: `useComputedState<T>(Future<T> Function() compute, {bool isRetryable = false})` - same `isRetryable` semantics as above. Returns the same `MutableComputedState<T>`, so the mutators above and the `value.when(...)` states (`notInitialized` / `inProgress` / `ready(T)` / `failed(Object)`) apply here too.

### Rendering ComputedState in the View

Before hand-rolling `valueOrNull` null checks in the View, reach for the bundled wrapper widgets - they handle the in-progress / failed / ready branching for you. Hand-rolled null checks stay acceptable for simple cases.

```dart
ComputedStateWrapper<Product>(
  state: state.product,
  inProgressBuilder: (context) => const Loader(),
  failedBuilder: (context) => const ErrorPlaceholder(),
  builder: (context, product) => ProductDetails(product: product),
)
```

| Widget | What it adds |
|---|---|
| `ComputedStateWrapper<E>` | `inProgressBuilder` / `failedBuilder` / `builder(context, value)` + `keepInProgress` |
| `RefreshableComputedStateWrapper<E>` | same, wrapped in `RefreshIndicator` calling `state.refresh()` (takes a `RefreshableComputedState<E>`) |
| `ComputedIterableWrapper<I>` | adds required `emptyBuilder` shown when the iterable is empty |
| `RefreshableComputedIterableWrapper<I>` | iterable variant + pull-to-refresh; `RefreshableComputedListWrapper<E>` typedef for `List<E>` |

All take `keepInProgress` (default `false`): when `true`, the last ready value stays visible during a reload instead of flashing `inProgressBuilder` - the View-side fix for refresh blink (see the sticky-value pattern in [async-patterns.md](./async-patterns.md)).

For paginated lists use `PaginatedComputedStateWrapper` instead (see [paginated.md](./paginated.md)).

### useSubmitState

**Your default "upload" hook.** Manages user-triggered write operations: save, delete, send, update. Full coverage in [async-patterns.md](./async-patterns.md).

What it actually does:
- **Counts in-flight runs** - `inProgress` is `true` while at least one `run` is executing. It does NOT block duplicate calls by itself - see "Guarding duplicate submissions" in [async-patterns.md](./async-patterns.md) for the three guards.
- **Unhandled errors crash** - default behavior, don't swallow; only use `mapError`/`afterKnownError` for specific error UX. See [error-handling.md](./error-handling.md) for where they land.
- **Errors are retryable by default** - `run`'s `isRetryable` defaults to `true`: thrown errors are wrapped via `Retryable.make`, so an app-level handler can offer a retry.

```dart
final saveState = useSubmitState();

// Default - let errors crash
void save() => saveState.runSimple<void, Never>(
  submit: () async => service.save(data),
  afterSubmit: (_) => navigateBack(),
);

saveState.inProgress       // bool - true while at least one run is in flight
saveState.toButtonState(enabled: isValid, onTap: save)  // ButtonState for UI
```

`run<T>(block, {bool isRetryable = true})` is the low-level primitive; `runSimple<T, E>` layers structured lifecycle callbacks on top. Full signature:

```dart
Future<void> runSimple<T, E>({
  FutureOr<bool> Function()? shouldSubmit,         // pre-check, return false to abort
  FutureOr<void> Function()? afterShouldNotSubmit, // runs when shouldSubmit returned false
  FutureOr<void> Function()? beforeSubmit,         // runs before submit
  required Future<T> Function() submit,            // the async work
  FutureOr<void> Function(T)? afterSubmit,         // called on success with result
  FutureOr<E?> Function(Object)? mapError,         // convert raw error → typed E (null = unknown)
  FutureOr<void> Function(E)? afterKnownError,     // handle typed error
  FutureOr<void> Function()? afterError,           // runs on ANY error, before mapError
  bool isRetryable = true,                         // unknown errors get a Retryable handle
  bool skipIfInProgress = false,                   // silently skip if already running
})
```

The when/why, error-handling strategy, and cross-hook patterns live in [async-patterns.md](./async-patterns.md).

### usePaginatedComputedState

**Your default "cursor-paginated download" hook.** Handles the full lifecycle of a paginated list: first-page auto-load, `loadMore`, pull-to-refresh, keys-triggered refresh, debouncing, deduplication, cancellation. Pairs with `PaginatedComputedStateWrapper` for infinite scroll + pull-to-refresh. Full coverage in [paginated.md](./paginated.md).

```dart
final usersState = usePaginatedComputedState<User, String?>(
  initialCursor: null,
  (token) async {
    final response = await api.getUsers(pageToken: token);
    return PaginatedPage(items: response.items, nextCursor: response.nextPageToken);
  },
  keys: [query],                    // refresh on query change (items stay visible)
  debounceDuration: const Duration(milliseconds: 300),  // debounce the first-page load after keys change
  deduplicateBy: (u) => u.id,       // drop items whose id already appears
);

usersState.items                         // List<T>? - null until first successful load
usersState.hasMore / usersState.isLoading / usersState.error
usersState.loadMore() / usersState.refresh({bool clearCache = false}) / usersState.clear()
```

Cursor `C` is opaque - use `int` for offset/page or `String?` (nullable) for opaque tokens. See [paginated.md](./paginated.md) for the three cursor schemes and the optimistic-overlay pattern.

### usePersistedState

Syncs local state with persistent storage (SharedPreferences, Hive, etc.). `get` and `set` are positional parameters:

```dart
final themePreferenceState = usePersistedState<ThemeMode>(
  () async => prefs.getThemeMode(),           // get
  (value) async => prefs.setThemeMode(value), // set - value is ThemeMode?, null means "clear"
);

themePreferenceState.isInitialized   // false until the first get completes
themePreferenceState.isSynchronized  // false while a save is in flight
themePreferenceState.value           // T? - null before first load and when storage is empty
themePreferenceState.value = ThemeMode.dark;  // updates immediately, persists via set in the background
```

Signature:

```dart
PersistedState<T> usePersistedState<T extends Object>(
  Future<T?> Function() get,
  Future<void> Function(T? value) set, {
  bool canGet = true,                // gate the initial load (e.g. until a prerequisite is ready)
  HookKeys getKeys = hookKeysEmpty,  // re-run get when these change
});
```

`PersistedState<T>` implements `MutableValue<T?>` - the value is nullable: `null` before the first load and when nothing is stored. For the cache-then-network wiring (persisted cache + computed-state refresh), see the offline/cache section in [async-patterns.md](./async-patterns.md).

### usePreferencesPersistedState (requires utopia_arch - optional)

Convenience wrapper that combines `usePersistedState` with `PreferencesService` (SharedPreferences).
Only available if `utopia_arch` is added as a dependency - not required for core utopia_hooks usage.

```dart
// Simple types (String, int, double, bool)
final localeState = usePreferencesPersistedState<String>('locale', defaultValue: 'en');

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
- `.value` - current field value (read/write via `MutableValue<T>`)
- `.errorMessage` - validation error (type `ValidatorResult?` = `String Function(BuildContext)?`)
- `.hasError` - convenience getter
- `.validate(validator)` - runs validator and sets `.errorMessage`

```dart
final emailState = useFieldState(initialValue: user?.email ?? '');
final ageState = useGenericFieldState<int>(initialValue: 0);

// Validate manually
emailState.errorMessage = isValidEmail(emailState.value) ? null : (context) => 'Invalid email';

// Or use .validate() with a Validator<T>
emailState.validate((value) => isValidEmail(value) ? null : (context) => 'Invalid email');

// In View - error displayed automatically
CrazyTextField(state: state.email, label: const Text("Email"))
```

### useSubmitButtonState

Shorthand for submit + button wired together. Unlike a bare `useSubmitState`, the returned button's `onTap` DOES guard against duplicate taps - it returns early while `inProgress`:

```dart
final saveButton = useSubmitButtonState(
  () async => service.save(data),
  enabled: nameState.value.isNotEmpty,
);

// saveButton is a ButtonState - pass directly to button
CrazySquashButton.withState(state: saveButton, child: const Text("Save"))
```

---

## 6. Global State Access

### useProvided\<T\>

Reads global state registered in `_providers`. Only valid in State hooks.

```dart
// ❌ In View
class TasksScreenView extends StatelessWidget {
  Widget build(BuildContext context) {
    final auth = useProvided<AuthState>(); // WRONG
  }
}

// ✅ In State hook only
TasksScreenState useTasksScreenState() {
  final auth = useProvided<AuthState>();
  final tasks = useProvided<TasksState>();
  // ...
}
```

### useInjected\<T\>

Gets a service from your DI container. Only valid in State hooks (screen or global), never in View or Screen. Full setup and service-type conventions in [di-services.md](./di-services.md).

```dart
// In a state hook
final taskService = useInjected<TaskService>();
final analytics = useInjected<AnalyticsService>();
```

If you use `utopia_arch`, this hook is shipped for you - `T useInjected<T>() => useProvided<Injector>().get()` resolves from the provided `utopia_injector` container. Without `utopia_arch`, it's a one-liner bridge you write yourself over your project's DI:

```dart
// lib/hooks/use_injected.dart (get_it fallback)
T useInjected<T extends Object>() => GetIt.I<T>();
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
// details is T? - null when condition is false

// Run hooks only when value is non-null
useIfNotNull(memberId, (id) => useEnsureRoomMember(id, onNotPresent: () => memberIdState.value = null));
```

### useKeyed

Re-runs the block (creating fresh hook state) when keys change:

```dart
// Fresh hook state whenever userId changes
final userHooks = useKeyed([userId], () {
  final profileState = useAutoComputedState(() => service.load(userId));
  return profileState;
});
```

### useMap

Runs a hook for each key in a `Set`. Keys can change dynamically.

```dart
// ❌ Hook inside loop - breaks ordering
for (final id in courseIds) {
  final dataState = useAutoComputedState(() => load(id), keys: [id]); // WRONG
}

// ✅ useMap - one hook instance per key, stable across rebuilds
final courseStates = useMap(
  courseIds.toSet(),
  (id) => useAutoComputedState(() => courseService.load(id), keys: [id]),
);
```

State survives key set changes - existing keys keep their state, new keys start fresh, removed keys are disposed.

---

## 8. Flutter Controllers

Auto-created and auto-disposed.

### useAnimationController

```dart
final controller = useAnimationController(
  duration: const Duration(milliseconds: 300),
  initialValue: 0,
);

controller.forward();
```

Staggered animations - the `staggered` extension method on `AnimationController` maps one `Tween` onto a sub-interval of the controller; call it once per animation:

```dart
// Animation<T> staggered<T>({required Tween<T> tween, double start = 0.0, double end = 1.0, Curve curve})
final controller = useAnimationController(duration: const Duration(milliseconds: 400));
final fade = controller.staggered(tween: Tween(begin: 0.0, end: 1.0), start: 0.0, end: 0.6);
final slide = controller.staggered(
  tween: Tween(begin: const Offset(0, 0.1), end: Offset.zero),
  start: 0.3,
  end: 1.0,
  curve: Curves.easeOut,
);

controller.forward();
FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: content))
```

### useFocusNode / useScrollController

Lifecycle-managed `FocusNode` and `ScrollController`. Exported from `utopia_hooks` (and re-exported by `utopia_arch`).

```dart
final focus = useFocusNode(debugLabel: 'email');
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

### useListenableListener / useValueListenableListener

Side-effect on change (no rebuild). Pick the variant matching your source type:

- `useListenableListener(Listenable?, void Function())` - any `Listenable` (e.g. `ScrollController`, which carries no single value)
- `useValueListenableListener<T>(ValueListenable<T>?, void Function(T))` - Flutter `ValueListenable`/`ValueNotifier`
- `useListenableValueListener<T>(ListenableValue<T>?, void Function(T))` - utopia's `ListenableValue` (e.g. a `useState` result)

```dart
// Listenable without a value - read what you need inside the callback
useListenableListener(scrollController, () {
  if (scrollController.offset > threshold) showFloatingButton.value = true;
});

// ValueListenable - the callback receives the current value
final query = useMemoized(() => ValueNotifier(''), [], (it) => it.dispose());
useValueListenableListener(query, (value) => analytics.logSearch(value));
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

Returns last non-null value - the packaged fix for refresh blink (content flashing away while a computed state reloads):

```dart
// Without: content disappears while refreshing
final dataState = useAutoComputedState(() => service.load(id), keys: [id]);
final display = dataState.valueOrNull; // null during refresh = blank screen

// With usePreviousIfNull: old content stays visible during refresh
final display = usePreviousIfNull(dataState.valueOrNull);
```

For the full sticky-value pattern (including the View-side `keepInProgress` alternative), see [async-patterns.md](./async-patterns.md).

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

Conditional `useMemoized` - returns null when condition is false:

```dart
final details = useMemoizedIf(isExpanded, () => computeDetails(item), [item]);
// details is T? - null when isExpanded == false
```

### useCombinedInitializationState

Wait for multiple global states to all be initialized:

```dart
final allReady = useCombinedInitializationState({AuthState, CoursesState, ProfileState});
if (!allReady.isInitialized) return const SplashScreen();
```

---

## Common Pitfalls

- **Calling hooks conditionally** - `if (x) useState(...)` breaks hook ordering; use `useIf` instead
- **Calling hooks in loops** - use `useMap` instead
- **useState for derived values** - if computable from other state, use `useMemoized`
- **Cascading useEffects** - effect A → sets state B → triggers effect B → ...; redesign with `useMemoized`
- **useProvided / useInjected in View** - `StatelessWidget` is not a hook context
- **Assuming `useSubmitState` blocks duplicate runs** - it only counts them; gate with `useSubmitButtonState`, a `loading`-respecting button via `toButtonState()`, or `runSimple(skipIfInProgress: true)`

## Related Skills

- [screen-state-view.md](./screen-state-view.md) - where hooks live (State hook)
- [global-state.md](./global-state.md) - global state registration and useProvided
- [async-patterns.md](./async-patterns.md) - useSubmitState and useAutoComputedState in depth
- [error-handling.md](./error-handling.md) - where uncaught errors land, Retryable mechanics, the app-level retry dialog
- [paginated.md](./paginated.md) - `usePaginatedComputedState` + `PaginatedComputedStateWrapper`, cursor schemes, optimistic overlays
- [composable-hooks.md](./composable-hooks.md) - useMap and useIf in widget-level hooks
- [testing.md](./testing.md) - testing hooks with SimpleHookContext
