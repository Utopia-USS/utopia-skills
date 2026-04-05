---
title: Async Patterns
impact: HIGH
tags: async, useSubmitState, useAutoComputedState, loading, error, forms
---

# Skill: Async Patterns

Async operations in utopia_hooks follow a **download / upload** mental model:

| Direction | Hook | Trigger | Examples |
|-----------|------|---------|----------|
| **Download** (read) | `useAutoComputedState` | Automatic (keys change) | Load screen data, fetch list, search results |
| **Upload** (write) | `useSubmitState` | Manual (user action) | Save, delete, send, create — any mutation |
| **Stream** (reactive) | `useMemoizedStream` | Continuous | Real-time updates, auth state, live data |

**Default rule:** reading → `useAutoComputedState`, writing → `useSubmitState`, reactive → `useMemoizedStream`.

## Quick Pattern

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

**Correct (useSubmitState):**
```dart
final submitState = useSubmitState();

// Default: let errors crash. Don't swallow exceptions.
void submit() => submitState.runSimple<void, Never>(
  submit: () async => service.save(data),
  afterSubmit: (_) => navigateBack(),
);

// In State output:
isSaving: submitState.inProgress,
saveButtonState: submitState.toButtonState(enabled: isFormValid, onTap: submit),
```

---

## useSubmitState — your default "upload" hook

The go-to hook for any write/mutation operation. Manages the full lifecycle: idle → in progress → success/error.

Built-in protections:
- **Blocks duplicate requests** — while `inProgress`, calling `run`/`runSimple` again is a no-op; `skipIfInProgress: true` silently drops
- **Unhandled errors crash by default** — don't swallow exceptions; only use `mapError`/`afterKnownError` when you have specific error UX (e.g. showing a snackbar for a known API error)
- **Retry support** — `isRetryable` flag for recoverable failures

### runSimple

Full signature:
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

**Default — let errors crash:**
```dart
final saveState = useSubmitState();

void save() => saveState.runSimple<void, Never>(
  submit: () async => service.saveItem(data),
  afterSubmit: (_) => navigateBack(),
);
```

**With error handling — only when you have specific error UX:**
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

## useAutoComputedState — your default "download" hook

The go-to hook for any read/load operation. Computes an async value automatically, re-fetches when `keys` change.
Returns a state with `isInitialized`, `valueOrNull`, and `value`.

### Basic usage

```dart
// Load data once
final product = useAutoComputedState(
  () async => productService.load(productId),
);

// Re-load when productId changes
final product = useAutoComputedState(
  () async => productService.load(productId),
  keys: [productId],
);

// Only compute when a prerequisite is ready
final orderHistory = useAutoComputedState(
  () async => orderService.loadHistory(userId),
  keys: [userId],
  shouldCompute: authState.isInitialized && userId != null,
);
```

### Reading the result

```dart
product.isInitialized   // false while loading
product.valueOrNull     // null while loading, T after
product.value           // T, throws StateError if not initialized

// Typical usage in State hook
return ProductPageState(
  isLoading: !product.isInitialized,
  product: product.valueOrNull,
);
```

### Loading guard in View

```dart
// View pattern for optional data
Widget build(BuildContext context) {
  if (state.isLoading) return const CrazyLoader();
  if (state.product == null) return const EmptyState();
  return _buildContent(state.product!);
}
```

### useAutoComputedState vs useMemoizedStream

| | `useAutoComputedState` | `useMemoizedStream` |
|---|---|---|
| Use for | One-shot `Future<T>` | Ongoing `Stream<T>` |
| Re-triggers on | `keys` change + `shouldCompute` | `keys` change (re-subscribes) |
| Returns | `ComputedState<T>` | `AsyncSnapshot<T>` |
| Initialized when | future completes | `connectionState == active` |

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

return LoginPageState(
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

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useSubmitState, useAutoComputedState, useMemoizedStream in context
- [page-state-view.md](./page-state-view.md) — where async state is exposed (State class) and consumed (View)
- [global-state.md](./global-state.md) — HasInitialized for global async state
