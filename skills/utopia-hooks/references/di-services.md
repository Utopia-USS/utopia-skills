---
title: Dependency Injection & Services
impact: MEDIUM
tags: di, injection, services, injector, register, useInjected
---

# Skill: Dependency Injection & Services

Services are registered in an Injector and accessed via `useInjected<T>()` in hooks.
This decouples screens from concrete implementations and enables testability.

## Quick Pattern

**Incorrect (direct instantiation):**
```dart
TasksPageState useTasksPageState() {
  final service = TaskService(apiClient: ApiClient()); // tight coupling, not testable
  // ...
}
```

**Correct (injected service):**
```dart
TasksPageState useTasksPageState() {
  final service = useInjected<TaskService>(); // resolved from Injector
  // ...
}
```

## When to Use

- Accessing Firebase services, API clients, or data transformation services in a page state hook
- Accessing services in a global state hook
- Adding a new service to the app
- Writing a service that depends on other services

---

## Services Are Stateless Infrastructure Wrappers

Services own all contact with infrastructure (Firebase, gRPC, SharedPreferences, file system, HTTP). Hooks own all state. This means:

- A service exposes methods that return `Stream<T>`, `Future<T>`, or synchronous `T` — it never holds mutable state
- A hook calls `useInjected<Service>()` and passes the service's streams/futures to `useMemoizedStream`, `useAutoComputedState`, `useSubmitState`, etc.
- The hook never knows *how* data is stored or fetched — only *what* to ask for

```dart
// ❌ Hook calls infrastructure directly
ProfileState useProfileState() {
  final data = useAutoComputedState(
    () async => database.collection('profiles').doc(userId).get(),  // infra in hook
  );
  // ...
}

// ✅ Service wraps infrastructure, hook calls service
ProfileState useProfileState() {
  final profileService = useInjected<ProfileService>();
  final data = useAutoComputedState(
    () async => profileService.load(userId),  // hook doesn't know how/where
  );
  // ...
}
```

---

## Service Types

| Suffix | Responsibility | I/O | Returns |
|--------|----------------|-----|---------|
| `FirebaseService` | Firestore CRUD | Stream / Future | Stream for reads, Future for writes |
| `ApiService` | gRPC / REST calls | Future | Future |
| `DataService` | Pure transformations | None | Synchronous |
| `AssetService` | Local asset loading | Future | Future |

```dart
// FirebaseService — Firestore streams
class TaskFirebaseService extends FirestoreRepositoryService {
  Stream<IList<Task>> streamTasks(String userId) =>
      streamList('users/$userId/tasks', Task.fromJson);

  Future<void> save(Task task) => set('users/${task.userId}/tasks/${task.id}', task.toJson());
}

// ApiService — gRPC call
class TaskApiService {
  final GrpcClient _grpc;
  TaskApiService(this._grpc);

  Future<TaskResponse> createTask(CreateTaskRequest req) =>
      _grpc.execute((client) => client.createTask(req));
}

// DataService — pure, no I/O
class TaskDataService {
  IList<Task> filterByStatus(IList<Task> tasks, TaskStatus status) =>
      tasks.where((it) => it.status == status).toIList();

  TaskSummary buildSummary(IList<Task> tasks) =>
      TaskSummary(total: tasks.length, done: tasks.count((it) => it.isDone));
}
```

---

## Registering Services

Services are registered in a class that extends `Injector`:

```dart
class AppInjector extends Injector {
  @override
  void register() {
    // No dependencies
    register.noarg(TaskDataService.new);

    // With dependencies — Injector resolves them automatically
    register(TaskFirebaseService.new);  // TaskFirebaseService(FirebaseFirestore instance)
    register(TaskApiService.new);       // TaskApiService(GrpcClient instance)
  }
}
```

**`register.noarg`** — service constructor takes no arguments:
```dart
register.noarg(AnalyticsService.new);
register.noarg(DateFormatterService.new);
```

**`register`** — service constructor has dependencies resolved by Injector:
```dart
// TaskService(TaskFirebaseService fb, TaskApiService api, TaskDataService data)
register(TaskService.new);
// Injector finds registered TaskFirebaseService, TaskApiService, TaskDataService
// and passes them automatically
```

**Registering the Injector itself** in `_providers`:
```dart
const _providers = {
  Injector: AppInjector.use,  // first entry
  AuthState: useAuthState,
  // ...
};
```

---

## Accessing Services via useInjected

```dart
// In any state hook (page or global)
TasksPageState useTasksPageState() {
  final taskService = useInjected<TaskService>();
  final analyticsService = useInjected<AnalyticsService>();

  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async {
      await taskService.delete(id);
      analyticsService.track('task_deleted');
    },
  );

  // ...
}
```

**Where `useInjected` is allowed:**

| Location | Allowed? |
|----------|----------|
| Page state hook (`useXPageState`) | ✅ Yes |
| Global state hook (`useXState` in `_providers`) | ✅ Yes |
| View (`StatelessWidget.build`) | ❌ No — not a hook context |
| Page widget (`HookWidget.build`) | ⚠️ Technically possible, but put it in the State hook |
| Custom hooks | ✅ Yes, if called from an allowed hook |

---

## Common Pitfalls

- **Accessing infrastructure directly in hooks** — `FirebaseDatabase.instance.ref(...)`, `SharedPreferences.getInstance()`, raw HTTP clients in a hook body. Always wrap in a service and use `useInjected<Service>()`. The hook should never know *how* data is stored or fetched — only *what* to ask for.
- **Injecting in View** — `View extends StatelessWidget` cannot call hooks; pass services via State if needed (rare — usually pass results, not services)
- **Forgetting `register.noarg`** — if the constructor takes no parameters and you use `register(...)`, it will fail at runtime when Injector tries to resolve dependencies
- **Circular dependencies** — Service A → Service B → Service A will throw; redesign to extract shared logic into a third service
- **Using `useInjected` inside a regular function** — only valid inside a hook build context; don't call it inside a `Future` or callback body
- **One service doing too much** — split large services by type (Firebase vs API vs Data); keeps responsibilities clear and tests isolated

## Related Skills

- [page-state-view.md](./page-state-view.md) — useInjected in the State hook
- [global-state.md](./global-state.md) — useInjected in global state hooks
- [async-patterns.md](./async-patterns.md) — calling service methods via useSubmitState
