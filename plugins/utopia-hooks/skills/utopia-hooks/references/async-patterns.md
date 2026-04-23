---
title: Async Patterns
impact: HIGH
tags: async, useSubmitState, useAutoComputedState, usePaginatedComputedState, pagination, infinite-scroll, loading, error, forms
---

# Skill: Async Patterns

Async operations in utopia_hooks follow a **download / upload** mental model:

| Direction | Hook | Trigger | Examples |
|-----------|------|---------|----------|
| **Download** (read, one-shot) | `useAutoComputedState` | Automatic (keys change) | Load screen data, fetch list, search results |
| **Download** (read, paginated) | `usePaginatedComputedState` | Automatic first page + `loadMore` | Feeds, paginated search, chat history — see [paginated.md](./paginated.md) |
| **Upload** (write) | `useSubmitState` | Manual (user action) | Save, delete, send, create — any mutation |
| **Stream** (reactive) | `useMemoizedStream` | Continuous | Real-time updates, auth state, live data |

**Default rule:** reading one-shot → `useAutoComputedState`, reading paged → `usePaginatedComputedState`, writing → `useSubmitState`, reactive → `useMemoizedStream`.

## Why these hooks — the anti-pattern

**Incorrect (manual loading flag):**
```dart
final isLoading = useState(false);
final error = useState<String?>(null);

Future<void> submit() async {
  isLoading.value = true;
  error.value = null;
  try {
    await service.save(data);
    navigateBack();
  } catch (e) {
    error.value = e.toString();
  } finally {
    isLoading.value = false;
  }
}
```

For canonical signatures of `useSubmitState` / `useAutoComputedState` / `useMemoizedStream`, see [hooks-reference.md](./hooks-reference.md) §3–4. This file covers the **deep context** — when/why, error-handling strategy, and cross-hook patterns.

---

## useSubmitState — deep context

The go-to hook for any write/mutation operation. Manages the full lifecycle: idle → in progress → success/error.

Built-in protections:
- **Blocks duplicate requests** — while `inProgress`, calling `run`/`runSimple` again is a no-op; `skipIfInProgress: true` silently drops
- **Unhandled errors crash by default** — don't swallow exceptions; only use `mapError`/`afterKnownError` when you have specific error UX (e.g. showing a snackbar for a known API error)
- **Retry support** — `isRetryable` flag for recoverable failures

### runSimple — full signature

```dart
Future<void> runSimple<T, E>({
  FutureOr<bool> Function()? shouldSubmit,       // pre-check, return false to abort
  FutureOr<void> Function()? beforeSubmit,        // runs before submit
  required Future<T> Function() submit,           // the async work
  FutureOr<void> Function(T)? afterSubmit,        // called on success with result
  FutureOr<E?> Function(Object)? mapError,        // convert raw error → typed E (null = unknown)
  FutureOr<void> Function(E)? afterKnownError,    // handle typed error
  FutureOr<void> Function()? afterError,          // handle any error (known or unknown)
  bool isRetryable = true,
  bool skipIfInProgress = false,                  // silently skip if already running
})
```

### Error-handling strategy — let errors crash by default

Add `mapError` / `afterKnownError` **only** when you have specific error UX to show the user. Without that UX, there's no value in swallowing — the unhandled error should surface to the error boundary / crash reporter.

```dart
void save() => saveState.runSimple<SaveResult, SaveError>(
  submit: () async => service.saveItem(data),
  afterSubmit: (_) => navigateBack(),
  mapError: (e) => e is SaveError ? e : null,   // known error → typed
  afterKnownError: (e) => showSnackbar(e.message), // show to user
  // unknown errors still crash — that's correct
);
```

### toButtonState

Converts `useSubmitState` into a `ButtonState` for `CrazySquashButton.withState`:

```dart
// In State class
final ButtonState saveButtonState;

// In State hook
saveButtonState: saveState.toButtonState(
  enabled: nameState.value.isNotEmpty && !saveState.inProgress,
  onTap: save,
),

// In View — button shows loading spinner automatically
CrazySquashButton.withState(
  state: state.saveButtonState,
  child: const Text("Save"),
)
```

### inProgress

```dart
// Show a loading indicator while saving
CrazyLoader(visible: saveState.inProgress)

// Disable other actions while submitting
onTap: saveState.inProgress ? null : onOtherAction,
```

### Multiple submit states — one per independent flow, not per button

Use **one `useSubmitState()` per independent user flow**. If multiple actions are mutually exclusive (user can only do one at a time), wrap them in a single submitState.

**Incorrect — one submitState per button (5 submitStates for mutually exclusive actions):**
```dart
final voteSubmitState = useSubmitState();
final nextRoundSubmitState = useSubmitState();
final showResultsSubmitState = useSubmitState();
final finishGameSubmitState = useSubmitState();
final leaveSubmitState = useSubmitState();
```

**Correct — group mutually exclusive actions under one submitState:**
```dart
// Host actions are mutually exclusive — one submitState
final hostSubmitState = useSubmitState();

void onHostAction(HostAction action) => hostSubmitState.run(() async {
  switch (action) {
    case HostAction.nextRound: await gameService.nextRound(...);
    case HostAction.showResults: await gameService.showResults(...);
    case HostAction.finishGame: await roomService.finishGame(...);
  }
});

// Vote is independent of host actions — separate submitState
final voteSubmitState = useSubmitState();

// Leave is independent — separate submitState (only if it can run in parallel with the above)
final leaveSubmitState = useSubmitState();
```

**When to use separate submitStates:**
- Operations that can genuinely run **in parallel** (e.g., user can vote while host advances round)
- Operations with **different error handling** needs

**When to share a submitState:**
- Mutually exclusive actions (user picks one, not multiple at once)
- Actions on the same entity (save/delete same item — user does one or the other)

---

## useAutoComputedState — deep context

`shouldCompute` is the key deep-dive — gate the load on prerequisites so the future doesn't run with `null` inputs:

```dart
final orderHistory = useAutoComputedState(
  () async => orderService.loadHistory(userId),
  keys: [userId],
  shouldCompute: authState.isInitialized && userId != null,
);
```

### Loading guard in View

```dart
Widget build(BuildContext context) {
  if (state.isLoading) return const CrazyLoader();
  if (state.product == null) return const EmptyState();
  return _buildContent(state.product!);
}
```

### Anti-pattern: counter-as-trigger

Never bump a `useState<int>` to force a recompute — `MutableComputedState` already exposes `.refresh()`.

```dart
// ❌ Counter in keys carries no information, only "something happened"
final refreshTrigger = useState(0);
final data = useAutoComputedState(
  () => repo.fetch(query),
  keys: [query, refreshTrigger.value],
);
void onRefresh() => refreshTrigger.value++;

// ✅ Imperative action → method call
final data = useAutoComputedState(() => repo.fetch(query), keys: [query]);
void onRefresh() => data.refresh();

// ✅ Reactive to real state → key on that state
useEffect(() { data.refresh(); related.refresh(); }, [user.id]);
```

**Rule:** imperative actions use method calls; reactive `keys` take real domain values. A `useState<int>` + `value++` + counter-in-keys is always one of those two wearing the wrong clothes — it hides fan-out in the reactivity graph and the first conditional in `onRefresh` forces a rewrite anyway. Applies to every `useState` used only to trigger an effect (`useEffect` + dummy key, `setState({})`-style rebuild bumps).

### useAutoComputedState vs useMemoizedStream vs usePaginatedComputedState

| | `useAutoComputedState` | `useMemoizedStream` | `usePaginatedComputedState` |
|---|---|---|---|
| Use for | One-shot `Future<T>` | Ongoing `Stream<T>` | Cursor-paginated list of `T` |
| Re-triggers on | `keys` change + `shouldCompute` | `keys` change (re-subscribes) | `keys` change (refresh), `loadMore()`, `refresh()` |
| Returns | `ComputedState<T>` | `AsyncSnapshot<T>` | `MutablePaginatedComputedState<T, C>` |
| Initialized when | future completes | `connectionState == active` | first page loaded successfully |

---

## usePaginatedComputedState — pointer

Cursor-paginated lists have their own deep-dive in [paginated.md](./paginated.md). The short version: `usePaginatedComputedState<T, C>(...)` covers first-page auto-load, in-flight dedup, cancellation, debouncing, and on-end pagination. Pair with `PaginatedComputedStateWrapper` for scroll + pull-to-refresh. Cursor `C` is opaque (`int` for offset/page, `String?` for token). Optimistic mutations go in a local override layer, not into `items`. Same `shouldCompute` contract as `useAutoComputedState`.

---

## useMemoizedStream

Subscribes to a `Stream<T>`. Builds `AsyncSnapshot<T>` — re-renders on every emitted value.

```dart
// Single stream
final notificationsSnap = useMemoizedStream(notificationService.stream);

// Re-subscribe when userId changes
final messagesSnap = useMemoizedStream(
  () => messageService.stream(userId),
  keys: [userId],
);

// Reading
final notifications = notificationsSnap.data;           // T? — null before first event
final isConnected = notificationsSnap.connectionState == ConnectionState.active;
final hasError = notificationsSnap.hasError;
```

### isInitialized pattern for global state

`HasInitialized` is defined in [global-state.md](./global-state.md#hasinitialized) — the pattern below is how stream-backed global state derives `isInitialized` from the snapshot's connection state:

```dart
class NotificationsState extends HasInitialized {
  final IList<Notification>? items;
  const NotificationsState({required super.isInitialized, required this.items});
}

NotificationsState useNotificationsState() {
  final snap = useMemoizedStream(notificationService.stream);
  return NotificationsState(
    isInitialized: snap.connectionState == ConnectionState.active,
    items: snap.data,
  );
}
```

---

## Form Validation Pattern

```dart
// State hook
final emailState = useFieldState(initialValue: user?.email ?? '');
final passwordState = useFieldState();
final submitState = useSubmitState();

bool get isFormValid =>
  !emailState.hasError &&
  !passwordState.hasError &&
  emailState.value.isNotEmpty &&
  passwordState.value.isNotEmpty;

void validateAndSubmit() {
  // .validate() runs validator and sets .errorMessage automatically
  emailState.validate((v) => isValidEmail(v) ? null : (context) => 'Invalid email');
  passwordState.validate((v) => v.length >= 8 ? null : (context) => 'Minimum 8 characters');

  if (!isFormValid) return;

  submitState.runSimple<void, AppError>(
    submit: () async => authService.login(
      email: emailState.value,
      password: passwordState.value,
    ),
    afterSubmit: (_) => navigateToHome(),
    mapError: (e) => e is AppError ? e : null,
    afterKnownError: (e) => showSnackbar(e.message),
  );
}

return LoginScreenState(
  email: emailState,
  password: passwordState,
  loginButtonState: submitState.toButtonState(
    enabled: isFormValid,
    onTap: validateAndSubmit,
  ),
);

// View — just wire up state
CrazyTextField(state: state.email, label: const Text("Email"))
CrazyTextField(state: state.password, label: const Text("Password"), obscureText: true)
CrazySquashButton.withState(state: state.loginButtonState, child: const Text("Login"))
```

---

## Common Pitfalls

- **Too many submitStates** — one per independent flow, not per button. See "Multiple submit states" section above.
- **Swallowing errors with catch-all mapError** — default is `Never` (let it crash). Only add `mapError`/`afterKnownError` when you have specific error UX for the user. Unhandled errors should crash, not get logged and ignored
- **`useAutoComputedState` without `shouldCompute`** — if prerequisites (like `userId`) may be null, guard with `shouldCompute: userId != null` or the future will run with null
- **Reading `.value` before `isInitialized`** — `.value` throws `StateError`; use `.valueOrNull` for safe access
- **Using `useSubmitState` for streaming** — `useSubmitState` is for one-shot operations; use `useMemoizedStream` for ongoing streams
- **Hand-rolling pagination with `useState` + `useEffect`** — use `usePaginatedComputedState`; see [paginated.md](./paginated.md) for the full set of pagination-specific pitfalls.

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useSubmitState, useAutoComputedState, useMemoizedStream in context
- [paginated.md](./paginated.md) — `usePaginatedComputedState` + `PaginatedComputedStateWrapper` for cursor/page/token paginated lists
- [screen-state-view.md](./screen-state-view.md) — where async state is exposed (State class) and consumed (View)
- [global-state.md](./global-state.md) — HasInitialized for global async state
