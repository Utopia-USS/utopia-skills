---
title: BLoC → Hooks Pattern Mapping
impact: CRITICAL
tags: bloc, cubit, migration, mapping, side-by-side, emit, BlocBuilder, BlocListener
---

# BLoC → utopia_hooks: Pattern-by-Pattern Mapping

Every BLoC/Cubit concept has a direct hooks equivalent. This file provides side-by-side
code examples for each pattern. All hooks examples use correct Page/State/View architecture.

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
class TaskListPageState {
  final IList<Task>? tasks;        // null = loading (no union type needed)
  final bool isDeleting;
  final void Function(TaskId) onDeletePressed;

  const TaskListPageState({
    required this.tasks,
    required this.isDeleting,
    required this.onDeletePressed,
  });
}

TaskListPageState useTaskListPageState() {
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

  return TaskListPageState(
    tasks: tasksState.valueOrNull,
    isDeleting: deleteState.inProgress,
    onDeletePressed: deleteTask,
  );
}
```

**What changed:**
- `Cubit` class → `useTaskListPageState()` function (no class to extend, no constructor)
- `emit(state)` → direct `useState` / `useAutoComputedState` (no immutable state copying)
- Freezed union `loading | loaded | error` → nullable `tasks` field (`null` = loading)
- `_repository` field → `useInjected<TaskRepository>()`
- Disposal → automatic (hook cleanup)

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
class LoginPageState {
  final FieldState email;
  final FieldState password;
  final bool isLoggingIn;
  final ButtonState loginButton;
  final void Function() onLogout;

  const LoginPageState({
    required this.email,
    required this.password,
    required this.isLoggingIn,
    required this.loginButton,
    required this.onLogout,
  });
}

LoginPageState useLoginPageState({
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

  return LoginPageState(
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
class TaskListPageView extends StatelessWidget {
  final TaskListPageState state;
  const TaskListPageView({required this.state});

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
AuthPageState useAuthPageState({
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
- `Navigator.of(context)` → navigation callback injected from Page
- Side effect is in the hook (logic layer), not in the widget tree (UI layer)

---

## 5. BlocConsumer → Page + View

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
// Page — coordinator
class CheckoutPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useCheckoutPageState(
      showSuccessSnackbar: () => CrazyInfoSnackbar.show(context, 'Order placed!'),
    );
    return CheckoutPageView(state: state);
  }
}

// State hook — logic (listener + builder logic combined)
CheckoutPageState useCheckoutPageState({
  required void Function() showSuccessSnackbar,
}) {
  final checkoutService = useInjected<CheckoutService>();
  final cartState = useProvided<CartState>();
  final submitState = useSubmitState();

  void placeOrder() => submitState.runSimple<void, Never>(
    submit: () async => checkoutService.placeOrder(cartState.items),
    afterSubmit: (_) => showSuccessSnackbar(),
  );

  return CheckoutPageState(
    total: cartState.total,
    isSubmitting: submitState.inProgress,
    placeOrderButton: submitState.toButtonState(
      enabled: cartState.items.isNotEmpty,
      onTap: placeOrder,
    ),
  );
}

// View — pure UI
class CheckoutPageView extends StatelessWidget {
  final CheckoutPageState state;
  const CheckoutPageView({required this.state});

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
- `BlocConsumer` (listener + builder in one widget) → split into Page (coordinator) + State hook (logic) + View (UI)
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
class ProfilePageState {
  final UserProfile? profile;     // null = loading or not loaded
  final bool isSaving;

  const ProfilePageState({
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

## Common Pitfalls During Migration

- **Keeping BLoC state union types** — don't port the Freezed union; flatten to nullable fields + bools
- **Putting `useProvided` in View** — View is a StatelessWidget; state access stays in the hook
- **Creating a "HookCubit"** — don't wrap hooks in a class; the hook function IS the replacement for the Cubit class
- **Keeping `emit()` mental model** — there's no emit; `useState` is direct mutation, `useAutoComputedState` is automatic
- **Migrating one file at a time within a screen** — migrate the entire screen (Page + State + View) at once
- **Leaving `flutter_bloc` as a dependency "just in case"** — remove it when all screens are migrated

## Related

- `../utopia-hooks/references/page-state-view.md` — full Page/State/View pattern reference
- `../utopia-hooks/references/hooks-reference.md` — complete hook catalog
- `../utopia-hooks/references/async-patterns.md` — download/upload mental model
- [migration-steps.md](./migration-steps.md) — step-by-step migration checklist
- [global-state-migration.md](./global-state-migration.md) — provider tree migration
