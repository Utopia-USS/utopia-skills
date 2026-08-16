---
title: Async Patterns
impact: HIGH
tags: async, useSubmitState, useAutoComputedState, usePaginatedComputedState, pagination, infinite-scroll, loading, error, forms, Retryable, retry, useEffect, timers, useStreamSubscription, usePersistedState, cache
---

# Skill: Async Patterns

Async operations in utopia_hooks follow a **download / upload / stream** mental model, plus a fourth shape for managed side effects:

| Direction | Hook | Trigger | Examples |
|-----------|------|---------|----------|
| **Download** (read, one-shot) | `useAutoComputedState` (manual-trigger variant: `useComputedState` - see [global-state.md](./global-state.md) when the service is late-initialized or callers need `force`) | Automatic (keys change) | Load screen data, fetch list, search results |
| **Download** (read, paginated) | `usePaginatedComputedState` | Automatic first page + `loadMore` | Feeds, paginated search, chat history - see [paginated.md](./paginated.md) |
| **Sync read** (no await anywhere) | `useMemoized` keyed on the inputs | Automatic (keys change) | Filter/sort an in-memory list, derive from a synchronous service call - a computed-state hook here manufactures an `inProgress` frame the operation never has |
| **Upload** (write) | `useSubmitState` | Manual (user action) | Save, delete, send, create - any mutation |
| **Stream** (reactive) | `useMemoizedStream` | Continuous | Real-time updates, auth state, live data |
| **Lifecycle effect** (side effect) | `useEffect` (+ `usePeriodicalSignal`) | Mount/unmount, keys change | Presence, heartbeats, wake locks, countdowns |

**Default rule:** reading one-shot → `useAutoComputedState`, reading paged → `usePaginatedComputedState`, synchronous read/derivation → `useMemoized`, writing → `useSubmitState`, reactive → `useMemoizedStream`, managed side effect → `useEffect` (see "Lifecycle effects" below).

`useSubmitState` note: expose `inProgress` (or a `ButtonState`) only when some UI actually renders a busy state; a migrated hook whose original had no busy flag should keep the submit state internal rather than invent surface.

## Why these hooks - the anti-pattern

**Incorrect (manual loading flag):**
```dart
final isLoadingState = useState(false);
final errorState = useState<String?>(null);

Future<void> submit() async {
  isLoadingState.value = true;
  errorState.value = null;
  try {
    await service.save(data);
    navigateBack();
  } catch (e) {
    errorState.value = e.toString();
  } finally {
    isLoadingState.value = false;
  }
}
```

For canonical signatures of `useSubmitState` / `useAutoComputedState` / `useMemoizedStream`, see [hooks-reference.md](./hooks-reference.md) §3-4. This file covers the **deep context** - when/why, error-handling strategy, and cross-hook patterns.

---

## useSubmitState - deep context

The go-to hook for any write/mutation operation. Manages the full lifecycle: idle → in progress → success/error.

Built-in behavior:
- **In-flight tracking, not blocking** - `run` counts in-flight runs (`inProgress` is `true` while the count > 0). Calling `run`/`runSimple` again while one is in flight starts a second, parallel run - duplicates are NOT blocked; gate them explicitly (see "Guarding duplicate submissions" below)
- **Unhandled errors crash by default** - don't swallow exceptions; only use `mapError`/`afterKnownError` when you have specific error UX (e.g. showing a field error for a known API error)
- **Retry support** - `run` wraps thrown errors with `Retryable` by default (`isRetryable: true`); see "Retryable errors" below

### Guarding duplicate submissions

`run` does not block duplicate calls by itself. Three legitimate guards:

```dart
// 1. The standard path for buttons: useSubmitButtonState / toButtonState.
//    useSubmitButtonState's onTap returns early while inProgress;
//    toButtonState() sets loading: inProgress so the design-system button
//    ignores taps while a submit is running.
final saveButtonState = useSubmitButtonState(() => service.save(data));

// 2. runSimple with skipIfInProgress (default is false):
void save() => saveState.runSimple<void, Never>(
  submit: () async => service.save(data),
  skipIfInProgress: true,   // silently skips when already running
);

// 3. Manual check, for non-button triggers:
void onTrigger() {
  if (saveState.inProgress) return;
  unawaited(saveState.run(() => service.save(data)));
}
```

### runSimple - the params this file teaches

Full signature lives in [hooks-reference.md](./hooks-reference.md) §4 (`useSubmitState`). The three this file leans on:
`shouldSubmit` (pre-check, return false to abort - the validation gate, see "Form Validation" below),
`mapError` (raw error → typed `E`, null = unknown/rethrow), and `afterKnownError` (handle the typed error).

### Error-handling strategy - let errors crash by default

Add `mapError` / `afterKnownError` **only** when you have specific error UX to show the user. Without that UX, there's no value in swallowing - the unhandled error should surface to the error boundary / crash reporter.

```dart
void save() => saveState.runSimple<SaveResult, SaveError>(
  submit: () async => service.saveItem(data),
  afterSubmit: (_) => navigateBack(),
  mapError: (e) => e is SaveError ? e : null,   // known error → typed
  afterKnownError: (e) => showSnackbar(e.message), // show to user
  // unknown errors still crash - that's correct
);
```

Before reaching for `try/catch` at all, check whether a hook already carries the error path
for you: `useSubmitState` (`mapError` / `afterKnownError` / `afterError`), `useAutoComputedState`
(the failure lands inside `.value` as `ComputedStateValue.failed` - render it with
`state.value.maybeWhen(failed: ..., orElse: ...)`; a keys change re-runs the compute),
`useMemoizedStream` (`AsyncSnapshot.hasError`).
Hand-rolled `try/catch` is the third choice, not the first - it adds complexity and is
swallowing-prone in exactly the way the hooks aren't.

When you do need a bare `try/catch` (`useEffect` launching a `Future`, `Timer.periodic`
callbacks, manual `unawaited(...)`) the same let-it-crash rule still applies. `catch (_)` with a
one-line prose excuse is the anti-pattern: a network-blip comment looks plausible, but the same
`catch` also buries parse errors, null derefs, and contract changes.

```dart
// ❌ Anonymous catch-all: any bug is silently swallowed behind the "network blips" excuse
useEffect(() {
  Future<void>(() async {
    try {
      final verified = await authService.isEmailVerified();
      emailVerifiedState.setIfMounted(verified);
    } catch (_) {
      // Network blips - assume not verified so the user still gets a send.
    }
  });
  return null;
}, [...]);

// ✅ Narrow the catch to the case you actually mean; let everything else crash
useEffect(() {
  Future<void>(() async {
    try {
      final verified = await authService.isEmailVerified();
      emailVerifiedState.setIfMounted(verified);
    } on NetworkException catch (e) {
      // documented fallback for the one case we tolerate; setIfMounted stays false.
      // Still report it as a warning - an expected exception is not a silent one.
      appReporter.warning('email verification check failed', e: e);
    }
  });
  return null;
}, [...]);
```

Two rules: bind the exception (`catch (e)` over `catch (_)`), and narrow to a specific type
(`on FooException`) unless you genuinely want to handle every error. Comment-as-justification
next to a bare `catch (_)` is how real bugs get hidden behind plausible-looking prose.

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

// In View - button shows loading spinner automatically
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

### Multiple submit states - one per independent flow, not per button

Use **one `useSubmitState()` per independent user flow**. If multiple actions are mutually exclusive (user can only do one at a time), wrap them in a single submitState.

**Incorrect - one submitState per button (5 submitStates for mutually exclusive actions):**
```dart
final voteSubmitState = useSubmitState();
final nextRoundSubmitState = useSubmitState();
final showResultsSubmitState = useSubmitState();
final finishGameSubmitState = useSubmitState();
final leaveSubmitState = useSubmitState();
```

**Correct - group mutually exclusive actions under one submitState:**
```dart
// Host actions are mutually exclusive - one submitState
final hostSubmitState = useSubmitState();

void onHostAction(HostAction action) => hostSubmitState.run(() async {
  switch (action) {
    case HostAction.nextRound: await gameService.nextRound(...);
    case HostAction.showResults: await gameService.showResults(...);
    case HostAction.finishGame: await roomService.finishGame(...);
  }
});

// Vote is independent of host actions - separate submitState
final voteSubmitState = useSubmitState();

// Leave is independent - separate submitState (only if it can run in parallel with the above)
final leaveSubmitState = useSubmitState();
```

**When to use separate submitStates:**
- Operations that can genuinely run **in parallel** (e.g., user can vote while host advances round)
- Operations with **different error handling** needs

**When to share a submitState:**
- Mutually exclusive actions (user picks one, not multiple at once)
- Actions on the same entity (save/delete same item - user does one or the other)

---

## useAutoComputedState - deep context

Signature and basic usage are in [hooks-reference.md](./hooks-reference.md). The key gate: `shouldCompute` keeps the future from running with `null` inputs (`shouldCompute: authState.isInitialized && userId != null`); the bootstrap chains built on it live in [app-bootstrap.md](./app-bootstrap.md).

### Driving it manually - `refresh`, `updateValue`, `clear`

`useAutoComputedState` returns `MutableComputedState<T>`, not a read-only snapshot. Three mutators sit alongside the loaded value:

- `refresh()` - **joins an in-flight compute rather than always re-running**: if `value` is `inProgress` it awaits that computation; otherwise it starts a new one. Safe to call from several places without stacking requests. Corollary: per-trigger side effects (analytics, logging) must live in the callback that calls `refresh()`, never inside the compute closure - joined refreshes would silently swallow the repeats
- Ordering note for ported code: if the original handler awaited a side effect BEFORE exposing the new state (e.g. awaited analytics before emitting loaded), keep that ordering - put the awaited call inside the compute so the ready state still lands after it. Behavior preservation beats closure purity during a migration
- `updateValue(T value)` - set to `ready(value)` without re-fetching. Since utopia_hooks 0.4.x it CANCELS any in-flight compute before setting the value (verified in 0.4.26 `use_computed_state.dart`; the doc comment on `MutableComputedState.updateValue` confirms) - a racing read cannot overwrite your value. On older versions it did not cancel; check your resolved package if behavior matters
- `clear()` - reset to `notInitialized`; cancels any in-flight computation

```dart
final productState = useAutoComputedState(() => service.load(id), keys: [id]);

// After a save that returns the updated entity - no round-trip needed
void onSaved(Product updated) => productState.updateValue(updated);

// Local edit, reflect immediately then reconcile on next keys change
void onFieldEdited(Product edited) => productState.updateValue(edited);

// Log out - drop cached value
void onLogout() => productState.clear();
```

**Anti-pattern: parallel `useState` override for a computed state.** If you find yourself writing `useState<T?>` next to `useAutoComputedState<T>` to "override" the loaded value after a mutation or local edit, call `updateValue` on the computed state instead. Mirroring the value in a separate `useState` duplicates the source of truth and silently drifts from `refresh()` / keys-triggered reloads.

```dart
// ❌ Duplicated state - productOverrideState shadows productState
final productState = useAutoComputedState(() => service.load(id), keys: [id]);
final productOverrideState = useState<Product?>(null);
final current = productOverrideState.value ?? productState.valueOrNull;
void onEdited(Product p) => productOverrideState.value = p;

// ✅ Single source of truth
final productState = useAutoComputedState(() => service.load(id), keys: [id]);
final current = productState.valueOrNull;
void onEdited(Product p) => productState.updateValue(p);
```

The same applies to `useComputedState` - it returns the same `MutableComputedState<T>`.

### Anti-pattern: counter-as-trigger

Never bump a `useState<int>` to force a recompute - `MutableComputedState` already exposes `.refresh()`.

```dart
// ❌ Counter in keys carries no information, only "something happened"
final refreshTriggerState = useState(0);
final dataState = useAutoComputedState(
  () => repo.fetch(query),
  keys: [query, refreshTriggerState.value],
);
void onRefresh() => refreshTriggerState.value++;

// ✅ Imperative action → method call
final dataState = useAutoComputedState(() => repo.fetch(query), keys: [query]);
void onRefresh() => dataState.refresh();

// ✅ Reactive to real state → key on that state
useEffect(() { dataState.refresh(); related.refresh(); }, [user.id]);
```

**Rule:** imperative actions use method calls; reactive `keys` take real domain values. A `useState<int>` + `value++` + counter-in-keys is always one of those two wearing the wrong clothes - it hides fan-out in the reactivity graph and the first conditional in `onRefresh` forces a rewrite anyway. Applies to every `useState` used only to trigger an effect (`useEffect` + dummy key, `setState({})`-style rebuild bumps).

### useAutoComputedState vs useMemoizedStream vs usePaginatedComputedState

| | `useAutoComputedState` | `useMemoizedStream` | `usePaginatedComputedState` |
|---|---|---|---|
| Use for | One-shot `Future<T>` | Ongoing `Stream<T>` | Cursor-paginated list of `T` |
| Re-triggers on | `keys` change + `shouldCompute` | `keys` change (re-subscribes) | `keys` change (refresh), `loadMore()`, `refresh()` |
| Returns | `MutableComputedState<T>` | `AsyncSnapshot<T>` | `MutablePaginatedComputedState<T, C>` |
| Initialized when | future completes | `connectionState == active` | first page loaded successfully |

---

## Retryable errors

Errors thrown inside these hooks can carry a retry handle (`Retryable`):

- `useSubmitState.run` wraps thrown errors **by default** (`isRetryable: true`)
- `useComputedState` / `useAutoComputedState` opt in with `isRetryable: true` (default `false`)

The `Retryable` API, the per-hook defaults table, the caveats, and the full app-level pipeline (root error stream, "Try again" dialog, navigator wiring) live in [error-handling.md](./error-handling.md).

---

## usePaginatedComputedState - pointer

Cursor-paginated lists have their own deep-dive in [paginated.md](./paginated.md). The short version: `usePaginatedComputedState<T, C>(...)` covers first-page auto-load, in-flight dedup, cancellation, debouncing, and on-end pagination. Pair with `PaginatedComputedStateWrapper` for scroll + pull-to-refresh. Cursor `C` is opaque (`int` for offset/page, `String?` for token). Confirmed optimistic edits/deletes override the buffer with `updateValues(items, {cursor})` / `updateAt` / `deleteAt` (decrement the cursor on offset/page deletes); a render-time override layer is for transient/uncommitted UI state. `shouldCompute` gates only the automatic loads (first page + keys-triggered refresh) - unlike `useAutoComputedState` it does NOT clear items or cancel in-flight loads when `false` (opt in with `clearOnShouldComputeFalse: true`); see [paginated.md](./paginated.md).

---

## useMemoizedStream

Signature and snapshot reading are in [hooks-reference.md](./hooks-reference.md). The part worth internalizing: it takes a **stream factory** (`Stream<T>? Function()`), memoized on `keys` - not a stream instance - so re-subscription is a keys change, and returning `null` from the factory means "no subscription yet" (the gate used in [app-bootstrap.md](./app-bootstrap.md)).

### isInitialized pattern for global state

`HasInitialized` is defined in [global-state.md](./global-state.md#hasinitialized) - the pattern below is how stream-backed global state derives `isInitialized` from the snapshot's connection state:

```dart
class NotificationsState extends HasInitialized {
  final IList<Notification>? items;
  const NotificationsState({required super.isInitialized, required this.items});
}

NotificationsState useNotificationsState() {
  final snap = useMemoizedStream(() => notificationService.stream);
  return NotificationsState(
    isInitialized: snap.connectionState == ConnectionState.active,
    items: snap.data,
  );
}
```

---

## Lifecycle effects - the fourth shape

Not every async operation is a download, an upload, or a stream. The fourth shape is the **managed side effect**: a void hook whose whole purpose is keeping some external fact in sync with the screen's lifecycle - presence registration, heartbeats, wake locks, timers. The tool is `useEffect` with a cleanup, not a state hook.

**Do NOT model these with `useSubmitState`.** They are not user actions: there is no button, no spinner, no per-call error UX. A submit state wrapped around `enterRoom()` buys nothing and loses the guaranteed cleanup on unmount.

### Register / cleanup (presence)

```dart
void useRoomPresence(String roomId) {
  final service = useInjected<PresenceService>();

  useEffect(() {
    unawaited(service.enterRoom(roomId));
    return () => unawaited(service.leaveRoom(roomId));  // unmount or roomId change
  }, [roomId]);
}
```

### Periodic heartbeat

`usePeriodicalSignal({required Duration period, bool enabled = true})` returns an `int` that increments every `period`. Use it as an effect key to re-run work periodically - no manual `Timer` bookkeeping:

```dart
final signal = usePeriodicalSignal(period: const Duration(seconds: 30));

useEffect(() {
  unawaited(presenceService.sendHeartbeat(roomId));
  return null;
}, [signal, roomId]);
```

### Wake-lock style toggles

Effects keyed on a boolean turn an external resource on and off, with the cleanup as the off-switch:

```dart
useEffect(() {
  if (!isPlaying) return null;
  unawaited(wakeLockService.enable());
  return () => unawaited(wakeLockService.disable());
}, [isPlaying]);
```

### Countdown timer

No manual `Timer` bookkeeping and no per-tick mutation: derive `remaining` from a deadline,
let `usePeriodicalSignal` drive rebuilds. The deadline is the single source of truth - a tick
re-renders, it does not mutate a counter, so the value can never drift:

```dart
final deadline = useMemoized(() => DateTime.now().add(roundDuration), [roundId]);
final left = deadline.difference(DateTime.now());
final remaining = left.isNegative ? Duration.zero : left;
usePeriodicalSignal(period: const Duration(seconds: 1), enabled: !left.isNegative);  // ticks until zero, then stops
```

`useMemoized` keyed on `roundId` resets the deadline each round; the signal only triggers
rebuilds. Computing `remaining` from `DateTime.now()` beats decrementing a `useState` per tick:
no drift, no separate reset/decrement bookkeeping, no first-build off-by-one.

---

## Sticky values - refresh without UI blink

`refresh()` (or a keys change) puts a computed state back into `inProgress`, so `valueOrNull` returns `null` and a naive View blinks to its loader even though it showed perfectly good data a frame ago. Three tools:

**1. `usePreviousIfNull`** - remembers the last non-null value across a refresh:

```dart
final productState = useAutoComputedState(() => service.load(id), keys: [id]);
final visibleProduct = usePreviousIfNull(productState.valueOrNull);  // stays on screen during refresh
```

(`productState.useValueOrPrevious()` is the equivalent extension method on `ComputedState`.)

Both are backed by `usePreviousValue`, which is change-gated: it updates its stored previous
only when the incoming value CHANGES, so the last real value stays on screen across any number
of in-progress rebuilds, not just the first one. The deprecated `usePrevious` (unconditional)
would blink after one rebuild - do not substitute it.

**2. Refresh inside the submit run** - when the refresh is caused by a mutation, await it inside `run`/`runSimple` so the button spinner only ends when the data is fresh and the screen never renders a half-updated state:

```dart
void save() => saveState.runSimple<void, Never>(
  submit: () async {
    await service.update(edited);
    await Future.wait([productState.refresh(), relatedList.refresh()]);
  },
);
```

**3. `keepInProgress: true` on `ComputedStateWrapper`** - the View-side switch: while a refresh is in progress the wrapper keeps rendering the previous ready value instead of `inProgressBuilder`. See [hooks-reference.md](./hooks-reference.md) for the wrapper's parameters.

---

## Re-entrancy on stream handlers

`useStreamSubscription`'s `strategy` parameter controls what happens when events arrive while an async handler is still running - the three modes (`parallel` / `pause` / `drop`) are tabled in [hooks-reference.md](./hooks-reference.md). Handlers that must not stack - the classic case is an error dialog per event - use `drop`:

```dart
useStreamSubscription(
  errorStream,
  (error) async => showErrorDialog(error),    // awaits until the dialog is dismissed
  strategy: StreamSubscriptionStrategy.drop,  // a second error while it's open is dropped
);
```

When the re-entrant trigger is not a stream (a `Listenable` callback, an effect), no strategy parameter exists - use the 9-line manual guard:

```dart
final isHandlingState = useState(false, listen: false);

Future<void> onTrigger() async {
  if (isHandlingState.value) return;
  isHandlingState.value = true;
  try {
    await showConfirmationDialog();
  } finally {
    isHandlingState.value = false;
  }
}
```

---

## Cache-then-network

`usePersistedState` (local cache; signature in [hooks-reference.md](./hooks-reference.md)) composes with a computed state into a cache-then-network read: show the cached value immediately, refresh from the network, persist what came back.

```dart
ProfileState useProfileState() {
  final store = useInjected<KeyValueStore>();  // generic key-value store (SharedPreferences, Hive, ...)
  final api = useInjected<ProfileApi>();

  // Cache - read once on mount, persisted on every write
  final cachedState = usePersistedState<Profile>(
    () async => (await store.read('profile'))?.let(Profile.fromJson),
    (value) async =>
        value == null ? store.delete('profile') : store.write('profile', value.toJson()),
  );

  // Network - fires on mount; a failed fetch leaves the cache untouched
  final freshState = useAutoComputedState(api.fetchProfile, isRetryable: true);

  // Fresh data updates the cache (writing cachedState.value also persists it)
  useEffect(() {
    final value = freshState.valueOrNull;
    if (value != null) cachedState.value = value;
  }, [freshState.valueOrNull]);

  return ProfileState(
    profile: freshState.valueOrNull ?? cachedState.value,  // network wins; cache fills the gap
    isStale: !freshState.isInitialized,
    refresh: freshState.refresh,
  );
}
```

**`shouldCompute` is for logical prerequisites, not transient ability.** Gate the fetch on facts like "user id available" (`shouldCompute: userId != null`, with `userId` in `keys`) - flipping `shouldCompute` to `false` clears the computed state immediately. Connectivity is not a prerequisite: when offline, let the fetch fail and keep serving the cache; `isRetryable: true` gives the failure a free retry handle (see "Retryable errors" above).

---

## Form Validation Pattern

```dart
// State hook
final emailState = useFieldState(initialValue: user?.email ?? '');
final passwordState = useFieldState();
final submitState = useSubmitState();

// .validate() runs the validator, sets .errorMessage, and returns whether the field is valid.
// Validate by design lives on shouldSubmit: run every field, return false to abort the submit.
bool validate() => [
      emailState.validate((it) => isValidEmail(it) ? null : (context) => 'Invalid email'),
      passwordState.validate((it) => it.length >= 8 ? null : (context) => 'Minimum 8 characters'),
    ].every((it) => it);

void login() => submitState.runSimple<void, LoginApiException>(
      shouldSubmit: () => !submitState.inProgress && validate(),  // the gate
      beforeSubmit: () => passwordState.errorMessage = null,  // clear stale server errors
      submit: () async => authService.login(
        email: emailState.value,
        password: passwordState.value,
      ),
      afterSubmit: (_) => navigateToHome(),
      // Known backend errors → typed E (tryCast is from utopia_utils, re-exported)
      mapError: (e) => e.tryCast<LoginApiException>(),
      // Typed error → localized message on the right field
      afterKnownError: (e) => passwordState.errorMessage = switch (e.code) {
        LoginErrorCode.invalidCredentials => (context) => 'Incorrect email or password',
        LoginErrorCode.tooManyAttempts => (context) => 'Too many attempts - try again later',
      },
      // Anything else rethrows → global error pipeline (see error-handling.md)
    );

return LoginScreenState(
  email: emailState,
  password: passwordState,
  loginButtonState: submitState.toButtonState(onTap: login),
);

// View - just wire up state
CrazyTextField(state: state.email, label: const Text("Email"))
CrazyTextField(state: state.password, label: const Text("Password"), obscureText: true)
CrazySquashButton.withState(state: state.loginButtonState, child: const Text("Login"))
```

Two things to note:

- **Validation runs in `shouldSubmit`, not a separate gate.** `shouldSubmit` returns false → the submit aborts and the fields already carry their error messages. No manual `isFormValid()` helper, no pre-call `if (!valid) return` - the one gate is the callback. (`errorMessage` is a `ValidatorResult?`, a typedef for `String Function(BuildContext)?`: the message resolves at render time, so the state hook stays free of `BuildContext`.)
- **The expected/unexpected split:** errors `mapError` recognizes are handled locally as field errors; everything else rethrows out of `runSimple` and surfaces in the global error pipeline - see [error-handling.md](./error-handling.md).

---

## Common Pitfalls

- **Too many submitStates** - one per independent flow, not per button. See "Multiple submit states" section above.
- **Swallowing errors with catch-all mapError** - default is `Never` (let it crash). Only add `mapError`/`afterKnownError` when you have specific error UX for the user. Unhandled errors should crash, not get logged and ignored
- **Bare `catch (_)` in state hooks** - same anti-pattern outside `useSubmitState`/`useAutoComputedState`: a network-blip comment next to a catch-all silently buries parse errors, null derefs, contract changes. Bind the exception (`catch (e)`) and narrow to a specific type (`on FooException`); let everything else crash. See "Error-handling strategy" above
- **`useAutoComputedState` without `shouldCompute`** - if prerequisites (like `userId`) may be null, guard with `shouldCompute: userId != null` or the future will run with null
- **Parallel `useState<T?>` shadowing a computed state** - to set the loaded value manually (after a mutation, local edit, logout), call `computed.updateValue(v)` / `computed.clear()`. Mirroring it in a `useState` duplicates the source of truth and drifts from `refresh()`
- **Treating `.value` as the loaded data** - `.value` is a `ComputedStateValue<T>` sum type (`notInitialized` / `inProgress` / `ready` / `failed`) and never throws; read the data via `.valueOrNull`, or pattern-match with `.value.when(...)` / `.value.maybeWhen(...)`
- **Assuming `run` blocks duplicate calls** - it doesn't; it only counts in-flight runs. Gate duplicates with `useSubmitButtonState` (hook-level guard), `toButtonState()` + a `loading`-respecting button (widget-level), `runSimple(skipIfInProgress: true)`, or a manual `inProgress` check. See "Guarding duplicate submissions" above
- **Modeling lifecycle side effects with `useSubmitState`** - presence, heartbeats, wake locks, and timers are not user actions; use `useEffect` with a cleanup. See "Lifecycle effects" above
- **Using `useSubmitState` for streaming** - `useSubmitState` is for one-shot operations; use `useMemoizedStream` for ongoing streams
- **Hand-rolling pagination with `useState` + `useEffect`** - use `usePaginatedComputedState`; see [paginated.md](./paginated.md) for the full set of pagination-specific pitfalls.

## Related Skills

- [hooks-reference.md](./hooks-reference.md) - useSubmitState, useAutoComputedState, useMemoizedStream in context
- [paginated.md](./paginated.md) - `usePaginatedComputedState` + `PaginatedComputedStateWrapper` for cursor/page/token paginated lists
- [screen-state-view.md](./screen-state-view.md) - where async state is exposed (State class) and consumed (View)
- [global-state.md](./global-state.md) - HasInitialized for global async state
- [error-handling.md](./error-handling.md) - where uncaught errors land, the app-level Retryable dialog, reporting
