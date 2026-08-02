---
title: Global State Migration - BLoC Provider Tree → _providers
impact: HIGH
tags: migration, global-state, MultiBlocProvider, RepositoryProvider, providers, useInjected
---

# Global State Migration: BLoC Provider Tree → _providers

Migrating the app-level BLoC provider tree to utopia_hooks' flat `_providers` map.
Existing DI (get_it, provider, etc.) stays as-is - only a thin `useInjected` bridge hook is added.
This is typically step 1 in a codebase-wide migration.

---

## Overview

| BLoC | utopia_hooks |
|------|-------------|
| `MultiBlocProvider` wrapping `MaterialApp` | `HookProviderContainerWidget` wrapping `MaterialApp` |
| Nested `BlocProvider(create: ...)` | Flat `_providers` map: `{Type: useXState}` |
| `RepositoryProvider` / `MultiRepositoryProvider` | Keep existing DI + create `useInjected` bridge hook |
| `context.read<XCubit>()` from any widget | `useProvided<XState>()` from any hook |
| `context.read<XRepository>()` from any widget | `useInjected<XService>()` from any hook |
| Lazy init (BlocProvider creates on first read) | Eager init (all providers build at startup, in order) |

---

## Before: BLoC Provider Tree

```dart
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => TaskRepository(apiClient)),
        RepositoryProvider(create: (_) => SettingsRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => AuthCubit(ctx.read<AuthRepository>())),
          BlocProvider(create: (ctx) => SettingsCubit(ctx.read<SettingsRepository>())),
          BlocProvider(create: (ctx) => TaskListCubit(ctx.read<TaskRepository>())),
          BlocProvider(create: (ctx) => NavigationCubit()),
        ],
        child: MaterialApp(/* ... */),
      ),
    );
  }
}
```

---

## After: _providers + useInjected bridge

### 1. Create useInjected bridge hook (wraps existing DI)

Create a one-liner hook that bridges your project's existing DI into hook context.
The project keeps its DI library - no need to migrate service registrations.

```dart
// hooks/use_injected.dart

// For get_it:
T useInjected<T extends Object>() => GetIt.I<T>();

// For provider (if services are in provider):
// T useInjected<T>() => useProvided<T>();

// For a custom service locator:
// T useInjected<T>() => ServiceLocator.instance.get<T>();
```

**Key point:** `useInjected` is not a framework class - it's a one-liner you write yourself.
Pick the variant that matches your project's DI. Keep existing service registrations unchanged.

### 2. Create global state hooks (replace Cubits)

```dart
// state/auth_state.dart
class AuthState extends HasInitialized {
  final User? user;
  const AuthState({required super.isInitialized, required this.user});
  bool get isLoggedIn => user != null;
}

AuthState useAuthState() {
  final authRepo = useInjected<AuthRepository>();
  final snap = useMemoizedStream(authRepo.userStream);
  return AuthState(
    isInitialized: snap.connectionState == ConnectionState.active,
    user: snap.data,
  );
}

// state/settings_state.dart
class SettingsState extends HasInitialized {
  final ThemeMode themeMode;
  final String locale;
  const SettingsState({required super.isInitialized, required this.themeMode, required this.locale});
}

SettingsState useSettingsState() {
  final repo = useInjected<SettingsRepository>();
  final settings = useAutoComputedState(() => repo.load());
  return SettingsState(
    isInitialized: settings.isInitialized,
    themeMode: settings.valueOrNull?.themeMode ?? ThemeMode.system,
    locale: settings.valueOrNull?.locale ?? 'en',
  );
}
```

### 3. Register in _providers (replaces MultiBlocProvider)

```dart
// app.dart
const _providers = {
  // Global state hooks - order matters (earlier = available to later)
  AuthState: useAuthState,
  SettingsState: useSettingsState,
  TaskListState: useTaskListState,

  // Initialization-dependent states go LAST
  InitializationState: useInitializationState,
};

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HookProviderContainerWidget(
      _providers,
      alwaysNotifyDependents: false,
      child: MaterialApp(/* ... */),
    );
  }
}
```

---

## Key Differences

### Initialization Order

**BLoC:** Lazy by default - Cubit is created when first `context.read<XCubit>()` is called.

**Hooks:** Eager by definition - all hooks in `_providers` run immediately at app start.
Order in the map matters: hooks registered earlier are available via `useProvided<T>()`
to hooks registered later.

```dart
const _providers = {
  AuthState: useAuthState,            // 1. Auth available to everything below
  SettingsState: useSettingsState,    // 2. Can useProvided<AuthState>() if needed
  TaskListState: useTaskListState,    // 3. Can use Auth + Settings
};
```

If a state depends on another being initialized, use `shouldCompute` guard:
```dart
TaskListState useTaskListState() {
  final auth = useProvided<AuthState>();

  final tasks = useAutoComputedState(
    () => taskRepo.loadForUser(auth.userId!),
    keys: [auth.userId],
    shouldCompute: auth.isInitialized && auth.isLoggedIn,  // wait for auth
  );
  // ...
}
```

### No Lazy Loading

In BLoC, a screen-specific Cubit provided locally is created only when that screen opens.
In hooks, if you put it in `_providers`, it's always running.

**Rule:** Only put truly global state in `_providers`. Screen-local state stays in the screen state hook:

```dart
// ❌ Screen-specific state in _providers (always running)
const _providers = {
  // ...
  CheckoutState: useCheckoutState,  // only needed on checkout screen
};

// ✅ Screen-specific state in screen state hook (created on navigation)
CheckoutScreenState useCheckoutScreenState() {
  // all checkout logic here - lives only while screen is mounted
}
```

### HasInitialized

Every global state with async loading should extend `HasInitialized`:

```dart
class TaskListState extends HasInitialized {
  final IList<Task>? tasks;
  const TaskListState({required super.isInitialized, required this.tasks});
}
```

Consumers guard with:
```dart
final tasks = useProvided<TaskListState>();
if (!tasks.isInitialized) return SomeScreenState.loading();
```

---

## Migrating RepositoryProvider Dependencies

### Pattern: Direct dependency

```dart
// BLoC
BlocProvider(
  create: (ctx) => TaskListCubit(ctx.read<TaskRepository>()),
  // ...
)
```

```dart
// Hooks - useInjected resolves from your existing DI (e.g. get_it)
TaskListState useTaskListState() {
  final repo = useInjected<TaskRepository>();
  // ...
}
```

### Pattern: Cubit depends on other Cubit

```dart
// BLoC - Cubit reads another Cubit
class TaskListCubit extends Cubit<TaskListState> {
  TaskListCubit(this._repo, this._authCubit) : super(...);
  final AuthCubit _authCubit;
  // uses _authCubit.state.userId
}
```

```dart
// Hooks - useProvided reads global state directly
TaskListState useTaskListState() {
  final auth = useProvided<AuthState>();     // ← replaces _authCubit
  final repo = useInjected<TaskRepository>();
  // uses auth.userId
}
```

No constructor wiring needed - `useProvided` reads global state, `useInjected` reads services from your DI.

---

## Migrating BlocObserver

### BLoC

```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    log('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    log('${bloc.runtimeType} $error $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  Bloc.observer = AppBlocObserver();
  runApp(App());
}
```

### utopia_hooks

No direct equivalent. Instead:
- **State change logging** - add logging inside individual hooks if needed
- **Error handling** - use error callbacks in `runSimple` (`afterError`), or a global error handler (e.g. `FlutterError.onError`, Sentry, Crashlytics)
- **Analytics** - track in `afterSubmit` / `afterError` callbacks

---

## HydratedCubit → Global State with Persistence

If the global Cubit extends `HydratedCubit`, replace `fromJson`/`toJson` with `usePersistedState`:

```dart
// Hooks - global state with persistence
SettingsState useSettingsState() {
  final prefs = useInjected<PreferencesService>();
  final themeMode = usePersistedState<ThemeMode>(
    () async => prefs.load<ThemeMode>('themeMode'),
    (value) async => prefs.save('themeMode', value),
  );
  return SettingsState(
    isInitialized: themeMode.isInitialized,
    themeMode: themeMode.value ?? ThemeMode.system,
  );
}
```

See [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) section 6 for full side-by-side.

---

## Migration Checklist

```
□ Create useInjected bridge hook wrapping your existing DI (one-liner)
□ Create global state classes (extending HasInitialized where needed)
□ Create corresponding useXState() hooks
□ Register in _providers map (correct order: init-dependent last)
□ Replace MultiBlocProvider with HookProviderContainerWidget
□ Keep existing DI registrations (get_it, provider, etc.) as-is
□ Update all screens: context.read<XCubit>() → useProvided<XState>()
□ Update all screens: context.read<XRepository>() → useInjected<XService>()
□ Remove flutter_bloc and bloc from pubspec.yaml (after all screens migrated)
□ Verify initialization order - states that depend on others are later in _providers
□ Verify screen-local state is NOT in _providers
```

## Related

- [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) - state-layer pattern mapping
- [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) - widget-layer pattern mapping
- [migration-steps.md](./migration-steps.md) - per-screen migration process
- `utopia-hooks:references/global-state.md` - full global state documentation
- `utopia-hooks:references/di-services.md` - useInjected bridge hook and service patterns
