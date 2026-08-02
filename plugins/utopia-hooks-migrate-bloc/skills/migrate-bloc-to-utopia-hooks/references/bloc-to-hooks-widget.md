---
title: "BLoC → Hooks: Widget & Lifecycle Mapping"
impact: CRITICAL
tags: bloc, cubit, migration, mapping, side-by-side, emit, BlocBuilder, BlocListener
---

# BLoC → utopia_hooks: Pattern-by-Pattern Mapping

Every BLoC/Cubit concept has a direct hooks equivalent. This file provides side-by-side
code examples for each pattern. For the target hook contracts themselves, see `utopia-hooks:references/`.

This file covers widget-layer constructs (BlocBuilder, BlocListener, BlocConsumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver). For state-layer constructs (Cubit/Bloc classes, events, context.read, Status enums, persistence, global mutable state), see [bloc-to-hooks-state.md](./bloc-to-hooks-state.md).

---

## 1. BlocBuilder → View (StatelessWidget)

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
- `context`-based Cubit access → state is passed via constructor (no context needed)

See `utopia-hooks:references/screen-state-view.md` for the Screen/State/View pattern.

---

## 2. BlocListener → useEffect / callback

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
// In the state hook - not in the widget tree
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

**What changed (BLoC → hooks mapping):**
- `BlocListener` widget in tree → `useEffect` in hook
- `listenWhen:` predicate → `useEffect` keys array `[authState.isLoggedIn]`
- `Navigator.of(context)` → navigation callback injected from Screen
- Side effect moves from the widget tree (UI) to the hook (logic layer)

---

## 3. BlocConsumer → Screen + View

### BLoC

```dart
class CheckoutScreen extends StatelessWidget {
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
// Screen - coordinator
class CheckoutScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useCheckoutScreenState(
      showSuccessSnackbar: () => CrazyInfoSnackbar.show(context, 'Order placed!'),
    );
    return CheckoutScreenView(state: state);
  }
}

// State hook - listener + builder logic combined
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

// View - pure UI (omitted, see screen-state-view.md)
```

**What changed (BLoC → hooks mapping):**
- `BlocConsumer` (listener + builder in one widget) → split into Screen + State hook + View
- `listener:` body → `afterSubmit` callback in `runSimple` (or a `useEffect`)
- `builder:` body → `StatelessWidget` View
- `context.read<Cubit>().method()` → callback field on State class

---

## 4. buildWhen / listenWhen → useMemoized / useEffect with keys

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
final themeMode = useMemoized(() => settingsState.themeMode, [settingsState.themeMode]);

useEffect(() {
  reloadTranslations(settingsState.locale);
  return null;
}, [settingsState.locale]);
```

**What changed (BLoC → hooks mapping):**
- `buildWhen` predicate → `useMemoized` keys
- `listenWhen` predicate → `useEffect` keys
- Predicate comparison function → explicit key values

---

## 5. TextEditingController → useFieldState + TextEditingControllerWrapper

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
// BLoC-brain in hooks - DO NOT DO THIS
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

// ── View ──
TextEditingControllerWrapper(
  text: state.title,
  builder: (controller) => TextField(
    controller: controller,
    decoration: const InputDecoration(hintText: 'Title'),
  ),
)
```

**Rule:** Every `TextEditingController` in the old code becomes a `useFieldState()` in the hook + `TextEditingControllerWrapper` in the View. No exceptions.

See `utopia-hooks:references/hooks-reference.md` and `utopia-hooks:references/flutter-conventions.md` for `useFieldState` + `TextEditingControllerWrapper` details (validation, errors, bidirectional sync).

### Pitfall: a keyed useEffect fires on mount - the old listener callbacks did not

Old-code listeners (`TextEditingController.addListener` in `initState`, a dropdown's
`onChanged`) fire only on actual change notifications, never on first build. A keyed
`useEffect(..., [field.value, ...])` ALSO runs its body once on mount: utopia_hooks
schedules the effect via `addPostBuildCallback` in the hook's `init()`, so it executes
after the first frame, when a `ScrollController` is already attached. `hasClients` is
therefore NOT a first-render guard.

Porting "scroll / side-effect on user change" verbatim into a keyed effect reproduces
the side effect on screen entry. Found twice in the field, in two independent screen
migrations of the same codebase.

Fix shape: consume one skip on the mount run, BEFORE any `hasClients` check. The
ordering is load-bearing - if the skip sits after a false `hasClients`, the flag
survives the mount and swallows the first real user change instead:

```dart
final hasRunOnceState = useState(false, listen: false);
useEffect(() {
  if (!hasRunOnceState.value) {
    hasRunOnceState.value = true;
    return null;
  }
  if (!scrollController.hasClients) return null;
  scrollController.animateTo(/* ... */);
  return null;
}, [quantityField.value, selectedUnit]);
```

The same applies to any listener-triggered side effect ported to a keyed effect
(snackbars, haptics, focus moves), not just scrolling.

---

## 6. stream.listen() → useStreamSubscription

The most commonly missed pattern during migration. Manual `.listen()` + `.cancel()` is the stream equivalent of manual `try/catch/finally` for loading state - hooks eliminate the ceremony.

### BLoC / StatefulWidget

```dart
class NotificationsCubit extends Cubit<NotificationsState> {
  StreamSubscription<Notification>? _subscription;

  void startListening(Stream<Notification> stream) {
    _subscription = stream.listen(
      (notification) => _handleNotification(notification),
      onError: (e) => emit(state.copyWith(error: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
```

### utopia_hooks

```dart
NotificationsScreenState useNotificationsScreenState() {
  final service = useInjected<NotificationService>();

  useStreamSubscription(service.notificationStream, (notification) async {
    handleNotification(notification);
  });

  // ...
}
```

**What changed (BLoC → hooks mapping):**
- `StreamSubscription?` field + manual `.cancel()` in `close()` → `useStreamSubscription` (auto-disposed)
- `onError` callback → `useStreamSubscription`'s `onError` parameter
- No `useState<StreamSubscription?>()` - that pattern is always wrong in hooks

### Which stream hook to use

| Need | Hook |
|------|------|
| Side effect per event (sync, navigate, toast) | `useStreamSubscription(stream, handler)` |
| Latest value from stream, drives UI | `useMemoizedStream(() => stream)` |
| Latest value, simplified (data only) | `useMemoizedStreamData(() => stream)` |
| Both | `useMemoizedStreamData` for UI + `useStreamSubscription` for side effects |

**Rule:** If you see `.listen(` in a state hook file, it should be `useStreamSubscription`. Manual subscription management is the #1 source of resource leaks in migrated code.

See `utopia-hooks:references/async-patterns.md` for stream hook contracts. For complex stream patterns (accumulation, dynamic stream creation, init/refresh separation) see [complex-cubit-patterns.md](./complex-cubit-patterns.md) sections 2, 3, and 5.

---

## 7. StatefulWidget lifecycle → HookWidget

When a `StatefulWidget` exists primarily to manage lifecycle (subscriptions in `initState`, cleanup in `dispose`, side effects in `didChangeDependencies`), it should become a `HookWidget`.

### Never scal `build()` into one place

**The #1 migration mistake: copying the whole `StatefulWidget.build()` into the new View verbatim.** The old `build()` is a junk drawer - it mixes UI composition, side effects, and `BuildContext`-dependent primitives. Migrating means splitting those concerns across three files.

Walk the old `build()` line by line and classify each fragment into exactly one of:

| Fragment | Goes to | Example |
|---|---|---|
| UI composition - `Scaffold`, `Stack`, `Column`, `ListView`, layout, conditional widgets | **View** | `return Scaffold(body: Column(children: [...]))` |
| Side effect - reactive comparisons of old/new state, snackbar on change, controller sync, `addPostFrameCallback` | **State hook** (`useEffect` with keys) | `if (oldStatus != newStatus) showToast(...)` → `useEffect(() { ...; return null; }, [newStatus])` |
| `BuildContext`-dependent primitive - `showDialog`, `showModalBottomSheet`, `showMenu`, `Navigator.push`, `Scaffold.of(context)` | **Screen** (as callback passed to `useXScreenState`) | `onEdit: () => showModalBottomSheet(context: context, ...)` |
| `context.read<Cubit>()` / `context.watch<Cubit>()` | **State hook** (`useProvided<XState>()` / `useInjected<XService>()`) | - |
| Cubit method call followed by navigation | **State hook** does the work, Screen-injected callback handles navigation | `cubit.save().then((_) => Navigator.pop(context))` → hook `runSimple(submit: service.save, afterSubmit: (_) => navigateBack())` |

If a `BlocListener` wraps the old `build()`, its `listener:` body is always a side effect → state-hook `useEffect` (or a hook-level callback like `afterSubmit`). Never inline it in the new View.

**Anti-pattern**: the new `*_view.dart` contains eight handler functions with business logic plus 9 `useX` calls. That means everything landed in the View. Go back and split.

### StatefulWidget

```dart
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final StreamSubscription<Uri> _linkSubscription;
  late final StreamSubscription<String?> _notificationSubscription;
  StoriesDownloadStatus? _lastDownloadStatus;

  @override
  void initState() {
    super.initState();
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      context.push(uri.path);
    });
    _notificationSubscription = notifications.stream.listen((id) {
      if (id != null) navigateToItem(id);
    });
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    _notificationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storiesState = context.get<StoriesState>();
    // ❌ Side effect in build - comparing old/new value manually
    if (_lastDownloadStatus != storiesState.downloadStatus) {
      _lastDownloadStatus = storiesState.downloadStatus;
      if (storiesState.downloadStatus == StoriesDownloadStatus.finished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDownloadCompletedDialog();
        });
      }
    }
    return /* ... */;
  }
}
```

### utopia_hooks

```dart
class HomeScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useHomeScreenState(
      navigateToItem: (id) => context.push('/item/$id'),
      showDownloadCompleted: () => showDownloadCompletedDialog(),
    );
    return HomeScreenView(state: state);
  }
}

HomeScreenState useHomeScreenState({
  required void Function(String) navigateToItem,
  required void Function() showDownloadCompleted,
}) {
  final storiesState = useProvided<StoriesState>();

  // initState stream subscriptions → useStreamSubscription (auto-disposed)
  useStreamSubscription(appLinks.uriLinkStream, (uri) async {
    navigateToItem(uri.path);
  });
  useStreamSubscription(notifications.stream, (id) async {
    if (id != null) navigateToItem(id);
  });

  // Side effect in build → useEffect with keys
  useEffect(() {
    if (storiesState.downloadStatus == StoriesDownloadStatus.finished) {
      showDownloadCompleted();
    }
    return null;
  }, [storiesState.downloadStatus]);

  return HomeScreenState(/* ... */);
}
```

### Lifecycle mapping

| StatefulWidget | Hook equivalent |
|----------------|-----------------|
| `initState` + `dispose` (general setup/teardown) | `useEffect(() { ...; return cleanup; }, const [])` |
| `initState` stream `.listen()` + `dispose` `.cancel()` | `useStreamSubscription(stream, handler)` |
| Non-text controller creation + `dispose` (`PageController`, `ScrollController`) | `useMemoized(() => Controller(), [args], (it) => it.dispose())`. **NOT for TextEditingController** - see section 5 |
| `didChangeDependencies` | Hook body runs on every rebuild (reactive by default) |
| `didUpdateWidget` | `useEffect` with keys matching changed widget parameters |
| `WidgetsBindingObserver` + `didChangeAppLifecycleState` | `useAppLifecycleState(onPaused:, onResumed:, ...)` - see section 8 |
| Side effects in `build()` (comparing old/new) | `useEffect` with keys - never put side effects in build |
| `context.get<T>()` / `context.watch<T>()` | `useProvided<T>()` - always reactive |

**Rule:** After migration, no `StatefulWidget` should remain unless it has a genuine reason (e.g., wrapping a platform view).

---

## 8. WidgetsBindingObserver / AppLifecycleState → useAppLifecycleState

Screens that react to the app going foreground/background (save drafts on `paused`, refresh on `resumed`, pause timers on `inactive`) typically implement `WidgetsBindingObserver` inside a `StatefulWidget`. utopia_hooks provides `useAppLifecycleState` as a drop-in. **Do not create a service wrapper** - the hook is the target.

### BLoC / StatefulWidget

```dart
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        context.read<DraftCubit>().saveDraft();
        break;
      case AppLifecycleState.resumed:
        context.read<FeedCubit>().refresh();
        break;
      default:
        break;
    }
  }
}
```

### utopia_hooks

```dart
// Inside the state hook - no service, no observer, no dispose
useAppLifecycleState(
  onPaused: () => draftService.saveDraft(draft.value),
  onResumed: () => feedState.refresh(),
);
```

All callbacks are optional (`onResumed`, `onPaused`, `onInactive`, `onDetached`, `onHidden`) - pass only what you need. Auto-disposed when the hook unmounts.

**Anti-pattern during migration:** wrapping `WidgetsBindingObserver` in an `AppLifecycleService` injected via `useInjected<AppLifecycleService>()`. If you find yourself writing such a service, STOP - replace with `useAppLifecycleState` directly in the state hook.

---

## Common Pitfalls During Migration

- **Putting `useProvided` in View** - View is a StatelessWidget; state access stays in the hook
- **Creating a "HookCubit"** - don't wrap hooks in a class; the hook function IS the replacement for the Cubit class
- **Migrating one file at a time within a screen** - migrate the entire screen (Screen + State + View) at once
- **Leaving `flutter_bloc` as a dependency "just in case"** - remove it when all screens are migrated
- **Using raw `TextEditingController` in hooks** - always use `useFieldState` + `TextEditingControllerWrapper` (section 5)
- **Manual stream subscription management** - never use `useState<StreamSubscription?>()` + manual `.cancel()`; always `useStreamSubscription` (section 6). The #1 source of resource leaks in migrated code.
- **Leaving StatefulWidget with lifecycle management** - if it only exists to manage subscriptions/controllers/timers, convert to HookWidget (section 7)

## Related

- [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) - state-layer mapping (Cubit/Bloc classes, events, context.read, Status enums, persistence, global mutable state)
- `utopia-hooks:references/screen-state-view.md` - full Screen/State/View pattern reference
- `utopia-hooks:references/hooks-reference.md` - complete hook catalog
- `utopia-hooks:references/async-patterns.md` - download/upload mental model, useSubmitState, useAutoComputedState, stream hooks
- `utopia-hooks:references/global-state.md` - `_providers`, `useProvided`, StateClass
- `utopia-hooks:references/di-services.md` - `useInjected`, service injection
- `utopia-hooks:references/flutter-conventions.md` - IList/IMap, TextEditingControllerWrapper
- [migration-steps.md](./migration-steps.md) - step-by-step migration checklist
- [global-state-migration.md](./global-state-migration.md) - provider tree migration
- [complex-cubit-patterns.md](./complex-cubit-patterns.md) - advanced stream/global patterns
