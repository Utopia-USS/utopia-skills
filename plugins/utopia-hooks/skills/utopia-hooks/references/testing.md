---
title: Testing Hooks
impact: HIGH
tags: testing, SimpleHookContext, SimpleHookProviderContainer, unit-test, hooks
---

# Skill: Testing Hooks

utopia_hooks provides two test utilities that let you test hook logic in isolation —
no widget tree, no `pumpWidget`, no `WidgetTester`. Tests are fast, synchronous-friendly,
and focus on the hook's behavior, not the UI.

| Tool | Use when |
|------|----------|
| `SimpleHookContext` | Testing a single hook or a screen state hook in isolation |
| `SimpleHookProviderContainer` | Testing global state hooks that use `useProvided` |

---

## Quick Pattern

**Incorrect (widget test for hook logic):**
```dart
testWidgets('saves task', (tester) async {
  await tester.pumpWidget(MaterialApp(home: TasksScreen()));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  expect(find.text('Saved!'), findsOneWidget); // testing UI, not logic
});
```

**Correct (hook unit test):**
```dart
test('save triggers service and navigates back', () async {
  var navigatedBack = false;
  final mockService = MockTaskService();

  final context = SimpleHookContext(() => useTaskScreenState(
    navigateBack: () => navigatedBack = true,
  ));

  context().onSavePressed();
  await context.waitUntil((it) => !it.isSaving);

  expect(navigatedBack, true);
  verify(mockService.save(any)).called(1);
});
```

---

## SimpleHookContext

Tests a single hook function. Automatically runs the hook on construction and after each state change.

### Basic usage

```dart
test('counter increments', () {
  final context = SimpleHookContext(() {
    final count = useState(0);
    return (value: count.value, increment: () => count.value++);
  });

  expect(context().value, 0);

  context().increment();
  expect(context().value, 1);
});
```

### API

```dart
// Create
final context = SimpleHookContext(
  () => useMyHook(param: value),  // hook function
);

// Access current value
context()          // calls context to get current state
context.value      // same, property form

// Manual rebuild (not usually needed — state changes trigger automatic rebuild)
context.rebuild()

// Wait for async state
await context.waitUntil((state) => state.isLoaded);

// Inject provided dependencies (for hooks that call useProvided)
SimpleHookContext(
  () => useMyHook(),
  provided: {AuthState: AuthState(isInitialized: true, user: fakeUser)},
)

// Cleanup
context.dispose()
```

### Testing async operations

```dart
test('loads product on init', () async {
  final mockService = MockProductService();
  when(mockService.load('123')).thenAnswer((_) async => Product(id: '123', name: 'Widget'));

  final context = SimpleHookContext(() => useProductScreenState(
    productId: '123',
    navigateBack: () {},
  ));

  // Initially loading
  expect(context().isLoading, true);

  // Wait for async load to complete
  await context.waitUntil((state) => !state.isLoading);
  expect(context().product?.name, 'Widget');
});
```

### Testing useEffect side effects

```dart
test('effect runs when key changes', () {
  var effectRunCount = 0;

  final context = SimpleHookContext(() {
    final id = useState('a');

    useEffect(() {
      effectRunCount++;
      return null;
    }, [id.value]);

    return id;
  });

  expect(effectRunCount, 1); // ran on mount

  context().value = 'b';
  expect(effectRunCount, 2); // ran on key change

  context().value = 'b';    // same value
  expect(effectRunCount, 2); // did not run
});
```

### Testing callbacks and navigation

```dart
test('onSavePressed calls service and navigates', () async {
  var navigatedBack = false;
  var savedName = '';
  final mockService = MockItemService();
  when(mockService.save(any)).thenAnswer((_) async {});

  final context = SimpleHookContext(() => useItemScreenState(
    itemId: 'item-1',
    navigateBack: () => navigatedBack = true,
  ));

  await context.waitUntil((s) => !s.isLoading);

  context().nameState.value = 'New Name';
  context().onSavePressed();

  await context.waitUntil((s) => !s.isSaving);
  expect(navigatedBack, true);
});
```

### Testing MutableValue fields

```dart
test('filter change updates displayed items', () {
  final context = SimpleHookContext(() => useTasksScreenState(
    navigateToDetail: (_) {},
  ));

  expect(context().tasks?.length, 5); // all tasks

  context().filter.value = FilterType.active;
  expect(context().tasks?.length, 3); // only active
});
```

---

## SimpleHookProviderContainer

Tests global state hooks and their interactions. Each entry in the map is a `useX`
hook registered by type — exactly mirrors the `_providers` map in the app root.

### Basic usage

```dart
test('auth state initializes', () async {
  final container = SimpleHookProviderContainer({
    AuthState: useAuthState,
  });

  expect(container.get<AuthState>().isInitialized, false);
  await container.waitUntil<AuthState>((it) => it.isInitialized);
  expect(container.get<AuthState>().isLoggedIn, false);
});
```

### Testing state that depends on other state

```dart
test('courses state waits for auth', () async {
  final container = SimpleHookProviderContainer({
    AuthState: useAuthState,
    CoursesState: useCoursesState,  // internally calls useProvided<AuthState>()
  });

  // CoursesState won't initialize until AuthState.isInitialized
  expect(container.get<CoursesState>().isInitialized, false);

  await container.waitUntil<CoursesState>((it) => it.isInitialized);
  expect(container.get<CoursesState>().courses, isNotEmpty);
});
```

### Injecting external dependencies (provided map)

Use the `provided` map for values that come from outside the container (mock services, injected values):

```dart
test('screen state hook uses provided auth', () async {
  final fakeUser = FakeUser(uid: 'user-123');

  final container = SimpleHookProviderContainer(
    {TasksState: useTasksState},
    provided: {
      AuthState: AuthState(isInitialized: true, user: fakeUser),
    },
  );

  await container.waitUntil<TasksState>((it) => it.isInitialized);
  expect(container.get<TasksState>().tasks, isNotEmpty);
});
```

### Updating provided values at runtime

```dart
test('state updates when auth changes', () async {
  final container = SimpleHookProviderContainer(
    {ProfileState: useProfileState},
    provided: {AuthState: AuthState(isInitialized: true, user: null)},
  );

  expect(container.get<ProfileState>().profile, isNull);

  // Simulate login
  container.setProvided<AuthState>(
    AuthState(isInitialized: true, user: FakeUser(uid: 'abc')),
  );

  await container.waitUntil<ProfileState>((it) => it.profile != null);
  expect(container.get<ProfileState>().profile?.id, 'abc');
});
```

### API

```dart
// Create
final container = SimpleHookProviderContainer(
  {StateA: useA, StateB: useB},    // hook registry — mirrors _providers
  provided: {int: 42},              // external injected values
);

// Access current state
container.get<StateA>()            // returns current StateA
container<StateA>()                // callable shorthand

// Update external dependency
container.setProvided<int>(100);

// Wait for async condition
await container.waitUntil<StateA>((it) => it.isReady);
```

---

## What to Test

### Do test:
- **Logic in State hooks** — filtering, sorting, derived values
- **Async operations** — loading states, success/error transitions
- **Callback behavior** — does `onSavePressed` call the service? navigate back?
- **State transitions** — does filter change update displayed items?
- **Global state interactions** — does CoursesState wait for AuthState?

### Don't test via hooks:
- **UI layout** — which widget appears where (use widget tests for that)
- **Navigation** — test that the callback was called, not that routing worked
- **Service internals** — mock the service; test that the hook calls it correctly

---

## Common Pitfalls

- **Forgetting `await context.waitUntil()`** — async hooks (useAutoComputedState, useMemoizedStream) don't resolve instantly; always wait for the expected state
- **Testing without dispose** — `SimpleHookContext` and `SimpleHookProviderContainer` hold resources; call `dispose()` in `tearDown` if using `setUp`
- **Asserting before async completes** — check `isLoading` first, then wait, then check the result
- **Testing View in hook tests** — View is a `StatelessWidget`, test it separately via widget tests if needed; hook tests cover the State hook

## Running Tests

Prefer the Dart MCP `run_tests` tool (instead of shell `dart test` / `flutter test`) — it returns structured per-test results and uses the active SDK. Fall back to `dart test` / `flutter test` only in CI scripts or when MCP isn't available. See the **Dart Tooling** section in [SKILL.md](../SKILL.md) for setup.

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — all hooks used in state hooks under test
- [screen-state-view.md](./screen-state-view.md) — what a screen state hook looks like
- [global-state.md](./global-state.md) — testing global state hooks with SimpleHookProviderContainer
- [async-patterns.md](./async-patterns.md) — testing useSubmitState and useAutoComputedState
