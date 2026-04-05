---
title: Step-by-Step Migration Checklist
impact: HIGH
tags: migration, checklist, step-by-step, screen, convert, refactor
---

# Step-by-Step: Migrating a Screen from BLoC to utopia_hooks

Migrate screen-by-screen, not file-by-file. Each screen fully migrated before moving to the next.

---

## Step 0: pubspec.yaml — FIRST, before writing any migration code

Update dependencies before touching any Dart file. This ensures `dart analyze` works
as a cross-check from the very first migrated file onward.

Follow [pubspec-migration.md](./pubspec-migration.md) for version resolution.

1. **Fetch** latest `utopia_arch` version from pub.dev (dynamic — `curl` the API, never from memory)
2. **Add** `utopia_arch: ^X.Y.Z` alongside existing BLoC packages (both coexist during migration)
3. **Do NOT remove BLoC packages yet** — other screens still need them. Remove only in the final cleanup.
4. **Never add** `flutter_hooks` — utopia_hooks is a completely separate implementation
5. **Run `flutter pub get`** — must pass before writing any code
6. **Run `dart analyze`** — note existing errors (pre-migration baseline); new errors after this point = your problem

Only proceed to Step 1 after `flutter pub get` succeeds.

---

## Step 1: Pre-Migration Assessment

Before touching Dart code:

```
□ Identify the Cubit/Bloc class and its state class
□ List all methods (Cubit) or event handlers (Bloc)
□ Identify BlocProvider scope — global (app root) or local (screen)?
□ If global → migrate to _providers first (see global-state-migration.md)
□ If this Cubit depends on ANOTHER Cubit → migrate that one first
□ List all BlocListeners — what side effects do they perform?
```

---

## Step 2: Rename + delete files

Do this FIRST, before writing any code.

**Rename:**
```
lib/cubit/task_list_cubit.dart  →  lib/state/task_list_state.dart
lib/bloc/auth_bloc.dart         →  lib/state/auth_state.dart
lib/screens/home_screen.dart    →  lib/screens/home/home_screen.dart
```

The target pattern is **Screen/State/View**. The `_screen.dart` filename stays — just restructure into the tripartite pattern:
- `home_screen.dart` stays as `home_screen.dart` (class `HomeScreen extends HookWidget`)
- Add `state/home_screen_state.dart` and `view/home_screen_view.dart`

**Delete immediately:**
```
lib/cubit/task_list_state.dart   ← old Freezed/part state file
lib/bloc/auth_event.dart         ← event classes — replaced by callbacks
lib/bloc/auth_state.dart         ← old state — merged into renamed bloc file
```

**Update barrel exports:**
```dart
// Before: export 'cubit/task_list_cubit.dart';
// After:  export 'state/task_list_state.dart';
```

---

## Step 3: Design the State class

Write the State class in the renamed file. See [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) sections 1, 7, 9, 12 for detailed before/after examples of each pattern.

Rules — **ALL mandatory, no exceptions:**

- **No `copyWith()`** — hooks use individual `useState` per field, not immutable state objects
- **No `extends Equatable`** — hooks don't need equality checks, no `props` getter
- **No `Status` enum** — hooks have built-in state machines (see below)
- **No `part` / `part of`** — everything in one file
- Nullable `T?` for data fields (null = not loaded yet)
- `bool` flags for in-progress actions
- One `void Function()` per user action
- `MutableValue<T>` for user-controlled selections (filter, tab)
- No widget imports, no BuildContext

**How Status maps to hooks (don't recreate it):**

| BLoC Status | Hook equivalent (built-in) | State class exposes |
|---|---|---|
| `idle` / `initial` | `ComputedStateValue.notInitialized` | `T? data` (null) |
| `loading` / `inProgress` | `ComputedStateValue.inProgress` | `bool isLoading` (via `!state.isInitialized`) |
| `success` / `loaded` | `ComputedStateValue.ready(T)` | `T? data` (non-null via `.valueOrNull`) |
| `failure` / `error` | error in `runSimple` callback | not in state — handled in hook |
| upload in progress | `submitState.inProgress` | `bool isSaving` |

**From Freezed union:**
```dart
// ❌ BLoC
@freezed
class TaskListState with _$TaskListState {
  const factory TaskListState.loading() = _Loading;
  const factory TaskListState.loaded(List<Task> tasks, {bool isDeleting}) = _Loaded;
  const factory TaskListState.error(String message) = _Error;
}

// ✅ Hooks — flat, no union, no copyWith, no Equatable
class TaskListScreenState {
  final IList<Task>? tasks;        // null = loading
  final bool isDeleting;
  final void Function(TaskId) onDeletePressed;
  final void Function() onRefreshPressed;

  const TaskListScreenState({
    required this.tasks,
    required this.isDeleting,
    required this.onDeletePressed,
    required this.onRefreshPressed,
  });
}
```

---

## Step 4: Migrate Cubit methods → hook body

| Cubit pattern | Hook equivalent |
|---|---|
| Constructor (initial load) | `useAutoComputedState(() => ...)` |
| Method that fetches data | `useAutoComputedState` with keys |
| Method that submits/mutates | `useSubmitState` + `runSimple` |
| `emit(state.copyWith(...))` | `useState` + `.value = ...` |
| Method that toggles a flag | `useState<bool>` + `.value = !.value` |
| Computed/derived/filtered value | `useMemoized(() => derive(source), [source])` — NEVER `useEffect` + `useState` |
| Timer / periodic | `usePeriodicalSignal` |
| Stream → read latest value | `useMemoizedStream` / `useMemoizedStreamData` |
| Stream → side effect per event | `useStreamSubscription` (auto-disposed, NOT `useState<StreamSubscription?>`) |
| Cubit depends on another Cubit | `useProvided<XState>()` |
| `TextEditingController` + `onChanged` | `useFieldState` + `TextEditingControllerWrapper` in View (see mapping #12) |

**Cascade trap — the #1 BLoC-brain mistake in hooks:**

In BLoC, the pattern is: event → handler → compute derived value → `emit(state.copyWith(derived: value))`.
Naively translated to hooks, this becomes: source changes → `useEffect` fires → writes to `useState` → triggers rebuild → repeat.

This is **structurally wrong**. Each `useEffect` → `useState` write is an extra rebuild frame.
Three cascading effects = four rebuilds where one suffices.

**Rule:** If a value is **computable** from other state, use `useMemoized` (runs synchronously during build, single rebuild). Only use `useEffect` for **fire-and-forget side effects** (analytics, stream subscriptions, external writes).

```dart
TaskListScreenState useTaskListScreenState() {
  final repo = useInjected<TaskRepository>();

  // Constructor + loadTasks() → auto-load on mount
  final tasksState = useAutoComputedState(() async => (await repo.getAll()).toIList());

  // deleteTask() → upload operation
  final deleteState = useSubmitState();
  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async {
      await repo.delete(id);
      await tasksState.refresh();
    },
  );

  return TaskListScreenState(
    tasks: tasksState.valueOrNull,
    isDeleting: deleteState.inProgress,
    onDeletePressed: deleteTask,
    onRefreshPressed: () => tasksState.refresh(),
  );
}
```

---

## Step 5: Migrate BlocBuilder → View

```dart
// ❌ BLoC
BlocBuilder<TaskListCubit, TaskListState>(
  builder: (context, state) {
    return state.when(
      loading: () => const CircularProgressIndicator(),
      loaded: (tasks, isDeleting) => ListView(...),
      error: (msg) => Text(msg),
    );
  },
)

// ✅ Hooks — StatelessWidget receives state
class TaskListScreenView extends StatelessWidget {
  final TaskListScreenState state;
  const TaskListScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasks;
    if (tasks == null) return const CrazyLoader();
    return ListView(
      children: tasks.map((t) => Dismissible(
        key: ValueKey(t.id),
        onDismissed: (_) => state.onDeletePressed(t.id),
        child: ListTile(title: Text(t.title)),
      )).toList(),
    );
  }
}
```

Changes:
- `context.read<XCubit>().method()` → `state.onXPressed()`
- `state.when(loading:, loaded:, ...)` → null checks on data fields
- All data comes from `state.` — no `context` access for business logic

---

## Step 6: Migrate BlocListener → useEffect or callback

```dart
// ❌ BLoC
BlocListener<TaskListCubit, TaskListState>(
  listener: (context, state) {
    if (state is _Error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
    }
  },
)

// ✅ Hooks — error handling in runSimple, no BlocListener needed
deleteState.runSimple<void, AppError>(
  submit: () async => repo.delete(id),
  mapError: (e) => e is AppError ? e : null,
  afterKnownError: (e) => showError(e.message),  // injected from Screen
);
```

For navigation side effects:
```dart
useEffect(() {
  if (someCondition) navigateToX();
  return null;
}, [someCondition]);
```

---

## Step 7: Wire up the Screen

```dart
// ❌ BLoC
class TaskListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskListCubit(context.read<TaskRepository>()),
      child: BlocConsumer<TaskListCubit, TaskListState>(...),
    );
  }
}

// ✅ Hooks — minimal coordinator
class TaskListScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTaskListScreenState();
    return TaskListScreenView(state: state);
  }
}
```

---

## Step 8: Compilation gate — BLOCKING, loop until zero errors

**Do NOT proceed to Step 9 until both commands pass with zero issues.**
**Do NOT report the migration as complete if any errors remain.**

```bash
# A: Dependencies must resolve
flutter pub get

# B: Static analysis — loop until clean
dart analyze
# ↳ If ANY errors → fix each one → re-run → repeat until "No issues found"
```

This is a loop, not a one-shot:

```
┌─────────────────────┐
│   dart analyze       │
│   ↓                  │
│   errors? ──yes──→ fix them ──→ (back to dart analyze)
│   ↓ no               │
│   PASS — proceed     │
└─────────────────────┘
```

Common post-migration errors:

| `dart analyze` error | Fix |
|---|---|
| `Undefined class 'XCubit'` | Old import → replace with `import 'state/x_state.dart'` |
| `'read' isn't defined for 'BuildContext'` | Leftover `context.read<X>()` → replace with `state.field` |
| `Unused import 'package:flutter_bloc/...'` | Remove the import line |
| `Unused import 'package:flutter_hooks/...'` | Remove — utopia_hooks is NOT flutter_hooks |
| `Missing concrete implementation` | State class missing required field |
| `The argument type 'X' can't be assigned to 'Y'` | State class shape changed → update call site |
| `'XState' is imported from both...` | Duplicate export in barrel file → remove one |

---

## Step 9: Cleanup + grep audit

```
□ Verify: grep -r "flutter_bloc\|package:bloc/" lib/ returns zero results
□ Verify: no files named *_bloc.dart or *_cubit.dart in lib/
□ Verify: no copyWith() methods in state classes
□ Verify: no extends Equatable on state classes
□ Remove .freezed.dart generated files for deleted Freezed states
□ Run build_runner if project has other generated code
```

---

## Step 10: Verify

```
□ App compiles without errors
□ Screen loads data correctly
□ User actions (save, delete, etc.) work
□ Error states show appropriate feedback
□ Navigation works (back, forward, deep links)
```

### Unit test with SimpleHookContext
```dart
test('tasks load on init', () async {
  final context = SimpleHookContext(() => useTaskListScreenState());
  expect(context().tasks, isNull);
  await context.waitUntil((s) => s.tasks != null);
  expect(context().tasks, isNotEmpty);
});
```

---

## Migration Order (for a full codebase)

Migrate **screen by screen**, not big-bang. BLoC and hooks coexist during migration — that's fine.
Commit after each working screen. The app must compile and run at every commit.

1. **pubspec FIRST** (Step 0) — add `utopia_arch` alongside existing BLoC packages. Both coexist. `flutter pub get`.
2. **Global state that the first screen needs** — if a screen reads `AuthBloc`, migrate `AuthBloc` → `AuthState` in `_providers` first. This may temporarily break other screens that still read `AuthBloc` — that's OK, they'll be fixed when you migrate them.
3. **One screen** — migrate fully (Screen + State + View), `dart analyze`, fix errors, commit.
4. **Next screen** — if it needs a global state that isn't migrated yet, migrate that state first. Repeat.
5. **After ALL screens are migrated** — remove BLoC packages from pubspec, delete old files, final cleanup.

```
┌─────────────────────────────────────────────────────┐
│ pubspec: add utopia_arch (keep flutter_bloc for now) │
│   ↓                                                  │
│ Migrate GlobalStateA (needed by Screen1)             │
│   ↓                                                  │
│ Migrate Screen1 → commit                             │
│   ↓                                                  │
│ Migrate GlobalStateB (needed by Screen2)             │
│   ↓                                                  │
│ Migrate Screen2 → commit                             │
│   ↓                                                  │
│ ... repeat for all screens ...                       │
│   ↓                                                  │
│ Remove flutter_bloc from pubspec → final commit      │
└─────────────────────────────────────────────────────┘
```

**Rules:**
- **Never** leave a screen half-migrated (mixing BLoC and hooks in ONE screen)
- **BLoC and hooks CAN coexist across screens** — Screen A uses hooks, Screen B still uses BLoC. That's the normal state during migration.
- **Run `dart analyze` after each screen** — catch errors immediately, not at the end
- **Commit after each working screen** — git history shows incremental progress, easy to bisect if something breaks
- **Migrating a global state may break screens that depend on it** — that's expected. When you get to those screens, you'll fix them.

## Related

- [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) — pattern-by-pattern mapping
- [global-state-migration.md](./global-state-migration.md) — provider tree migration
- `../utopia-hooks/references/page-state-view.md` — Screen/State/View pattern
- `../utopia-hooks/references/testing.md` — SimpleHookContext testing
