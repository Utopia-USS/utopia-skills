---
title: Screen / State / View Pattern
impact: CRITICAL
tags: architecture, screen, pattern, widget, hooks, navigation
---

# Skill: Screen / State / View Pattern

Every screen in a utopia_hooks app consists of exactly three files: Screen, State, and View.
This separation ensures logic never bleeds into UI and UI never bleeds into logic.

- **Screen** — `HookWidget`, pure coordinator. Reads `BuildContext`, builds navigation/dialog
  callbacks, calls exactly one hook (`useXScreenState`), returns the View.
- **State** — plain data class + hook function. All logic, services, async, and derived values
  live in the hook. No widgets, no `BuildContext`.
- **View** — `StatelessWidget`, pure UI. Receives `state` and nothing else. No hooks.

## Quick Pattern

**Incorrect (logic in widget):**
```dart
class TasksScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final tasks = useProvided<TasksState>().tasks;
    final service = useInjected<TaskService>();
    final isLoading = useState(false);

    Future<void> deleteTask(TaskId id) async {
      isLoading.value = true;
      await service.delete(id);
      isLoading.value = false;
    }

    return ListView(
      children: tasks?.map((t) => ListTile(
        title: Text(t.title),
        onLongPress: () => deleteTask(t.id),
      )).toList() ?? [],
    );
  }
}
```

**Correct (Screen + State + View):**
```dart
// tasks_screen.dart
class TasksScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTasksScreenState(
      navigateToDetail: (id) => Navigator.of(context).pushNamed('/task', arguments: id),
    );
    return TasksScreenView(state: state);
  }
}

// state/tasks_screen_state.dart
class TasksScreenState {
  final IList<Task>? tasks;           // null = loading
  final bool isDeleting;
  final void Function(TaskId) onTaskTapped;
  final void Function(TaskId) onDeletePressed;

  const TasksScreenState({
    required this.tasks,
    required this.isDeleting,
    required this.onTaskTapped,
    required this.onDeletePressed,
  });
}

TasksScreenState useTasksScreenState({
  required void Function(TaskId) navigateToDetail,
}) {
  final service = useInjected<TaskService>();
  final tasksState = useProvided<TasksState>();
  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async => service.delete(id),
  );

  return TasksScreenState(
    tasks: tasksState.tasks,
    isDeleting: deleteState.inProgress,
    onTaskTapped: navigateToDetail,
    onDeletePressed: deleteTask,
  );
}

// view/tasks_screen_view.dart
class TasksScreenView extends StatelessWidget {
  final TasksScreenState state;
  const TasksScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasks;
    if (tasks == null) return const CrazyLoader();
    return ListView(
      children: tasks.map(_buildTask).toList(),
    );
  }

  Widget _buildTask(Task task) {
    return ListTile(
      title: Text(task.title),
      onTap: () => state.onTaskTapped(task.id),
      onLongPress: () => state.onDeletePressed(task.id),
    );
  }
}
```

## When to Use

- Building any new screen or route
- Adding a feature to an existing screen
- Reviewing code for architecture violations
- Replacing a `StatefulWidget` with hooks

## File Naming

| Role | File | Class |
|------|------|-------|
| Screen | `feature_screen.dart` | `FeatureScreen extends HookWidget` |
| State | `state/feature_screen_state.dart` | `FeatureScreenState` + `useFeatureScreenState()` |
| View | `view/feature_screen_view.dart` | `FeatureScreenView extends StatelessWidget` |

## Screen = pure wiring

The Screen is a coordinator, not a logic host. Its `build()` may:

- Read from `BuildContext`: `Navigator.of(context)`, `context.push(...)`, `MediaQuery.of(context)`,
  `context.routeArgs<T>()` (utopia_arch), `context.navigator` (utopia_arch), `XDialog.show(context)`
- Call **exactly one hook**: `useXScreenState(...)` with navigation/dialog callbacks built inline
- Return `XScreenView(state: state)` — nothing else

The Screen **must not** call:

- `useInjected<T>()` — services belong in the state hook
- `useProvided<T>()` — global state belongs in the state hook (including `useProvided<NavigatorKey>` — see below)
- `useEffect`, `useStreamSubscription`, `useAutoComputedState`, `useSubmitState` — effects belong in the state hook
- `useState`, `useMemoized` — local state belongs in the state hook

Everything the Screen needs (services, state, effects) is encapsulated by the single `useXScreenState(...)` call.

### Navigation flows Screen → State → View as callbacks

Navigation is built **in the Screen** from `BuildContext` and passed to the state hook as callback
parameters. The state hook stores them as fields on the State class. The View calls them.

```dart
// ✅ CORRECT — Screen builds nav from context, hook receives callbacks
class HabitDetailsScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useHabitDetailsScreenState(
      habit: habit,
      navigateToEdit: () async => EditHabitScreen.show(context, habit),
      navigateToPaywall: () => Navigator.of(context).pushNamed('/paywall'),
    );
    return HabitDetailsScreenView(state: state);
  }
}

HabitDetailsScreenState useHabitDetailsScreenState({
  required Habit habit,
  required Future<Habit?> Function() navigateToEdit,
  required void Function() navigateToPaywall,
}) { /* ... */ }
```

```dart
// ❌ FORBIDDEN — injecting navigation into the state hook
HabitDetailsScreenState useHabitDetailsScreenState({required Habit habit}) {
  final navigatorKey = useProvided<NavigatorKey>();   // ❌ NEVER
  final router = useInjected<AppRouter>();             // ❌ NEVER
  // ...
}
```

**Never use `useProvided<NavigatorKey>` or `useInjected<AppRouter>` anywhere.** The state hook
receives navigation as `void Function()` / `Future<T?> Function()` parameters. The Screen closes
over `BuildContext` from `build()` and builds those callbacks.

## Widget Callback Policy

When a sub-widget exposes callbacks (`onTap`, `onFontSizeTap`, `onSendTapped`, `onEdit`), classify
each callback before wiring it:

1. **Business callback** — triggers state logic, async work, navigation, or mutates domain data.
   → Must be a **field on the `State` class**. The state hook builds it (opening dialogs via the
   Screen-injected callback if needed). View passes it through: `MorePopupMenu(onLoginTapped: state.onLoginTapped)`.
2. **Widget-internal callback** — affects only the sub-widget's own local UI state (expand/collapse,
   focus, hover, per-tile animation).
   → Belongs in a **widget-level hook** on the sub-widget itself. See [composable-hooks.md](./composable-hooks.md) Pattern 1.

**Never build business callbacks as closures in the View.**

```dart
// ❌ Closure in View — couples View to service and BuildContext
class ItemScreenView extends StatelessWidget {
  Widget build(BuildContext context) {
    return ReplyBox(
      onSendTapped: (text) {                         // ← business logic in View
        if (!state.isLoggedIn) {
          Navigator.of(context).pushNamed('/login');
          return;
        }
        state.onReplyWith(text);
      },
    );
  }
}

// ✅ Callback is a field on State — View passes it through
class ItemScreenView extends StatelessWidget {
  Widget build(BuildContext context) {
    return ReplyBox(onSendTapped: state.onSendReply);
  }
}
```

### The same rule applies to the Screen file — no top-level `_onXTapped(context, ...)` helpers

The "closures in View" prohibition has a mirror in the Screen file: **do not write top-level
private functions in the Screen file that accept `BuildContext` + state objects and orchestrate
dialogs/sheets/navigation.** They are business callbacks wearing a disguise — relocation debt
parked at file scope.

Symptom shape:

```dart
// ❌ Forbidden — Screen file with 9 top-level helpers
class ItemScreen extends HookWidget {
  Widget build(BuildContext context) {
    final state = useItemScreenState(/* ... */);
    return ItemScreenView(
      state: state,
      onMoreTapped: (item, rect) => _onMoreTapped(
        context, item, rect,
        authState: state.auth,        // ← closure captures state
        favState: state.fav,
        splitViewState: state.splitView,
      ),
      onFlagTapped: (item) => _onFlagTapped(context, item, authState: state.auth),
      onBlockTapped: (item, isBlocked) => _onBlockTapped(context, item, isBlocked: isBlocked),
      onShareTapped: (item, rect) => _onShareTapped(context, item, rect),
      onFontSizeTapped: () => _onFontSizeTapped(
        context,
        fontSizeKey: state.fontSizeIconButtonKey,
        preferenceState: state.preference,
      ),
      // ... 5 more
    );
  }
}

// 290 LoC of private helpers at the bottom of item_screen.dart:
void _onMoreTapped(BuildContext ctx, Item item, Rect? rect, {
  required AuthGlobalState authState, required FavGlobalState favState,
  required SplitViewGlobalState splitViewState,
}) {
  showModalBottomSheet<MenuAction>(context: ctx, builder: /* ... */).then((action) {
    switch (action) {
      case MenuAction.fav: _onFavTapped(ctx, item, favState: favState);
      case MenuAction.flag: _onFlagTapped(ctx, item, authState: authState);
      // ...
    }
  });
}

void _onFlagTapped(BuildContext ctx, Item item, {required AuthGlobalState authState}) { /* ... */ }
void _onBlockTapped(BuildContext ctx, Item item, {required bool isBlocked}) { /* ... */ }
void _onShareTapped(BuildContext ctx, Item item, Rect? rect, {Item? parent}) { /* ... */ }
// ...
```

This compiles, passes the exit-gate greps, and is completely wrong. The `_onMoreTapped` helper
reads global state (`authState`, `favState`), opens a modal, and dispatches to more helpers.
**That is the state hook's job.** Keeping it at file scope in the Screen file means:

- The state hook doesn't expose `onMoreTapped` — the View asks the Screen to build it each `build()`.
- Tests for `onMoreTapped` behaviour have to go through the Screen + a fake BuildContext, not the hook.
- Any future widget that wants the same action re-imports the helper — spread through the subtree.

**Fix:** the Screen injects small, typed **UI primitives** (`showLoginDialog`, `showFlagDialog`,
`showMoreSheet`, `navigateToItem`, `showSnackBar`). The state hook composes the business
callbacks (`onMoreTapped`, `onFlagTapped`, ...) using those primitives **plus state it already
owns** (`authState`, `favState` obtained via `useProvided` inside the hook).

```dart
// ✅ Correct — Screen is ~80 LoC, no top-level helpers
class ItemScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useItemScreenState(
      item: item,
      // Thin primitives — each one just opens a UI surface and returns a result.
      // The hook composes onMoreTapped/onFlagTapped/etc. from these.
      showLoginDialog: () => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LoginDialog(),
      ),
      showFlagConfirmation: (byUser) => showDialog<bool>(
        context: context,
        builder: (_) => FlagDialog(byUser: byUser),
      ),
      showMoreSheet: (item) => showModalBottomSheet<MenuAction>(
        context: context,
        isScrollControlled: true,
        builder: (_) => MorePopupMenu(item: item),
      ),
      navigateToItem: (args) => context.push(Paths.item, extra: args),
      showSnackBar: (msg, {action, label}) =>
        context.showSnackBar(content: msg, action: action, label: label),
      showErrorSnackBar: () => context.showErrorSnackBar(),
    );

    return ItemScreenView(state: state);
  }
}

// In useItemScreenState — the hook composes actions from primitives + its own state:
ItemScreenState useItemScreenState({
  required Item item,
  required Future<void> Function() showLoginDialog,
  required Future<bool?> Function(String byUser) showFlagConfirmation,
  required Future<MenuAction?> Function(Item item) showMoreSheet,
  required void Function(ItemScreenArgs) navigateToItem,
  required void Function(String, {VoidCallback? action, String? label}) showSnackBar,
  required void Function() showErrorSnackBar,
}) {
  final authState = useProvided<AuthGlobalState>();
  final favState = useProvided<FavGlobalState>();
  // ...

  Future<void> onMoreTapped(Item item) async {
    final action = await showMoreSheet(item);
    switch (action) {
      case MenuAction.fav:
        if (favState.favIds.contains(item.id)) {
          favState.onRemoveFav(item.id);
          showSnackBar('Removed from favorites.');
        } else {
          favState.onAddFav(item.id);
          showSnackBar('Added to favorites.');
        }
      case MenuAction.flag:
        final yes = await showFlagConfirmation(item.by);
        if (yes ?? false) {
          authState.onFlag(item);
          showSnackBar('Comment flagged!');
        }
      // ...
      default: break;
    }
  }

  return ItemScreenState(onMoreTapped: onMoreTapped, /* ... */);
}
```

**Weight check:** for Complex screens, the Screen file should typically sit under ~100 LoC.
Over that, audit for top-level helpers. A Screen at 400+ LoC with 5+ private helpers is the
unambiguous symptom of this anti-pattern.

**Quick grep** (signatures may span multiple lines — match any top-level `_fn(` first, then inspect each hit):
```bash
grep -nE '^(Future<[^>]+>|void|bool|int|\w+) _[a-z]\w*\(' <screen_file>
```

If that returns more than a handful of results and each captures `BuildContext` + state
(visible in the multi-line signature block) → move them into the hook's action composition.

## Step-by-Step: Creating a new screen

### 1. State class — define your data contract

```dart
class ProductScreenState {
  // Data displayed by the View
  final Product? product;           // null = loading
  final bool isSaving;

  // Mutable fields (user-editable) — View reads AND writes
  final MutableFieldState nameField;

  // Callbacks — View calls these, Screen provides implementations
  final void Function() onSavePressed;
  final void Function() onDeletePressed;

  const ProductScreenState({
    required this.product,
    required this.isSaving,
    required this.nameField,
    required this.onSavePressed,
    required this.onDeletePressed,
  });

  bool get canSave => product != null && nameField.value.isNotEmpty;
}
```

Rules for the State class:
- **Immutable data** fields (final, no setters)
- **`MutableValue<T>` / `MutableFieldState`** for fields the View needs to read AND update
- **`void Function()` callbacks** for user actions — navigation/dialogs passed from Screen
- No widget imports, no `BuildContext`, no Flutter dependencies
- **No global-state re-export.** State must NOT hold a cross-screen global (e.g. `AuthState authState`, `SettingsState settingsState`) as a field. Re-exporting the whole global forces every field read on the View to rebuild the entire subtree when any unrelated field of that global changes, defeating `useProvided`'s granular reactivity. Instead:
  - Project selectively: expose the specific primitives the View needs (`final bool isLoggedIn;` instead of `final AuthState authState;`).
  - OR have the consuming widget call `useProvided<AuthState>()` in its own widget-level hook, so it rebuilds independently of the screen state.
  Sub-hook states from the same screen's `state/` folder (composition pattern, see [composable-hooks.md][composable-hooks]) are NOT re-exports and MAY be held as fields — they're the point of the aggregator. The rule targets cross-screen globals only.

[composable-hooks]: composable-hooks.md

### 2. State hook — implement logic

```dart
ProductScreenState useProductScreenState({
  required String productId,
  required void Function() navigateBack,
  required void Function(String message) showErrorSnackbar,
}) {
  // Services
  final service = useInjected<ProductService>();

  // Local state
  final nameField = useFieldState();
  final product = useAutoComputedState(() => service.load(productId));
  final saveState = useSubmitState();

  // Sync name field when product loads
  useEffect(() {
    if (product.valueOrNull != null) nameField.value = product.value.name;
    return null;
  }, [product.valueOrNull?.name]);

  void save() => saveState.runSimple<void, AppError>(
    submit: () async => service.update(productId, name: nameField.value),
    afterSubmit: (_) => navigateBack(),
    mapError: (e) => e is AppError ? e : null,
    afterKnownError: (e) => showErrorSnackbar('Failed to save: ${e.message}'),
  );

  return ProductScreenState(
    product: product.valueOrNull,
    isSaving: saveState.inProgress,
    nameField: nameField,
    onSavePressed: save,
    onDeletePressed: () {/* ... */},
  );
}
```

### 3. Screen — wire navigation and dialogs

```dart
@RoutePage()
class ProductScreen extends HookWidget {
  final String productId;
  const ProductScreen({required this.productId});

  @override
  Widget build(BuildContext context) {
    final state = useProductScreenState(
      productId: productId,
      navigateBack: Navigator.of(context).pop,
      showErrorSnackbar: (msg) => CrazyInfoSnackbar.show(context, msg),
    );
    return ProductScreenView(state: state);
  }
}
```

### 4. View — pure UI

```dart
class ProductScreenView extends StatelessWidget {
  final ProductScreenState state;
  const ProductScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.product == null) return const CrazyLoader();

    return CrazyPage(
      title: const Text("Edit Product"),
      sliversBuilder: (_, __) => [
        SliverToBoxAdapter(child: _buildForm()),
        SliverToBoxAdapter(child: _buildButtons()),
      ],
    );
  }

  Widget _buildForm() {
    return TextEditingControllerWrapper(
      text: state.nameField,
      builder: (controller) => TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    );
  }

  Widget _buildButtons() {
    return CrazySquashButton(
      onTap: state.onSavePressed,
      enabled: state.canSave,
      child: const Text("Save"),
    );
  }
}
```

View rules:
- `extends StatelessWidget`
- Receives `final XScreenState state` — nothing else
- No hooks, no `useProvided`, no `useInjected`
- No `BuildContext` for business logic (only for UI utilities like `MediaQuery`)
- Private `_buildXxx` helper methods for long `build()` methods
- Business callbacks are fields on `state` — never built inline as closures

## Common Pitfalls

- **`useProvided` / `useInjected` in View** — View receives everything it needs via State; it never reaches for global dependencies
- **Widget imports in State class** — if `state/feature_screen_state.dart` imports `package:flutter/material.dart` for anything other than `Color`, it's a red flag
- **Navigation logic in State hook** — navigation callbacks are injected from Screen, not called directly
- **`useProvided<NavigatorKey>` / `useInjected<AppRouter>`** — never. Navigation is a callback, not an injected dependency
- **Multiple hooks in Screen** — Screen calls `useXScreenState` once. Anything else belongs in the state hook
- **Business callbacks built as View closures** — closures in View couple UI to services; callbacks go on the State class
- **Shared State class across screens** — each screen has its own State class; don't reuse across routes

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useState, useMemoized, useEffect inside the State hook
- [global-state.md](./global-state.md) — useProvided to access app-wide state
- [async-patterns.md](./async-patterns.md) — useSubmitState, useAutoComputedState in the State hook
- [di-services.md](./di-services.md) — useInjected to access services
- [composable-hooks.md](./composable-hooks.md) — widget-level hooks for local sub-widget state
- [flutter-conventions.md](./flutter-conventions.md) — TextEditingController/FocusNode canonical wrappers
