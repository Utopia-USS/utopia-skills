---
title: Complex Cubit Migration Patterns
impact: HIGH
tags: complex, decomposition, streams, accumulation, dynamic-stream, global-state, migration
---

# Complex Cubit Migration Patterns

This reference covers patterns that appear **only in complex cubits** (>10 public methods, multiple streams, global mutable state, >300 estimated hook lines). Simple 1:1 mappings are in [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) — this file picks up where that one stops.

A complex cubit is identifiable by Phase 1b's complexity classification. If any indicator is "Complex", you will encounter patterns from this file. **Read this before Phase 2.**

---

## 1. Decomposing a monolithic cubit into sub-hooks

A cubit with 20+ methods spanning multiple domains (data fetching, search, scroll, collapse state, thread navigation) must NOT become a single hook. The hook equivalent is **multiple sub-hooks composed by a main screen hook** (see `composable-hooks.md` Pattern 3).

### How to identify domains

Group the cubit's public methods by what they operate on:

```
// Example: a 1,200-line cubit with 24 public methods

Data fetching domain:    init(), refresh(), loadAll(), loadMore()
Collapse domain:         collapse(), uncollapse(), collapsedCount(), lock(), unlock()
Scroll domain:           scrollTo(), scrollToNext(), scrollToPrevious(), scrollToItem()
Search domain:           search(), resetSearch()
Settings domain:         updateOrder(), updateFetchMode()
```

**Signals that two methods belong to the same domain:**
- They mutate the same state fields (e.g. both touch `comments` list)
- They call each other (e.g. `refresh()` calls `_preserveState()`)
- They share private helpers (e.g. `_sortKids()` used by `init()` and `refresh()`)
- Removing one would break the other

**Signals that methods belong to different domains:**
- They operate on disjoint state fields (`matchedComments` vs `collapseStates`)
- They can be tested independently
- One domain can be deleted without affecting the other

### Resulting decomposition plan

```
useFetchState(itemId, fetchMode, order)        — init, refresh, loadAll, loadMore, stream management
useCollapseState(comments)                      — collapse, uncollapse, collapsedCount, persistence
useScrollState(comments, isAllLoaded)           — scrollTo, scrollToNext, scrollToPrevious
useSearchState(comments)                        — search, resetSearch
Main useScreenState()                           — composes all four, wires cross-domain dependencies
```

### Handling shared state between sub-hooks

The most common challenge: multiple domains read/write the same field (e.g. `comments` list). The rule is: **one sub-hook owns the field, others receive it as input.**

```dart
// ✅ fetch sub-hook OWNS the comments list
FetchState useFetchState(...) {
  final comments = useState<IList<Comment>>(const IList.empty());
  // ... populates comments from stream
  return FetchState(comments: comments.value, ...);
}

// ✅ collapse sub-hook RECEIVES comments and returns modified list
CollapseState useCollapseState(IList<Comment> comments) {
  // operates on the received list, returns collapsed version
  return CollapseState(
    collapsedComments: applyCollapseStates(comments),
    onCollapse: collapse,
    onUncollapse: uncollapse,
  );
}

// ✅ main hook wires them together
ScreenState useScreenState(...) {
  final fetch = useFetchState(...);
  final collapse = useCollapseState(fetch.comments);  // fetch → collapse
  final scroll = useScrollState(collapse.collapsedComments);  // collapse → scroll
  final search = useSearchState(fetch.comments);  // fetch → search
  // ...
}
```

**Rule:** Sub-hooks never call each other. The main hook is the coordinator. If sub-hook A needs output from sub-hook B, the main hook passes B's output as A's input.

### What NOT to do

```dart
// ❌ Single 900-line hook with 20 useState calls
ScreenState useScreenState() {
  final comments = useState<IList<Comment>>(...);
  final matchedComments = useState<IList<Comment>>(...);
  final collapseStates = useState<Map<int, bool>>(...);
  final scrollController = ...;
  final searchQuery = useState('');
  final isLoading = useState(false);       // ❌ should be useAutoComputedState
  final isRefreshing = useState(false);    // ❌ should be useSubmitState
  final isFetchingParent = useState(false); // ❌ should be useSubmitState
  // ... 17 more useState calls, 900 lines of mixed-domain logic
}
```

---

## 2. Streams in complex cubits

Most streams emit a **complete value** — a full list, an object, a snapshot of current state. For these, use `useMemoizedStream` / `useMemoizedStreamData` and pass to View. No accumulation, no side effects:

```dart
// Stream<List<Item>> — complete state per emission
final items = useMemoizedStreamData(() => repository.streamItems(parentId), keys: [parentId]);
// items is List<Item>? — null before first event, full list after

// Stream<UserProfile> — object per emission
final profile = useMemoizedStreamData(() => profileService.stream(userId), keys: [userId]);
```

If the stream value needs processing before reaching the View, use `useEffect`:

```dart
final rawItems = useMemoizedStreamData(() => repository.streamItems(parentId), keys: [parentId]);

// Side effect when stream emits new value (e.g. sync to local cache, trigger analytics)
useEffect(() {
  if (rawItems != null) cacheService.update(rawItems);
  return null;
}, [rawItems]);
```

### Stream accumulation (rare — events → growing list)

Some APIs emit **individual items one by one** (e.g. recursive fetch that yields each item as it's resolved). This is NOT the typical stream pattern — most streams emit complete state. Only use accumulation when the stream genuinely emits incremental events.

The cubit pattern:

```dart
// BLoC: manual .listen() + accumulate + emit
_subscription = commentStream.listen((comment) {
  comments.add(comment);
  emit(state.copyWith(comments: List.from(comments)));
});
// + manual .onDone(), .onError(), .cancel() in close()
```

In hooks this is a composition of existing hooks — no new abstraction needed.

### Without preloading

```dart
// null = not yet started, empty = stream emitted but no items, non-empty = items loaded
final items = useState<IList<Comment>?>(null);

useStreamSubscription(commentStream, (comment) async {
  items.value = (items.value ?? const IList.empty()).add(comment);
});
```

### With preloading (initial data loaded first, then stream appends)

```dart
final items = useAutoComputedState(
  () => repository.fetchInitialItems(parentId),
  keys: [parentId],
);

useStreamSubscription(liveStream, (newItem) async {
  items.updateValue(items.valueOrNull!.add(newItem));
});
```

### With onError

If the cubit's `.listen()` has an `onError` callback, it becomes a `useStreamSubscription` parameter:

```dart
final items = useState<IList<Comment>?>(null);

useStreamSubscription(
  commentStream,
  (comment) async {
    items.value = (items.value ?? const IList.empty()).add(comment);
  },
  onError: (e, st) { /* handle */ },
);
```

### Pagination (load more)

When the cubit loads page-by-page and the user triggers "load more", this is Future-based — not stream-based. Use `useAutoComputedState` for initial load and `useSubmitState` for load more:

```dart
// In the fetch sub-hook:
final initialItems = useAutoComputedState(
  () => repository.fetchPage(0),
  keys: const [],
);
final additionalItems = useState<IList<Item>>(const IList.empty());
final loadMoreState = useSubmitState();

void loadMore() => loadMoreState.runSimple<void, Never>(
  submit: () async {
    final nextPage = additionalItems.value.length ~/ pageSize + 1;
    final newItems = await repository.fetchPage(nextPage);
    additionalItems.value = additionalItems.value.addAll(newItems);
  },
);

return FetchState(
  items: initialItems.valueOrNull?.addAll(additionalItems.value),
  isLoading: !initialItems.isInitialized,
  onLoadMore: loadMore,
);
```

---

## 3. Dynamic stream creation

Complex cubits often create streams conditionally — based on async checks (connectivity, fetch mode, cache state). The BLoC pattern:

```dart
// BLoC: stream created imperatively inside init()
Future<void> init() async {
  late final Stream<Item> stream;

  if (isOffline) {
    stream = offlineRepo.getCachedStream(ids: kids);
  } else if (await shouldFetchFromWeb) {
    stream = webRepo.fetchStream(item);
  } else {
    stream = apiRepo.fetchAllRecursivelyStream(ids: kids);
  }

  _subscription = stream.listen(_onFetched)
    ..onDone(_onDone)
    ..onError(_onError);
}
```

**The rule stays: no `.listen()` in hook files, no exceptions.** The solution is to restructure so the stream is available at declaration time.

### Pattern A: Compute the stream source, then subscribe

Move the "which stream?" decision into its own step. The stream is resolved first, then hooks subscribe to it.

`useStreamSubscription` accepts `Stream<T>?` — null means no subscription. It also **re-subscribes automatically** when the stream reference changes (`useEffect` with `[stream]` internally). This means `useMemoizedIf` / `useMemoized` + `useStreamSubscription` compose naturally.

```dart
FetchState useFetchState({
  required int itemId,
  required FetchMode fetchMode,
  required bool isOffline,
}) {
  final repo = useInjected<ItemRepository>();
  final webRepo = useInjected<WebRepository>();
  final offlineRepo = useInjected<OfflineRepository>();

  // Step 1: resolve which stream source to use (async decision)
  final streamSource = useAutoComputedState(() async {
    if (isOffline) return StreamSource.offline;
    if (await _shouldFetchFromWeb()) return StreamSource.web;
    return StreamSource.api;
  }, keys: [isOffline, fetchMode]);

  // Step 2: create stream once source is known (null until resolved)
  final source = streamSource.valueOrNull;
  final stream = useMemoizedIf(source != null, () => switch (source!) {
    StreamSource.offline => offlineRepo.getCachedStream(ids: kids),
    StreamSource.web => webRepo.fetchStream(item),
    StreamSource.api => repo.fetchAllStream(ids: kids),
  }, [source]);

  // Step 3: accumulate — useStreamSubscription accepts null stream (no-op),
  // and re-subscribes when stream reference changes
  final items = useState<IList<Item>?>(null);
  useStreamSubscription(stream, (item) async {
    items.value = (items.value ?? const IList.empty()).add(item);
  });

  return FetchState(items: items.value);
}
```

### Pattern B: Pass the stream as a hook parameter

When the stream decision is simple, move it to the Page or main hook:

```dart
// Main hook decides, sub-hook subscribes
ScreenState useScreenState(...) {
  final stream = isOffline
    ? offlineRepo.getCachedStream(ids: kids)
    : apiRepo.fetchStream(ids: kids);

  final fetch = useFetchState(commentStream: stream);
  // ...
}

// Sub-hook receives stream — no dynamic creation needed
FetchState useFetchState({required Stream<Item> commentStream}) {
  final items = useState<IList<Item>?>(null);
  useStreamSubscription(commentStream, (item) async {
    items.value = (items.value ?? const IList.empty()).add(item);
  });
  return FetchState(items: items.value);
}
```

### Pattern C: Refresh vs Stream — choose the right primitive

BLoC cubits often mix pull-to-refresh with stream subscriptions. In hooks, these are **separate concerns** — don't combine them.

**If you need pull-to-refresh / pagination** — this is a sequence of Futures, not a stream. Use `useAutoComputedState` (or a paging wrapper):

```dart
final items = useAutoComputedState(
  () => repository.fetchItems(parentId),
  keys: [parentId],
);

// Pull-to-refresh: just re-trigger the computed state
void refresh() => items.refresh();
```

**If you have a stream** — you don't need refresh. The stream delivers data reactively. If the stream's source changes (e.g. `parentId` changes), hooks re-subscribe automatically via keys:

```dart
// Latest value — useMemoizedStream re-subscribes when keys change
final snap = useMemoizedStream(
  () => repository.streamItems(parentId),
  keys: [parentId],
);

// Accumulation — useMemoized creates stream, useStreamSubscription re-subscribes on change
final stream = useMemoized(() => repository.streamItems(parentId), [parentId]);
final items = useState<IList<Item>?>(null);
useStreamSubscription(stream, (item) async {
  items.value = (items.value ?? const IList.empty()).add(item);
});
```

**If the BLoC had both `init()` and `refresh()` doing nearly the same thing with streams** — that's a signal the original design was wrong. In hooks, the stream subscribes once (declaratively via keys). If you need "fresh data on user action", that's a Future (`useAutoComputedState` / `useSubmitState`), not a stream re-subscription.

---

## 4. Top-level mutable state → services

Complex cubits often have top-level mutable variables or `static` fields that act as cross-instance caches:

```dart
// BLoC: top-level globals shared across cubit instances
final Map<int, Map<int, Item>> _globalItemStates = {};
final Map<int, Story> _globalStoryCache = {};
static DateTime? _retryAfterDateTime;
static int _lockedItemId = 0;
```

**Rule:** These never stay as top-level variables in hook files. Each becomes either a service or global state.

### Cache → registered service

```dart
// Service: stateful, app-wide, no UI reactivity needed
class StoryCacheService {
  final _cache = <int, Story>{};
  Story? get(int id) => _cache[id];
  void put(int id, Story story) => _cache[id] = story;
}

// Register in DI (get_it), access in hook:
final storyCache = useInjected<StoryCacheService>();
```

### Cross-screen reactive state → global state via _providers

When other screens need to react to changes (e.g. collapse states that persist across screen pushes):

```dart
// See global-state-migration.md for full pattern
class CollapseStateManager {
  final _states = <int, Map<int, CollapseInfo>>{};
  void saveStates(int storyId, Map<int, CollapseInfo> states) { ... }
  Map<int, CollapseInfo>? getStates(int storyId) => _states[storyId];
}
// → register as service, or if reactive: global state via _providers
```

### Rate-limit / retry state → service field

```dart
// BLoC: static DateTime? _retryAfterDateTime;
// Hooks: move to the repository or a rate-limit service
class RateLimitService {
  DateTime? _retryAfter;
  bool get canRetry =>
    _retryAfter == null || DateTime.now().isAfter(_retryAfter!);
  void setRetryAfter(DateTime dateTime) => _retryAfter = dateTime;
}
```

### Simple lock state → service or useState (depending on scope)

```dart
// BLoC: static int _lockedCommentId = 0;

// If single-screen scope: just useState in the hook
final lockedItemId = useState(0);

// If cross-screen scope: register as service
class ItemLockService {
  int _lockedId = 0;
  void lock(int id) => _lockedId = id;
  void unlock() => _lockedId = 0;
  bool isLocked(int id) => _lockedId == id;
}
```

---

## 5. De-duplicating init() and refresh()

Complex cubits often have `init()` and `refresh()` that share 80%+ of their logic. This duplication is a signal that the cubit is mixing two concerns: **reactive data delivery** (stream) and **user-triggered data fetching** (pull-to-refresh). In hooks, these are different primitives.

### BLoC pattern (duplicated)

```dart
Future<void> init() async {
  emit(state.copyWith(status: loading));
  final stream = _buildCommentStream();      // 50 lines of stream selection
  _subscription = stream.listen(_onFetched)
    ..onDone(_onDone)
    ..onError(_onError);
}

Future<void> refresh() async {
  _preserveState();
  await _subscription?.cancel();
  emit(state.copyWith(status: loading, comments: []));
  final stream = _buildCommentStream();      // same 50 lines, duplicated
  _subscription = stream.listen(_onFetched)
    ..onDone(_onDone)
    ..onError(_onError);
}
```

### Hooks: separate the concerns

**Step 1: Ask — is refresh actually needed, or does the stream handle it?**

If data arrives via stream, the stream IS the refresh mechanism. There's no separate "refresh" — new data just arrives. The BLoC's `refresh()` was only needed because BLoC doesn't have declarative subscriptions.

**Step 2: If user-triggered refresh IS needed, it's a Future, not a stream.**

```dart
FetchState useFetchState({required int parentId}) {
  // Initial load — automatic, re-triggers when parentId changes
  final items = useAutoComputedState(
    () => repository.fetchItems(parentId),
    keys: [parentId],
  );

  // Pull-to-refresh — user-triggered, reuses the same computed state
  void refresh() => items.refresh();

  return FetchState(
    items: items.valueOrNull,
    isLoading: !items.isInitialized,
    refresh: refresh,
  );
}
```

No duplication. `init` = first render (automatic). `refresh` = `items.refresh()` (one line).

**Step 3: If you genuinely have both a stream AND refresh (rare) — separate them.**

The stream handles live updates. Refresh re-fetches the initial data. They don't share code:

```dart
FetchState useFetchState({required int parentId}) {
  // Initial + refresh via Future
  final initialItems = useAutoComputedState(
    () => repository.fetchItems(parentId),
    keys: [parentId],
  );

  // Live updates via stream (independent of refresh)
  final liveStream = useMemoized(() => repository.streamNewItems(parentId), [parentId]);
  final liveItems = useState<IList<Item>?>(null);
  useStreamSubscription(liveStream, (item) async {
    liveItems.value = (liveItems.value ?? const IList.empty()).add(item);
  });

  return FetchState(
    // Combine: initial data + live additions
    items: initialItems.valueOrNull?.addAll(liveItems.value ?? const IList.empty()),
    isLoading: !initialItems.isInitialized,
    refresh: () {
      liveItems.value = null;
      initialItems.refresh();
    },
  );
}
```

---

## 6. Navigation and UI callbacks in complex cubits

Complex cubits often call `router.push()`, `showSnackBar()`, `Overlay.of()`, or access `BuildContext` directly. This is the #1 violation that passes exit gate greps because there's no grep for it.

### BLoC pattern (navigation in cubit)

```dart
Future<void> loadParentThread() async {
  emit(state.copyWith(fetchParentStatus: loading));
  final parent = await repository.fetchItem(id: state.item.parent);
  if (parent != null) {
    await router.push(Paths.item, extra: ItemArgs(item: parent));  // ❌
  }
  emit(state.copyWith(fetchParentStatus: loaded));
}

void _onDone() {
  final rootContext = navigatorKey.currentContext;       // ❌
  rootContext.showSnackBar(content: '...');              // ❌
  Overlay.of(targetContext).insert(entry);               // ❌
}
```

### Hooks pattern (callbacks injected from Page)

```dart
// Page injects navigation and UI callbacks
class ItemPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useItemScreenState(
      navigateToItem: (item) => context.push(Paths.item, extra: ItemArgs(item: item)),
      showCompletionSnackbar: (count) => CrazyInfoSnackbar.show(context, '$count new items'),
      highlightItem: (key) => _startShine(context, key),
    );
    return ItemPageView(state: state);
  }
}

// Hook receives them as parameters — never touches BuildContext
ItemScreenState useItemScreenState({
  required void Function(Item) navigateToItem,
  required void Function(int count) showCompletionSnackbar,
  required void Function(GlobalKey) highlightItem,
}) {
  final loadParentState = useSubmitState();

  void loadParent() => loadParentState.runSimple<void, Never>(
    submit: () => repository.fetchItem(id: item.parent),
    afterSubmit: (parent) { if (parent != null) navigateToItem(parent); },
  );

  // ...
}
```

**Rule:** If you find `router.`, `Navigator.`, `context.push`, `context.pop`, `BuildContext`, `Overlay.`, `MediaQuery.`, `showSnackBar`, or `ScaffoldMessenger` in a state hook file — it must become a callback parameter injected from the Page.

---

## Checklist: Before writing a complex migration

Use this checklist after Phase 1 analysis, before starting Phase 2:

```
□ Domains identified — each domain becomes a sub-hook file
□ Shared state ownership assigned — one sub-hook owns each field, others receive it
□ Stream pattern chosen per stream — useMemoizedStreamData (default for complete values), or useState + useStreamSubscription (only if stream emits individual events to accumulate)
□ Dynamic stream creation restructured — stream available at declaration time via useMemoizedIf / useMemoized + keys
□ Top-level mutable state mapped — each global → service or useState (with scope justification)
□ init/refresh separated — stream = no refresh needed; pull-to-refresh = useAutoComputedState + .refresh()
□ Navigation/UI callbacks listed — each becomes a parameter on the main hook, injected from Page
□ No sub-hook file expected to exceed ~300 lines
□ No sub-hook expected to have >10 useState calls
□ State class expected to have <15 fields per sub-state
```
