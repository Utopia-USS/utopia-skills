---
title: Global State
impact: CRITICAL
tags: global-state, providers, HasInitialized, MutableValue, registration
---

# Skill: Global State

App-wide state that any screen can access. Built from a State class, a hook that computes it,
and a registration entry in `_providers` at the app root.

## Quick Pattern

**Incorrect (state logic in widget):**
```dart
class HomeScreen extends HookWidget {
  Widget build(BuildContext context) {
    // Every screen that needs auth repeats this logic
    final snap = useMemoizedStream(FirebaseAuth.instance.userChanges);
    final user = snap.data;
    if (snap.connectionState != ConnectionState.active) return const Loader();
    if (user == null) return const LoginScreen();
    return HomeView(userId: user.uid);
  }
}
```

**Correct (shared global state — service layer):**
```dart
// auth_service.dart
class AuthService {
  Stream<User?> streamUser() => FirebaseAuth.instance.userChanges();
}

// auth_state.dart
class AuthState extends HasInitialized {
  final User? user;
  const AuthState({required super.isInitialized, required this.user});
  bool get isLoggedIn => user != null;
  String? get userId => user?.uid;
}

AuthState useAuthState() {
  final authService = useInjected<AuthService>();
  final snap = useMemoizedStream(authService.streamUser);
  return AuthState(
    isInitialized: snap.connectionState == ConnectionState.active,
    user: snap.data,
  );
}

// app.dart — registered once at the root
const _providers = {
  AuthState: useAuthState,
};

// Any screen state hook accesses it with one line:
final auth = useProvided<AuthState>();
```

## When to Use

- State shared between multiple screens (auth, user profile, settings, school/class context)
- Data loaded once at startup and used throughout the app (static data, feature flags)
- State that persists across navigation (shopping cart, active session, connectivity)
- Any state that would otherwise be passed down as constructor arguments across 2+ widget levels

## Step-by-Step: Creating global state

### 1. Choose the right base class

```dart
// Option A: extends HasInitialized — use when state has async loading
class CoursesState extends HasInitialized {
  final IMap<CourseId, Course>? courses;  // null while loading
  const CoursesState({required super.isInitialized, required this.courses});

  Course? course(CourseId id) => courses?[id];
}

// Option B: plain class — use when state is always available (no async init)
class ThemeState {
  final ThemeMode mode;
  const ThemeState({required this.mode});
}
```

### 2. Write the hook

```dart
CoursesState useCoursesState() {
  final courseService = useInjected<CourseAssetService>();

  // Call one hook per course — useMap handles the dynamic count
  final courseMap = useMap(
    CourseId.values,
    (id) => useAutoComputedState(() => courseService.load(id)).valueOrNull,
  );

  final allLoaded = courseMap.all((_, v) => v != null);

  return CoursesState(
    isInitialized: allLoaded,
    courses: allLoaded ? courseMap.toIMap().cast() : null,
  );
}
```

### 3. Register in app root

```dart
// classroom_app.dart (or equivalent app root)
const _providers = {
  AuthState: useAuthState,
  CoursesState: useCoursesState,
  ThemeState: useThemeState,
  // leave initialization-dependent states last
  InitializationState: useInitializationState,
};

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return HookProviderContainerWidget(
      _providers,
      alwaysNotifyDependents: false,
      child: /* ... */,
    );
  }
}
```

### ValueProvider — providing values without hooks

For values that don't need hooks (constants, configuration, already-computed values), use `ValueProvider` instead of registering in `_providers`:

```dart
// Provide a value to the subtree — accessible via useProvided<RouterState>()
ValueProvider(
  routerState,
  child: MaterialApp.router(routerConfig: routerState.routerConfig),
);
```

Use `_providers` + hook for reactive state. Use `ValueProvider` for static or already-computed values.

### 4. Consume in any screen state hook

```dart
SettingsScreenState useSettingsScreenState() {
  final auth = useProvided<AuthState>();
  final courses = useProvided<CoursesState>();

  // Guard: don't proceed until data is ready
  if (!courses.isInitialized) {
    return SettingsScreenState.loading();
  }

  return SettingsScreenState(
    userName: auth.user?.displayName,
    availableCourses: courses.courses!.values.toIList(),
  );
}
```

---

## HasInitialized

Base class for states with async initialization. Signals whether the state is ready.

```dart
class UserProfileState extends HasInitialized {
  final UserProfile? profile;

  const UserProfileState({
    required super.isInitialized,
    required this.profile,
  });
}

// isInitialized = false → loading
// isInitialized = true, profile = null → loaded but no data (e.g. logged out)
// isInitialized = true, profile != null → ready
```

**Loading guard pattern:**
```dart
// In screen state hook
final profile = useProvided<UserProfileState>();
if (!profile.isInitialized) return UserProfileScreenState.loading();

// In View
if (state.isLoading) return const CrazyLoader();
```

For stream-backed global state, `isInitialized` is derived from the snapshot's connection state — see [async-patterns.md § isInitialized pattern for global state](./async-patterns.md#isinitialized-pattern-for-global-state).

---

## MutableValue

Wraps a `useState` value for passing between layers. View reads and writes it directly
without needing a separate callback.

```dart
// In State hook — expose mutable field
final selectedFilter = useState(FilterType.all);
return DashboardState(
  filter: selectedFilter,  // MutableValue<FilterType>
  items: filteredItems,
);

// In View — read and write the same object
SegmentedControl(
  selected: state.filter.value,
  onChanged: (v) => state.filter.value = v,  // triggers rebuild
);
```

**When to use MutableValue vs callback:**

| Use case | Pattern |
|----------|---------|
| UI-only selection (filter, tab, checkbox) | `MutableValue<T>` |
| Action that triggers async work (save, delete) | `void Function()` callback |
| Field that requires validation | `useFieldState` |

```dart
// MutableValue — View drives the value, no business logic involved
final tabState = useState(TabIndex.first);
return ScreenState(tab: tabState);  // View: state.tab.value = TabIndex.second

// Callback — async work involved, State hook owns the logic
return ScreenState(onSavePressed: save);  // View: state.onSavePressed()
```

---

## Common Pitfalls

- **State registered but not initialized** — check the order in `_providers`; states registered earlier are available to those registered later
- **useProvided in a regular StatelessWidget** — only works in `HookWidget` (and hooks called from it)
- **Mutable state in State class** — `var` fields or setters on the State class create hidden mutation; use `MutableValue<T>` explicitly
- **Global state for screen-local data** — if only one screen uses it, it belongs in the screen state hook, not in `_providers`
- **Side effects in State class** — the class is a pure data holder; all logic lives in the hook

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useMemoizedStream, useAutoComputedState used inside global state hooks
- [di-services.md](./di-services.md) — useInjected inside global state hooks to access services
- [screen-state-view.md](./screen-state-view.md) — useProvided consuming global state in screen state hooks
- [async-patterns.md](./async-patterns.md) — loading states and HasInitialized patterns
