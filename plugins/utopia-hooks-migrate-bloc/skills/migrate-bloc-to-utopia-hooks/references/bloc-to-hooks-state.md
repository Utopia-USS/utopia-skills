---
title: "BLoC → Hooks: State & Data Flow Mapping"
impact: CRITICAL
tags: bloc, cubit, migration, mapping, side-by-side, emit, BlocBuilder, BlocListener
---

# BLoC → utopia_hooks: Pattern-by-Pattern Mapping

Every BLoC/Cubit concept has a direct hooks equivalent. This file provides side-by-side
code examples for each pattern. For the target hook contracts themselves, see `utopia-hooks:references/`.

This file covers state-layer constructs (Cubit/Bloc classes, events, context.read, Status enums, persistence, global mutable state). For widget-layer constructs (BlocBuilder, BlocListener, BlocConsumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver), see [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md).

---

## 1. Cubit → State class + hook

The most common migration. A Cubit class (state + methods) becomes a State class (data) + hook (logic).

### BLoC

```dart
class TaskListCubit extends Cubit<TaskListState> {
  final TaskRepository _repository;

  TaskListCubit(this._repository) : super(const TaskListState.loading());

  Future<void> loadTasks() async {
    emit(const TaskListState.loading());
    try {
      final tasks = await _repository.getAll();
      emit(TaskListState.loaded(tasks));
    } catch (e) {
      emit(TaskListState.error(e.toString()));
    }
  }

  void deleteTask(String id) async {
    await _repository.delete(id);
    loadTasks(); // reload
  }
}

@freezed
class TaskListState with _$TaskListState {
  const factory TaskListState.loading() = _Loading;
  const factory TaskListState.loaded(List<Task> tasks) = _Loaded;
  const factory TaskListState.error(String message) = _Error;
}
```

### utopia_hooks

```dart
class TaskListScreenState {
  final IList<Task>? tasks;        // null = loading (no union type needed)
  final bool isDeleting;
  final void Function(TaskId) onDeletePressed;

  const TaskListScreenState({
    required this.tasks,
    required this.isDeleting,
    required this.onDeletePressed,
  });
}

TaskListScreenState useTaskListScreenState() {
  final repository = useInjected<TaskRepository>();

  final tasksState = useAutoComputedState(
    () async => (await repository.getAll()).toIList(),
  );

  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async {
      await repository.delete(id);
      await tasksState.refresh();
    },
  );

  return TaskListScreenState(
    tasks: tasksState.valueOrNull,
    isDeleting: deleteState.inProgress,
    onDeletePressed: deleteTask,
  );
}
```

**What changed (BLoC → hooks mapping):**
- `Cubit` class → `useXxxScreenState()` function
- `emit(state)` → direct `useState` / `useAutoComputedState` assignment
- Freezed union `loading | loaded | error` → nullable `tasks` field (`null` = loading)
- `_repository` constructor field → `useInjected<TaskRepository>()`
- Cubit `close()` disposal → automatic hook cleanup

**What MUST be eliminated (not carried over):**
- `copyWith()` - hooks use individual `useState` per field, not immutable state objects
- `Equatable` / `props` - hooks don't do equality-based rebuild
- `Status` enum - use nullable `T?` for loading and `bool` flags for actions (see section 5)
- File name `_cubit.dart` / `_bloc.dart` - rename to `_state.dart`

---

## 2. Bloc with Events → hook with callbacks

A Bloc with typed events becomes a hook with plain functions. Event classes are eliminated.

### BLoC

```dart
// Events
abstract class AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email, password;
  LoginRequested(this.email, this.password);
}
class LogoutRequested extends AuthEvent {}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepo;

  AuthBloc(this._authRepo) : super(const AuthState.unauthenticated()) {
    on<LoginRequested>(_onLogin);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());
    try {
      final user = await _authRepo.login(event.email, event.password);
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await _authRepo.logout();
    emit(const AuthState.unauthenticated());
  }
}
```

### utopia_hooks

```dart
LoginScreenState useLoginScreenState({
  required void Function() navigateToHome,
  required void Function(String) showError,
}) {
  final authRepo = useInjected<AuthRepository>();
  final emailState = useFieldState();
  final passwordState = useFieldState();
  final loginState = useSubmitState();

  void login() => loginState.runSimple<void, AppError>(
    submit: () async => authRepo.login(emailState.value, passwordState.value),
    afterSubmit: (_) => navigateToHome(),
    mapError: (e) => e is AppError ? e : null,
    afterKnownError: (e) => showError(e.message),
  );

  void logout() => authRepo.logout();

  return LoginScreenState(
    email: emailState,
    password: passwordState,
    isLoggingIn: loginState.inProgress,
    loginButton: loginState.toButtonState(
      enabled: emailState.value.isNotEmpty && passwordState.value.isNotEmpty,
      onTap: login,
    ),
    onLogout: logout,
  );
}
```

**What changed (BLoC → hooks mapping):**
- `AuthEvent` classes → plain functions (`login()`, `logout()`)
- `on<Event>(_handler)` registration → just define the function
- `Emitter<AuthState> emit` → `useSubmitState` manages loading/error automatically
- Typed error handling via `mapError` + `afterKnownError` instead of try/catch + emit

See `utopia-hooks:references/async-patterns.md` for the full `useSubmitState` contract.

---

## 3. context.read / context.watch → useProvided

### BLoC

```dart
// Read (one-shot, no rebuild)
final cubit = context.read<TaskListCubit>();
cubit.deleteTask(taskId);

// Watch (reactive, triggers rebuild)
final state = context.watch<TaskListCubit>().state;
Text('${state.tasks.length} tasks');

// Select (derived value, granular rebuild)
final count = context.select<TaskListCubit, int>((c) => c.state.tasks.length);
```

### utopia_hooks

```dart
// In state hook - always reactive (no read/watch distinction)
final tasksState = useProvided<TaskListState>();

// For derived values - useMemoized instead of context.select
final count = useMemoized(() => tasksState.tasks?.length ?? 0, [tasksState.tasks]);
```

**What changed (BLoC → hooks mapping):**
- `context.read` and `context.watch` → both become `useProvided<T>()` (always reactive)
- `context.select` → `useMemoized` with keys

See `utopia-hooks:references/global-state.md` for `useProvided` semantics.

---

## 4. Freezed BLoC States → Flat State Class

### BLoC

```dart
@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading() = _Loading;
  const factory ProfileState.loaded(UserProfile profile) = _Loaded;
  const factory ProfileState.saving() = _Saving;
  const factory ProfileState.error(String message) = _Error;
}

// Usage in BlocBuilder
state.when(
  initial: () => const SizedBox.shrink(),
  loading: () => const CircularProgressIndicator(),
  loaded: (profile) => ProfileView(profile: profile),
  saving: () => const CircularProgressIndicator(),
  error: (msg) => Text(msg),
);
```

### utopia_hooks

```dart
class ProfileScreenState {
  final UserProfile? profile;     // null = loading or not loaded
  final bool isSaving;

  const ProfileScreenState({
    required this.profile,
    required this.isSaving,
  });
}

// Usage in View
Widget build(BuildContext context) {
  if (state.profile == null) return const CrazyLoader();
  if (state.isSaving) return const CrazyLoader();
  return _buildProfile(state.profile!);
}
```

**What changed (BLoC → hooks mapping):**
- Freezed union with 5 variants → flat class with 2 fields (`T? profile`, `bool isSaving`)
- `state.when(loading:, loaded:, error:, ...)` → null checks and bool flags
- Error handling moves to the hook (`afterKnownError`), not onto the state class

**Why:** Freezed union states explode combinatorially (loading + saving + error + loaded → 4+ variants). Hooks keep each concern independent.

---

## 5. Status Enum → Built-in Hook State Machines

BLoC `Status` enums (idle/loading/success/failure) map to hook built-in state tracking - don't recreate them.

### Download (read data) → useAutoComputedState

| BLoC Status | `ComputedStateValue` | What State class exposes |
|---|---|---|
| `Status.idle` / `initial` | `.notInitialized` | `T? data` (null) |
| `Status.loading` / `inProgress` | `.inProgress(operation)` | `!computed.isInitialized` |
| `Status.success` / `loaded` | `.ready(T)` | `T? data` via `.valueOrNull` |
| `Status.failure` / `error` | `.failed(exception)` | error callback or `.value.when(failed: ...)` |

```dart
// ❌ BLoC - manual Status tracking
class TaskListState extends Equatable {
  final Status status;
  final List<Task> tasks;
  TaskListState copyWith({Status? status, List<Task>? tasks}) => ...;
}

class TaskListCubit extends Cubit<TaskListState> {
  Future<void> loadTasks() async {
    emit(state.copyWith(status: Status.loading));
    final tasks = await repo.getAll();
    emit(state.copyWith(status: Status.success, tasks: tasks));
  }
}

// ✅ Hooks - ComputedStateValue handles all states
class TaskListScreenState {
  final IList<Task>? tasks;  // null = loading, non-null = loaded
  // No Status enum. No copyWith. No Equatable.
}

TaskListScreenState useTaskListScreenState() {
  final repo = useInjected<TaskRepository>();
  final tasksState = useAutoComputedState(() async => (await repo.getAll()).toIList());
  return TaskListScreenState(tasks: tasksState.valueOrNull);
}
```

### Upload (write/mutate) → useSubmitState

| BLoC Status | `submitState` | What State class exposes |
|---|---|---|
| `idle` | `!inProgress` | `bool isSaving` (false) |
| `inProgress` | `inProgress` | `bool isSaving` (true) |
| `success` | `afterSubmit` callback | callback runs, no state field |
| `failure` | `afterKnownError` callback | callback runs, no state field |

```dart
// ❌ BLoC
emit(state.copyWith(status: Status.loading));
await repo.save(data);
emit(state.copyWith(status: Status.success));

// ✅ Hooks
final saveState = useSubmitState();
void save() => saveState.runSimple<void, Never>(
  submit: () async => repo.save(data),
  afterSubmit: (_) => navigateBack(),
);
// State class: isSaving: saveState.inProgress
```

See `utopia-hooks:references/async-patterns.md` for the full `useAutoComputedState` / `useSubmitState` contracts.

---

## 6. HydratedCubit → usePersistedState

### BLoC

```dart
class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void updateTheme(ThemeMode mode) => emit(state.copyWith(themeMode: mode));

  @override
  SettingsState? fromJson(Map<String, dynamic> json) => SettingsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
```

### utopia_hooks

```dart
SettingsScreenState useSettingsScreenState() {
  final prefs = useInjected<PreferencesService>();

  final themeMode = usePersistedState<ThemeMode>(
    () async => prefs.load<ThemeMode>('themeMode'),
    (value) async => prefs.save('themeMode', value),
  );

  return SettingsScreenState(
    themeMode: themeMode.value ?? ThemeMode.system,
    onUpdateTheme: (mode) => themeMode.value = mode,
  );
}
```

**What changed (BLoC → hooks mapping):**
- `HydratedCubit` + `fromJson`/`toJson` → `usePersistedState(get, set)` - no serialization boilerplate
- `themeMode.isSynchronized` tells you if the value has been saved

**The same primitive applies WITHOUT HydratedCubit.** Any settings/preferences bloc whose
setters are thin persistence writes (via usecases, services, or a config DAO) maps to
per-setting `usePersistedState` or an optimistic snapshot field - NOT to a split
read-snapshot state plus a sibling setter-wrapper state. Pattern recognition greps,
target shapes, and the parity checklist: [settings-prefs-migration.md](./settings-prefs-migration.md).

---

## 7. Cubit Parameter → useProvided

If a hook takes a Cubit/Bloc as parameter, the migration is incomplete.

### BLoC

```dart
class FavCubit extends Cubit<FavState> {
  final AuthCubit _authCubit;
  FavCubit(this._authCubit) : super(const FavState());

  void loadFavorites() {
    final username = _authCubit.state.username;
    // ... load favorites for username
  }
}
```

### ❌ Half-migrated (Cubit as parameter)

```dart
FavState useFavState({required AuthCubit authCubit}) {
  final username = authCubit.state.username;  // still using Cubit API
  authCubit.stream.listen(...)                // still using BLoC stream
}
```

### ✅ Fully migrated (useProvided)

```dart
FavState useFavState() {
  final authState = useProvided<AuthState>();  // reactive, no Cubit
  final username = authState.username;

  final favs = useAutoComputedState(
    () async => favRepo.loadForUser(username),
    keys: [username],                           // auto-reloads when username changes
    shouldCompute: username.isNotEmpty,
  );
  // ...
}
```

**Rule:** If a hook takes a Cubit/Bloc parameter, migrate that Cubit to global state FIRST (see [global-state-migration.md](./global-state-migration.md)), then replace the parameter with `useProvided<XState>()`.

---

## 8. Global mutable state from Cubit

Cubits sometimes carry top-level mutable variables or `static` fields acting as cross-instance caches or singletons. These don't belong as top-level variables in hooks code.

### BLoC

```dart
// Top-level mutable state - shared across Cubit instances
final Map<int, CollapseState> _globalCollapseStates = {};
DateTime? _retryAfterDateTime;

class CommentsCubit extends Cubit<CommentsState> {
  void toggleCollapse(int id) {
    _globalCollapseStates[id] = /* ... */;
  }
}
```

### utopia_hooks

```dart
// Option A: registered service (app-wide state, not reactive)
class CollapseService {
  final _states = <int, CollapseState>{};
  CollapseState? getState(int id) => _states[id];
  void setState(int id, CollapseState state) => _states[id] = state;
}
// Accessed via useInjected<CollapseService>()

// Option B: global state via _providers (reactive, other screens react)
// See global-state-migration.md
```

**Rule:** Top-level mutable variables and `static` mutable fields from Cubits should become either a registered service (`useInjected`) or global state (via `_providers`). Never top-level `late` / mutable variables in hook files.

See `utopia-hooks:references/global-state.md` and `utopia-hooks:references/di-services.md`. For complex cases (multiple globals, caches, rate-limit state), see [complex-cubit-patterns.md](./complex-cubit-patterns.md) section 4.

---

## 9. bloc_concurrency transformers → what they become

The exit-gate greps ban `bloc_concurrency`, so every `transformer:` needs a conscious mapping.
Judge per handler and record the judgment; most delegating handlers need NOTHING because the
ordering was never observable.

| Transformer | When it actually mattered in the bloc | Hook-side mapping |
|---|---|---|
| `sequential()` | Only for handlers with real `await`s doing read-modify-write on shared in-memory state; a fully synchronous handler cannot interleave under ANY transformer | Usually nothing. If mutations genuinely must serialize, route them through one `useSubmitState` and await each `run` before UI can fire the next (note: submit runs do NOT queue - they run in parallel - so gate at the UI or chain the futures) |
| `droppable()` | Ignore events while one is processing | `useSubmitState` + `skipIfInProgress: true` for writes. CAUTION: this DROPS the repeat like droppable did - do not use it to emulate sequential queueing |
| `restartable()` | New event cancels the in-flight handler | keyed `useAutoComputedState` (a keys change cancels and re-runs), or `clear()` + `refresh()` on a manual computed state |
| `concurrent()` | Handlers were free to interleave | Default hook behavior; nothing to port |

Also: `refresh()` on computed states JOINS an in-flight compute rather than queueing a second
run - a repeated trigger during a compute is coalesced, which is droppable-like, not
sequential-like. If a per-trigger side effect must fire every time, keep it in the trigger
callback, outside the compute closure.

## 10. Throwing SYNC calls change blast radius

A synchronous throw inside a bloc event handler was contained by `Bloc.onError` (observer
logging, bloc goes on living). The same call moved into `useMemoized` or a hook body throws
DURING BUILD - and once the state is registered in `_providers`, that is an app-level build
error, not a screen-level one. When porting a sync call that can realistically throw
(parsing, `firstWhere`, map indexing on data-dependent keys), keep the error surface
equivalent: move the call inside the computed-state closure (failures become
`ComputedStateValue.failed` / zone-reported) or guard it explicitly. Do not silently upgrade
a contained per-event failure into a build crash.

## Common Pitfalls During Migration

- **Keeping BLoC state union types** - don't port the Freezed union; flatten to nullable fields + bools (section 4)
- **Creating a "HookCubit"** - don't wrap hooks in a class; the hook function IS the replacement for the Cubit class
- **Keeping `emit()` mental model** - there's no emit; `useState` is direct mutation, `useAutoComputedState` is automatic
- **Migrating one file at a time within a screen** - migrate the entire screen (Screen + State + View) at once
- **Leaving `flutter_bloc` as a dependency "just in case"** - remove it when all screens are migrated
- **Cascade trap (the #1 BLoC-brain mistake)** - In BLoC: event → handler → compute derived value → `emit(state.copyWith(derived: value))`. Naively translated to hooks: source changes → `useEffect` fires → writes to `useState` → triggers rebuild → repeat. Each `useEffect` → `useState` write is an extra rebuild frame. Three cascading effects = four rebuilds where one suffices. **Rule:** If a value is computable from other state, use `useMemoized` (runs synchronously during build, single rebuild). Only use `useEffect` for fire-and-forget side effects (analytics, stream subscriptions, external writes).

## Related

- [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) - widget-layer mapping (BlocBuilder/Listener/Consumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver)
- `utopia-hooks:references/screen-state-view.md` - full Screen/State/View pattern reference
- `utopia-hooks:references/hooks-reference.md` - complete hook catalog
- `utopia-hooks:references/async-patterns.md` - download/upload mental model, useSubmitState, useAutoComputedState, stream hooks
- `utopia-hooks:references/global-state.md` - `_providers`, `useProvided`, StateClass
- `utopia-hooks:references/di-services.md` - `useInjected`, service injection
- `utopia-hooks:references/flutter-conventions.md` - IList/IMap, TextEditingControllerWrapper
- [migration-steps.md](./migration-steps.md) - step-by-step migration checklist
- [global-state-migration.md](./global-state-migration.md) - provider tree migration
- [complex-cubit-patterns.md](./complex-cubit-patterns.md) - advanced stream/global patterns
