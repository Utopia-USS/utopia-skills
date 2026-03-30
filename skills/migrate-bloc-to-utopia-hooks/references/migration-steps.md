---
title: Step-by-Step Migration Checklist
impact: HIGH
tags: migration, checklist, step-by-step, screen, convert, refactor
---

# Step-by-Step: Migrating a Screen from BLoC to utopia_hooks

This checklist converts one screen at a time. Migrate screen-by-screen, not file-by-file.
Each screen should be fully migrated before moving to the next.

---

## Pre-Migration Assessment

Before touching code, analyze the existing BLoC:

```
□ Identify the Cubit/Bloc class and its state class
□ List all methods (Cubit) or event handlers (Bloc)
□ List all state variants (Freezed unions, loading/loaded/error)
□ Identify BlocProvider scope — is it global (app root) or local (screen)?
□ Identify BlocListeners — what side effects do they perform?
□ Identify RepositoryProvider dependencies
□ Check if other screens depend on this Cubit/Bloc's state
```

If the Cubit/Bloc is **global** (provided at app root, consumed by multiple screens),
see [global-state-migration.md](./global-state-migration.md) first.

---

## Step 1: Create the file structure

From:
```
lib/
  cubit/
    task_list_cubit.dart
    task_list_state.dart     ← Freezed
  pages/
    task_list_page.dart      ← BlocProvider + BlocBuilder + BlocListener
```

To:
```
lib/ui/pages/task_list/
  task_list_page.dart                  ← HookWidget (coordinator)
  state/task_list_page_state.dart      ← State class + hook
  view/task_list_page_view.dart        ← StatelessWidget
```

Create the three empty files. Don't delete the BLoC files yet.

---

## Step 2: Design the State class

Analyze the BLoC state and flatten it:

**From Freezed union:**
```dart
@freezed
class TaskListState with _$TaskListState {
  const factory TaskListState.loading() = _Loading;
  const factory TaskListState.loaded(List<Task> tasks, {bool isDeleting}) = _Loaded;
  const factory TaskListState.error(String message) = _Error;
}
```

**To flat State class:**
```dart
class TaskListPageState {
  // Data fields — null means loading/not available
  final IList<Task>? tasks;

  // Progress flags
  final bool isDeleting;

  // Callbacks — one per user action
  final void Function(TaskId) onDeletePressed;
  final void Function() onRefreshPressed;

  const TaskListPageState({
    required this.tasks,
    required this.isDeleting,
    required this.onDeletePressed,
    required this.onRefreshPressed,
  });
}
```

**Rules for State class design:**
- Nullable `T?` replaces "loading" state (null = not loaded yet)
- `bool` flags replace "submitting" / "deleting" variants
- Error messages are NOT in state — they're handled via `afterKnownError` callbacks
- One `void Function()` per user action
- `MutableValue<T>` for user-controlled selections (filter, tab, dropdown)
- No widget imports, no BuildContext

---

## Step 3: Migrate Cubit methods → hook body

Map each Cubit method to a hooks equivalent:

| Cubit pattern | Hook equivalent |
|---|---|
| Constructor (initial load) | `useAutoComputedState(() => ...)` |
| Method that fetches data | `useAutoComputedState` with keys |
| Method that submits/mutates | `useSubmitState` + `runSimple` |
| `emit(state.copyWith(...))` | `useState` + `.value = ...` |
| Method that toggles a flag | `useState<bool>` + `.value = !.value` |
| Timer / periodic | `usePeriodicalSignal` |
| Stream subscription | `useMemoizedStream` |

**From Cubit:**
```dart
class TaskListCubit extends Cubit<TaskListState> {
  final TaskRepository _repo;

  TaskListCubit(this._repo) : super(const TaskListState.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    emit(const TaskListState.loading());
    try {
      final tasks = await _repo.getAll();
      emit(TaskListState.loaded(tasks));
    } catch (e) {
      emit(TaskListState.error(e.toString()));
    }
  }

  Future<void> deleteTask(String id) async {
    emit((state as _Loaded).copyWith(isDeleting: true));
    await _repo.delete(id);
    loadTasks();
  }
}
```

**To hook:**
```dart
TaskListPageState useTaskListPageState() {
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

  return TaskListPageState(
    tasks: tasksState.valueOrNull,
    isDeleting: deleteState.inProgress,
    onDeletePressed: deleteTask,
    onRefreshPressed: () => tasksState.refresh(),
  );
}
```

---

## Step 4: Migrate BlocBuilder → View

**From:**
```dart
BlocBuilder<TaskListCubit, TaskListState>(
  builder: (context, state) {
    return state.when(
      loading: () => const CircularProgressIndicator(),
      loaded: (tasks, isDeleting) => ListView(
        children: tasks.map((t) => Dismissible(
          key: ValueKey(t.id),
          onDismissed: (_) => context.read<TaskListCubit>().deleteTask(t.id),
          child: ListTile(title: Text(t.title)),
        )).toList(),
      ),
      error: (msg) => Text(msg),
    );
  },
)
```

**To:**
```dart
class TaskListPageView extends StatelessWidget {
  final TaskListPageState state;
  const TaskListPageView({required this.state});

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

**What to change:**
- `context.read<XCubit>().method()` → `state.onXPressed()`
- `state.when(loading:, loaded:, ...)` → null checks on data fields
- All data comes from `state.` — no `context` access for business logic

---

## Step 5: Migrate BlocListener → useEffect or callback

**From:**
```dart
BlocListener<TaskListCubit, TaskListState>(
  listener: (context, state) {
    if (state is _Error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
    }
  },
  child: /* BlocBuilder... */,
)
```

**To (in hook):**
```dart
// Error handling is already in runSimple — no BlocListener needed!
deleteState.runSimple<void, AppError>(
  submit: () async => repo.delete(id),
  mapError: (e) => e is AppError ? e : null,
  afterKnownError: (e) => showError(e.message),  // injected from Page
);
```

If the listener is for navigation or non-error side effects:
```dart
// In hook
useEffect(() {
  if (someCondition) navigateToX();
  return null;
}, [someCondition]);
```

---

## Step 6: Wire up the Page

**From:**
```dart
class TaskListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskListCubit(context.read<TaskRepository>()),
      child: BlocConsumer<TaskListCubit, TaskListState>(
        listener: (context, state) { /* ... */ },
        builder: (context, state) { /* ... */ },
      ),
    );
  }
}
```

**To:**
```dart
class TaskListPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTaskListPageState();
    return TaskListPageView(state: state);
  }
}
```

The Page is minimal — just calls the hook and passes state to View.
Navigation callbacks and context-dependent callbacks are injected here.

---

## Step 7: Handle BlocProvider scope

### Local BlocProvider (screen-only)
```dart
// BLoC — wraps a single screen
BlocProvider(
  create: (_) => TaskListCubit(repo),
  child: TaskListPage(),
)
```

**→ Nothing needed.** The hook is called inside the Page — state lives in the hook's lifecycle.

### Global BlocProvider (app-wide)
```dart
// BLoC — at app root
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => AuthCubit(authRepo)),
    BlocProvider(create: (_) => ThemeCubit()),
  ],
  child: App(),
)
```

**→ See [global-state-migration.md](./global-state-migration.md)** for full migration.

---

## Step 8: Update pubspec.yaml

When ALL screens are migrated, update dependencies:

**Remove:**
```yaml
# dependencies:
  bloc: ^9.0.0           # remove
  flutter_bloc: ^9.1.0   # remove

# dev_dependencies:
  bloc_lint: ^0.3.0      # remove
  bloc_test: ^10.0.0     # remove
  mockingjay: ^2.0.0     # remove (BLoC-specific mock helper)
```

**Add:**
```yaml
# dependencies:
  utopia_arch: ^0.5.0    # add — re-exports utopia_hooks + DI + navigation + error handling
  # OR, if the app only needs hooks with no arch utilities:
  utopia_hooks: ^0.4.0   # add (standalone, no DI/navigation/error handling)
```

Most apps should depend on `utopia_arch`, not `utopia_hooks` directly — `utopia_arch` re-exports all of `utopia_hooks` and adds `useInjected` (DI), `NestedNavigator`, `GlobalErrorHandler`, `PreferencesService`, etc. If the app already has `utopia_arch` in pubspec.yaml, no separate `utopia_hooks` entry is needed.

Keep `equatable` if your model classes use it (e.g., `Todo extends Equatable`).
Keep `mocktail` for general mocking.

---

## Step 9: Cleanup

```
□ Delete the Cubit/Bloc class file
□ Delete the Freezed state file (and its .freezed.dart generated file)
□ Delete BLoC event classes (if Bloc, not Cubit)
□ Remove BlocProvider/BlocListener/BlocBuilder from the widget tree
□ Remove `flutter_bloc` import from the migrated file
□ Remove `flutter_bloc`, `bloc`, `bloc_lint`, `bloc_test` from pubspec.yaml
□ Add `utopia_hooks` to pubspec.yaml dependencies
□ Run build_runner if other generated code exists in the project
□ Rename files and directories to utopia_hooks conventions (see below)
```

### File/directory naming conventions

BLoC projects typically use flat directories (`cubit/`, `bloc/`, `pages/`). Rename to the utopia_hooks structure:

| BLoC (old) | utopia_hooks (new) |
|---|---|
| `lib/cubit/task_list_cubit.dart` | _(deleted — logic is now in the hook)_ |
| `lib/cubit/task_list_state.dart` | `lib/ui/pages/task_list/state/task_list_page_state.dart` |
| `lib/bloc/task_list_bloc.dart` | _(deleted)_ |
| `lib/bloc/task_list_event.dart` | _(deleted)_ |
| `lib/pages/task_list_page.dart` | `lib/ui/pages/task_list/task_list_page.dart` |
| _(no view file)_ | `lib/ui/pages/task_list/view/task_list_page_view.dart` |

**Naming rules:**
- Pages live under `lib/ui/pages/<feature_name>/`
- State class file is `<feature_name>_page_state.dart` inside a `state/` subdirectory
- View file is `<feature_name>_page_view.dart` inside a `view/` subdirectory
- No `cubit/`, `bloc/`, or top-level `pages/` directories remain after migration

---

## Step 10: Verify

### Quick smoke test
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
  final context = SimpleHookContext(() => useTaskListPageState());

  expect(context().tasks, isNull); // loading

  await context.waitUntil((s) => s.tasks != null);
  expect(context().tasks, isNotEmpty);
});

test('delete calls repo and refreshes', () async {
  final context = SimpleHookContext(() => useTaskListPageState());
  await context.waitUntil((s) => s.tasks != null);

  context().onDeletePressed('task-1');
  await context.waitUntil((s) => !s.isDeleting);

  // verify repo was called, tasks refreshed
});
```

---

## Migration Order (for a full codebase)

1. **Global state first** — Migrate Cubits/Blocs at app root to `_providers`
2. **Leaf screens** — Screens with no children or dependencies
3. **Feature modules** — Group related screens and migrate together
4. **Shared Cubits** — Cubits used by multiple screens (already migrated to global state in step 1)
5. **Remove flutter_bloc** — Only after ALL screens are migrated

**Never** leave a screen half-migrated (mixing BLoC and hooks in one screen).

## Related

- [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) — pattern-by-pattern mapping reference
- [global-state-migration.md](./global-state-migration.md) — provider tree migration
- `../utopia-hooks/references/page-state-view.md` — full Page/State/View pattern
- `../utopia-hooks/references/testing.md` — SimpleHookContext testing
