---
title: BLoC → Hooks Pattern Mapping
impact: CRITICAL
tags: bloc, cubit, migration, mapping, side-by-side, emit, BlocBuilder, BlocListener
---

# BLoC → utopia_hooks: Pattern-by-Pattern Mapping

Every BLoC/Cubit concept has a direct hooks equivalent. This file provides side-by-side
code examples for each pattern. All hooks examples use correct Screen/State/View architecture.

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

  // Download: auto-loads on mount
  final tasksState = useAutoComputedState(
    () async => (await repository.getAll()).toIList(),
  );

  // Upload: user-triggered delete
  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async {
      await repository.delete(id);
      await tasksState.refresh(); // reload after delete
    },
  );

  return TaskListScreenState(
    tasks: tasksState.valueOrNull,
    isDeleting: deleteState.inProgress,
    onDeletePressed: deleteTask,
  );
}
```

**What changed:**
- `Cubit` class → `useTaskListScreenState()` function (no class to extend, no constructor)
- `emit(state)` → direct `useState` / `useAutoComputedState` (no immutable state copying)
- Freezed union `loading | loaded | error` → nullable `tasks` field (`null` = loading)
- `_repository` field → `useInjected<TaskRepository>()`
- Disposal → automatic (hook cleanup)

**What MUST be eliminated (not carried over):**
- `copyWith()` — hooks use individual `useState` per field, not immutable state objects
- `Equatable` / `props` — not needed, hooks don't do equality-based rebuild
- `Status` enum — use nullable `T?` for loading and `bool` flags for actions
- File name `_cubit.dart` / `_bloc.dart` — rename to `_state.dart`

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
class LoginScreenState {
  final FieldState email;
  final FieldState password;
  final bool isLoggingIn;
  final ButtonState loginButton;
  final void Function() onLogout;

  const LoginScreenState({
    required this.email,
    required this.password,
    required this.isLoggingIn,
    required this.loginButton,
    required this.onLogout,
  });
}

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

**What changed:**
- `AuthEvent` classes → plain functions (`login()`, `logout()`)
- `on<Event>(_handler)` registration → just define the function
- `Emitter<AuthState> emit` → `useSubmitState` manages loading/error automatically
- Typed error handling via `mapError` + `afterKnownError` instead of try/catch + emit

---

## 3. BlocBuilder → View (StatelessWidget)

### BLoC

```dart
BlocBuilder<TaskListCubit, TaskListState>(
  builder: (context, state) {
    return state.when(
      loading: () => const CircularProgressIndicator(),
      loaded: (tasks) => ListView(
        children: tasks.map((t) => ListTile(title: Text(t.title))).toList(),
      ),
      error: (msg) => Text('Error: $msg'),
    );
  },
)
```

### utopia_hooks

```dart
class TaskListScreenView extends StatelessWidget {
  final TaskListScreenState state;
  const TaskListScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasks;
    if (tasks == null) return const CrazyLoader();
    return ListView(
      children: tasks.map((t) => ListTile(title: Text(t.title))).toList(),
    );
  }
}
```

**What changed:**
- `BlocBuilder<C, S>(builder:)` → `StatelessWidget` with `state` parameter
- `state.when(loading:, loaded:, error:)` → `if (state.tasks == null)` null check
- `context` access for BLoC → state is passed via constructor (no context needed)

---

## 4. BlocListener → useEffect / callback

### BLoC

```dart
BlocListener<AuthCubit, AuthState>(
  listenWhen: (prev, curr) => prev.isLoggedIn != curr.isLoggedIn,
  listener: (context, state) {
    if (!state.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  },
  child: /* ... */,
)
```

### utopia_hooks

```dart
// In the state hook — not in the widget tree
AuthScreenState useAuthScreenState({
  required void Function() navigateToLogin,
}) {
  final authState = useProvided<AuthState>();

  useEffect(() {
    if (authState.isInitialized && !authState.isLoggedIn) {
      navigateToLogin();
    }
    return null;
  }, [authState.isLoggedIn]);

  // ...
}
```

**What changed:**
- `BlocListener` widget in tree → `useEffect` in hook
- `listenWhen:` → `useEffect` keys array `[authState.isLoggedIn]`
- `Navigator.of(context)` → navigation callback injected from Screen
- Side effect is in the hook (logic layer), not in the widget tree (UI layer)

---

## 5. BlocConsumer → Screen + View

### BLoC

```dart
class CheckoutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order placed!')),
          );
        }
      },
      builder: (context, state) {
        return Column(children: [
          Text('Total: ${state.total}'),
          ElevatedButton(
            onPressed: state.isSubmitting
                ? null
                : () => context.read<CheckoutCubit>().placeOrder(),
            child: const Text('Place Order'),
          ),
        ]);
      },
    );
  }
}
```

### utopia_hooks

```dart
// Screen — coordinator
class CheckoutPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useCheckoutScreenState(
      showSuccessSnackbar: () => CrazyInfoSnackbar.show(context, 'Order placed!'),
    );
    return CheckoutScreenView(state: state);
  }
}

// State hook — logic (listener + builder logic combined)
CheckoutScreenState useCheckoutScreenState({
  required void Function() showSuccessSnackbar,
}) {
  final checkoutService = useInjected<CheckoutService>();
  final cartState = useProvided<CartState>();
  final submitState = useSubmitState();

  void placeOrder() => submitState.runSimple<void, Never>(
    submit: () async => checkoutService.placeOrder(cartState.items),
    afterSubmit: (_) => showSuccessSnackbar(),
  );

  return CheckoutScreenState(
    total: cartState.total,
    isSubmitting: submitState.inProgress,
    placeOrderButton: submitState.toButtonState(
      enabled: cartState.items.isNotEmpty,
      onTap: placeOrder,
    ),
  );
}

// View — pure UI
class CheckoutScreenView extends StatelessWidget {
  final CheckoutScreenState state;
  const CheckoutScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('Total: ${state.total}'),
      CrazySquashButton.withState(
        state: state.placeOrderButton,
        child: const Text('Place Order'),
      ),
    ]);
  }
}
```

**What changed:**
- `BlocConsumer` (listener + builder in one widget) → split into Screen (coordinator) + State hook (logic) + View (UI)
- `listener:` → `afterSubmit` callback in `runSimple`
- `builder:` → `StatelessWidget` View
- `context.read<Cubit>().method()` → callback in State class

---

## 6. context.read / context.watch → useProvided

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
// In state hook — always reactive (no read/watch distinction)
final tasksState = useProvided<TaskListState>();
// tasksState.tasks is always current, rebuilds automatically

// For derived values — useMemoized instead of context.select
final count = useMemoized(() => tasksState.tasks?.length ?? 0, [tasksState.tasks]);
```

**What changed:**
- `context.read` and `context.watch` → both become `useProvided<T>()`
- No distinction needed — hooks are always reactive
- `context.select` → `useMemoized` with keys (only recomputes when dependency changes)

---

## 7. Freezed BLoC States → Flat State Class

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

**What changed:**
- Freezed union type with 5 variants → flat class with 2 fields
- `state.when(loading:, loaded:, error:, ...)` → simple null checks and bool flags
- No code generation needed (no `.freezed.dart` for state)
- Error handling lives in the hook (`afterKnownError`), not in the state class

**Why this is better:**
- Freezed union states explode combinatorially (loading + saving + error + loaded = 4+ variants)
- In hooks, each concern is independent: `profile` is null/non-null, `isSaving` is bool, errors are handled in callbacks
- The View is simpler: `if (x == null)` vs `state.when(5 cases)`

---

## 8. buildWhen / listenWhen → useMemoized / useEffect with keys

### BLoC

```dart
BlocBuilder<SettingsCubit, SettingsState>(
  buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
  builder: (context, state) => ThemeWidget(mode: state.themeMode),
)

BlocListener<SettingsCubit, SettingsState>(
  listenWhen: (prev, curr) => prev.locale != curr.locale,
  listener: (context, state) => reloadTranslations(state.locale),
)
```

### utopia_hooks

```dart
// buildWhen equivalent — derived value with selective keys
final themeMode = useMemoized(() => settingsState.themeMode, [settingsState.themeMode]);

// listenWhen equivalent — effect with selective keys
useEffect(() {
  reloadTranslations(settingsState.locale);
  return null;
}, [settingsState.locale]);
```

**What changed:**
- `buildWhen` predicate → `useMemoized` keys (only recomputes when key changes)
- `listenWhen` predicate → `useEffect` keys (only runs when key changes)
- More granular — keys are explicit values, not comparison functions

---

## 9. Status Enum → Built-in Hook State Machines

Hooks have built-in state tracking. Don't recreate Status enums.

### Download (read data) → useAutoComputedState

`useAutoComputedState` returns `MutableComputedState<T>` which internally uses `ComputedStateValue`:

| BLoC Status | ComputedStateValue | What State class exposes |
|---|---|---|
| `Status.idle` / `initial` | `.notInitialized` | `T? data` (null) |
| `Status.loading` / `inProgress` | `.inProgress(operation)` | `!computed.isInitialized` |
| `Status.success` / `loaded` | `.ready(T)` | `T? data` (non-null via `.valueOrNull`) |
| `Status.failure` / `error` | `.failed(exception)` | handled by error callback or `.value.when(failed: ...)` |

```dart
// ❌ BLoC — manual Status tracking
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

// ✅ Hooks — ComputedStateValue handles all states
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

| BLoC Status | submitState | What State class exposes |
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

---

## 10. HydratedCubit → usePersistedState

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
class SettingsScreenState {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onUpdateTheme;
  const SettingsScreenState({required this.themeMode, required this.onUpdateTheme});
}

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

**What changed:**
- `HydratedCubit` + `fromJson`/`toJson` → `usePersistedState(get, set)`
- No manual serialization boilerplate — `usePersistedState` handles sync
- `themeMode.isSynchronized` tells you if the value has been saved

---

## 11. Cubit Parameter → useProvided

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
  final username = authState.username;          // direct field access

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

## 12. TextEditingController → useFieldState + TextEditingControllerWrapper

The most common form pattern in BLoC apps. **Never carry raw `TextEditingController` into hooks.**

### BLoC

```dart
class SubmitCubit extends Cubit<SubmitState> {
  SubmitCubit() : super(const SubmitState());

  void onTitleChanged(String value) => emit(state.copyWith(title: value));
  void onUrlChanged(String value) => emit(state.copyWith(url: value));
}

// In widget:
final controller = TextEditingController();

TextField(
  controller: controller,
  onChanged: context.read<SubmitCubit>().onTitleChanged,
)
```

### ❌ Wrong migration (raw controller + useState sync)

```dart
// This is BLoC-brain in hooks — DO NOT DO THIS
final controller = useMemoized(() => TextEditingController());
final title = useState('');
useEffect(() {
  void onChange() => title.value = controller.text;
  controller.addListener(onChange);
  return () { controller.removeListener(onChange); controller.dispose(); };
}, const []);
```

### ✅ Correct migration (useFieldState + TextEditingControllerWrapper)

```dart
// ── Hook ──
SubmitScreenState useSubmitScreenState() {
  final title = useFieldState();
  final url = useFieldState();
  final text = useFieldState();

  // Validation, submit logic, etc. uses title.value, url.value, text.value directly

  return SubmitScreenState(title: title, url: url, text: text, ...);
}

// ── State class ──
class SubmitScreenState {
  final MutableFieldState title;
  final MutableFieldState url;
  final MutableFieldState text;
  const SubmitScreenState({required this.title, required this.url, required this.text});

  bool get canSubmit => title.value.isNotEmpty && (url.value.isNotEmpty || text.value.isNotEmpty);
}

// ── View ── TextEditingControllerWrapper manages the controller
TextEditingControllerWrapper(
  text: state.title,
  builder: (controller) => TextField(
    controller: controller,
    decoration: const InputDecoration(hintText: 'Title'),
  ),
)
```

`TextEditingControllerWrapper` is a View-side widget that:
- Takes `MutableValue<String>` (from `useFieldState()`)
- Creates, syncs, and disposes a `TextEditingController` internally
- Bidirectional sync: typing updates state, programmatic state changes update the field

**With validation errors:**
```dart
TextEditingControllerWrapper(
  text: state.email,
  builder: (controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(controller: controller),
      if (state.email.errorMessage != null)
        Text(state.email.errorMessage!(context), style: TextStyle(color: Colors.red)),
    ],
  ),
)
```

**Rule:** Every `TextEditingController` in the old code becomes a `useFieldState()` in the hook + `TextEditingControllerWrapper` in the View. No exceptions.

---

## Common Pitfalls During Migration

- **Keeping BLoC state union types** — don't port the Freezed union; flatten to nullable fields + bools
- **Putting `useProvided` in View** — View is a StatelessWidget; state access stays in the hook
- **Creating a "HookCubit"** — don't wrap hooks in a class; the hook function IS the replacement for the Cubit class
- **Keeping `emit()` mental model** — there's no emit; `useState` is direct mutation, `useAutoComputedState` is automatic
- **Migrating one file at a time within a screen** — migrate the entire screen (Page + State + View) at once
- **Leaving `flutter_bloc` as a dependency "just in case"** — remove it when all screens are migrated
- **Using raw `TextEditingController` in hooks** — always use `useFieldState` + `TextEditingControllerWrapper`

## Related

- `../utopia-hooks/references/page-state-view.md` — full Screen/State/View pattern reference
- `../utopia-hooks/references/hooks-reference.md` — complete hook catalog
- `../utopia-hooks/references/async-patterns.md` — download/upload mental model
- [migration-steps.md](./migration-steps.md) — step-by-step migration checklist
- [global-state-migration.md](./global-state-migration.md) — provider tree migration
