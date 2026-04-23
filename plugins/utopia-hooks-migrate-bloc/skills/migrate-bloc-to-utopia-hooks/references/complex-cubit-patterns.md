---
title: Complex Cubit Migration Patterns
impact: HIGH
tags: complex, decomposition, streams, accumulation, dynamic-stream, global-state, migration
---

# Complex Cubit Migration Patterns

This reference covers patterns that appear **only in complex cubits** (>10 public methods, multiple streams, global mutable state, >300 estimated hook lines). Simple 1:1 mappings are in [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) — this file picks up where that one stops.

A complex cubit is identifiable by Phase 1b's complexity classification. If any indicator is "Complex", you will encounter patterns from this file. **Read this before Phase 2.**

---

## 0. Draw the ownership graph first, write code second

Before splitting a complex cubit into sub-hooks, draw the state-ownership graph on paper (or in plain text). Nodes = pieces of mutable state (e.g. `comments: IList<Comment>`, `expandedIds: ISet<int>`, `fetchStatus: Status`). Edges = reads and writes between hooks and state. The graph exists in your head anyway — write it down.

### Why

Three structural defects show up as graph properties, and are invisible until you draw it:

| Defect | Graph property |
|---|---|
| Shared writer (two hooks mutate the same field) | Multiple edges writing into one node |
| Callback upstream (sub-hook notifies parent via callback) | Edge from sub-hook to parent |
| Cycle (hook A writes to B, B writes to A) | Directed cycle |

The rule every complex decomposition must satisfy:

- **Single writer per mutable state node.** Readers are fine; writers are not.
- **Edges point downstream only.** Parent → sub-hook inputs. Sub-hook → parent outputs (values, not callbacks).
- **No cycles.** If two hooks need to coordinate, the parent coordinates them — not each other.

### How to draw it

For a cubit with ~1200 LOC and ~24 public methods, the graph is ~6-10 nodes. List them, then for each method note: which nodes it reads, which it writes. Group by writer — each node should end up with exactly one writing hook.

```
comments: IList<Comment>
  WRITES: fetch (stream emissions, refresh, loadMore)
  READS:  collapse (for applyCollapseStates), search (for filtering), scroll (for indexOf)

expandedIds: ISet<int>
  WRITES: collapse (toggleCollapse)
  READS:  collapse, fetch (to annotate re-fetched items)   ← STOP. Two readers is fine.
                                                            A writer that is also a reader is fine.
                                                            But if fetch also WROTE to expandedIds,
                                                            that would be a shared-writer defect.
```

If a node has two writers, redesign before writing code — often one of the "writers" is actually doing a derivation that belongs in a `useMemoized` read. If a sub-hook has an outgoing callback to the parent, restructure to value-return + parent-side effect.

### When the graph is wrong

Defects visible in the graph map to concrete rnd-validated corrections:

- Two writers on `comments` → move the derivation into `useMemoized` at the parent, keeping one true writer
- Sub-hook A calls into sub-hook B (edge A→B) → invert: parent reads A's output, passes it to B as input
- Cycle fetch ↔ collapse → one of them is misplaced; often the cross-cutting concern (e.g. lifecycle preserve) belongs at the parent, not inside either sub-hook

Phase 4 (exit gate) also checks the graph — once during Phase 1 to design, once at handoff to verify no drift.

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

### Is any of this state per-item?

Before drawing screen sub-hooks, ask: **is any of this state per-item?** Per-tile expansion flags, per-item async loads, per-item drafts / validators / resources (GlobalKeys, animation controllers, progress indicators) — none of these belong in screen sub-hooks. They have their own natural scope (one per list item) that matches a widget, not the screen.

See [`composable-hooks.md` → "Per-item state: three archetypes"][per-item] for the decision tree:
- Widget-level Pattern 1 when item is self-contained (parent just wants "done")
- Composed hook called N times (fixed N) or `useMap<Key, useX>` (dynamic N) when parent aggregates
- Screen-state `Map<Key, Flag>` only for trivial single-flag cases

[per-item]: ../../../../utopia-hooks/skills/utopia-hooks/references/composable-hooks.md

Pulling per-item state out of the screen state before drawing sub-hooks often shrinks the screen's surface by 20-40% and removes whole categories of cross-domain coupling (e.g. "fetch needs to know each tile's expansion" disappears because the tile owns its own expansion).

---

## 2. Streams in complex cubits

Streams fall into two shapes by source — the shape dictates the hook:

| Source shape | Each emission | Hook |
|---|---|---|
| **Complete-state** (Firestore query, Stream.io feed, SQL observer, BehaviorSubject) | Full list/object/snapshot | `useMemoizedStream` / `useMemoizedStreamData` |
| **Per-item** (recursive fetch, paged scraper, Firebase-per-document, file-by-file watcher) | One item | `useStreamSubscription` + `useState<IList<T>?>` accumulator (see below) |

Both shapes are legitimate — match the hook to the source. Don't "fix" accumulation if the API genuinely produces per-item emissions, and don't force per-item handling onto a complete-state source.

**Complete-state** — pass to View, no side effects needed:

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

### Stream accumulation — per-item sources

Per-item APIs emit individual items one by one — a recursive fetch yielding each resolved item, a paged scraper yielding each parsed element, a Firebase-per-document API that returns one doc at a time, a watcher emitting each new event. The hook accumulates into a list. This is not a code smell when the API genuinely produces per-item emissions — it's the right pattern for that source shape.

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

### ⚠️ Do not derive from reactive inputs inside the emission handler

A common bug class migrated from BLoC: annotating each emitted item with a flag derived from a reactive input.

```dart
// ❌ Freezes filter.keywords at emission time
useStreamSubscription(commentStream, (comment) async {
  final hidden = filter.keywords.any(  // reads filter.keywords ONCE per emission
    (kw) => comment.text.toLowerCase().contains(kw),
  );
  items.value = items.value.add(comment.copyWith(hidden: hidden));
});
```

If `filter.keywords` changes later, already-emitted items keep the old `hidden` flag. The filter is stale for the lifetime of the list.

**Fix:** store raw items in the stream handler; derive the annotated list at the parent via `useMemoized` with the reactive input as a key:

```dart
// ✅ Re-derives when filter.keywords changes
useStreamSubscription(commentStream, (comment) async {
  items.value = items.value.add(comment);  // raw
});

// At parent (or even same hook if appropriate):
final annotated = useMemoized(
  () => items.value.map((c) => c.copyWith(
    hidden: filter.keywords.any((kw) => c.text.toLowerCase().contains(kw)),
  )).toList(),
  [items.value, filter.keywords],
);
```

Rule: if `copyWith(flag: derivedFromReactive)` appears inside a stream handler, move the derivation out.

### `stream.forEach` for one-shot await-on-done

When you need a `Future<void>` that completes when the stream is done (e.g. the "finish loading replies" button is disabled until kids are fully loaded), use `await stream.forEach(action)` — not `listen() + Completer + onDone(completer.complete)`.

```dart
// ✅ Natural Future<void>
Future<void> loadKids(Item parent) async {
  int offset = 0;
  await repository.fetchCommentsStream(ids: parent.kids)
      .asyncMap(buildable.toBuildableComment)
      .whereNotNull()
      .forEach((cmt) {
    items.value = items.value.insert(parent, cmt, offset++);
  });
  // stream done — future resolves here
}
```

No Completer. No manual subscription tracking. Use when the call-site wants `.runSimple(submit: loadKids)` progress via `useSubmitState`.

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

### Pattern A (extended): Multi-await setup before the stream

The pattern above works when the "which stream?" decision is synchronous (a connectivity check suffices). Real cubits often require several awaits before the stream can even be constructed — `await collapseState.initializeForStory(item)`, `await repo.fetchItem(id)` to get an updated item, `await connectivity.check()` for the web-vs-api decision, etc. The stream factory in these cases also needs the resolved metadata (e.g. `updatedItem.descendants` to decide when the stream is "done enough" to cache).

The urge is to write an imperative `useEffect` with `unawaited(() async {...}())` + a `cancelled` flag + a nullable `StreamSubscription?` — don't. Wrap the async setup + the stream + the metadata in a single record, return it from `useAutoComputedState`, then subscribe with `useStreamSubscription`.

```dart
class _FetchPlan {
  const _FetchPlan({required this.stream, required this.updatedItem});
  final Stream<Comment?> stream;
  final Item updatedItem;
}

final planState = useAutoComputedState<_FetchPlan>(() async {
  await collapseState.initializeForStory(item: item.value, prefs: ...);
  final updatedItem = await repo.fetchItem(id: item.value.id) ?? item.value;
  final stream = _pickStream(updatedItem, fetchMode, order, webAllowed);
  return _FetchPlan(stream: stream, updatedItem: updatedItem);
}, keys: [item.value.id, fetchMode, order, webAllowed, refreshTrigger.value]);

// useStreamSubscription accepts null (while useAutoComputedState resolves),
// and re-subscribes when planState produces a new plan.
useStreamSubscription(
  planState.valueOrNull?.stream,
  (Comment? c) => onCommentReceived(c),
  onDone: () {
    final plan = planState.valueOrNull;
    if (plan == null) return;
    // onDone closure captures the plan — access updatedItem here:
    if (items.value.length >= plan.updatedItem.descendants) {
      cacheService.put(plan.updatedItem.id, plan.updatedItem);
    }
    status.value = Status.allLoaded;
  },
  onError: (e, _) => /* error handling */,
);
```

`useAutoComputedState`'s built-in `CancelableOperation` handles cancellation on deps change — no `cancelled` flag needed. The `_FetchPlan` record carries the companion metadata that `onDone` needs.

For an immediate sync reset on deps change (clear the items list while async setup is pending) use a small sibling `useEffect` keyed on the same inputs — it runs synchronously so the UI flashes "empty / inProgress" immediately rather than waiting for the async setup.

### Pattern B: Pass the stream as a hook parameter

When the stream decision is simple, move it to the Screen or main hook:

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

### Reactive inputs vs. mutators

Before de-duplicating, spot a related smell: **`updateX(T)` methods that change a configuration flag and then trigger re-fetch.**

```dart
// BLoC: "mutator" that is actually a reactive input in disguise
void updateOrder(CommentsOrder newOrder) {
  if (newOrder == state.order) return;
  emit(state.copyWith(order: newOrder, comments: []));
  _subscription?.cancel();
  init();  // re-fetch with new order
}

void updateFetchMode(FetchMode newMode) { /* same shape */ }
```

These methods look like actions but they're **configuration parameters**. Don't migrate them as sub-hook methods. The hook shape is: aggregator owns the config as `MutableValue<T>`, passes the snapshot to the fetch sub-hook, and the sub-hook's reactive `useEffect`/`useAutoComputedState` re-runs automatically when the key changes.

```dart
// ✅ Aggregator owns config; sub-hook takes snapshot as input
ScreenState useScreenState(...) {
  final order = useState(defaultOrder);
  final fetchMode = useState(defaultFetchMode);

  final fetch = useFetchState(
    order: order.value,           // reactive input
    fetchMode: fetchMode.value,   // reactive input
    // ...
  );

  // Changing order is just a setter; fetch re-fetches via its own keys
  return ScreenState(
    setOrder: (o) => order.value = o,
    setFetchMode: (m) => fetchMode.value = m,
    // ...
  );
}

// Sub-hook — no updateOrder / updateFetchMode methods
FetchState useFetchState({required CommentsOrder order, required FetchMode fetchMode, ...}) {
  useAutoComputedState(
    () => _fetchForConfig(order, fetchMode, ...),
    keys: [order, fetchMode, ...],  // re-runs automatically
  );
  // ...
}
```

Rule: when the cubit has `updateX(T newX)` that emits+refetches, migrate `X` as a `MutableValue<T>` at the aggregator. The sub-hook doesn't need an `updateX` method — the reactive key handles it.

Signals that flag this pattern in the cubit:
- Method body: `if (newX == state.x) return; emit(...); init()` or `...stream re-subscribe`
- The "mutator" name starts with `update*` or `change*` or `set*`
- Removing the mutator breaks nothing except the one caller that sets the flag

If you find `updateFetchMode`, `updateOrder`, `loadAll`, `changeFilter` etc. with this shape — they become reactive inputs, not sub-hook methods. This alone often shrinks a ported sub-hook by 100-200 LOC.

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

### Hooks pattern (callbacks injected from Screen)

```dart
// Screen injects navigation and UI callbacks
class ItemScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useItemScreenState(
      navigateToItem: (item) => context.push(Paths.item, extra: ItemArgs(item: item)),
      showCompletionSnackbar: (count) => CrazyInfoSnackbar.show(context, '$count new items'),
      highlightItem: (key) => _startShine(context, key),
    );
    return ItemScreenView(state: state);
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

**Rule:** If you find `router.`, `Navigator.`, `context.push`, `context.pop`, `BuildContext`, `Overlay.`, `MediaQuery.`, `showSnackBar`, or `ScaffoldMessenger` in a state hook file — it must become a callback parameter injected from the Screen.

### ⚠️ Silent void-discard from callback parameters

When migrating a cubit callback that's typed `void Function(X)`, inspect what the call-site lambda actually returns. Dart silently discards return values in void contexts, so this compiles but quietly does nothing:

```dart
// BLoC cubit exposes:  void Function(Comment) uncollapse;
// Call-site wires it like this — lambda returns a List<Comment>,
// but the callback type is void, so Dart throws the return away.
uncollapse: (Comment c) => state.collapse.uncollapse(state.comments, c),
//                                                      ^ returns List<Comment>
//                                                      discarded silently
```

The uncollapse call has no effect — a latent bug that passes analyzer and tests. When migrating, check every `void Function(X)` parameter whose call-site builds a lambda from a non-void-returning function. If the return carries data, either (a) the callback type should be `R Function(X)`, or (b) the return is being used incorrectly and should be explicitly applied at the call site.

---

## 7. Self-review smells

Catch these during Phase 3 self-review (after Phase 2 migration, before Phase 4 exit gate):

### Top-level `_helpers()` trailing a state file

If after moving logic into the aggregator you find yourself with `_foo()` / `_bar()` / `_baz()` top-level private functions at the end of a `*_state.dart` file — that's **relocation debt**. The helpers operate on some piece of state; they belong inside the sub-hook that owns that state, exposed as a method.

```dart
// ❌ Trailing helpers
ScreenState useScreenState(...) { /* 200 lines */ }
Rect? _getWidgetRect(GlobalKey k) { ... }        // Used only by _startShine
void _startShine(BuildContext c, GlobalKey k) {  // Used only from scrollToComment
  // needs scroll.globalKeys lookup too
}

// ✅ Moved into the sub-hook whose data they use
// _getWidgetRect stays file-private in comments_scroll_state.dart
// startShineOn becomes a method on CommentsScrollState:
class CommentsScrollState {
  final void Function(int commentId) startShineOn;
  // ...
}
```

Signal: a top-level `_fn()` reads from a shared map (`globalKeys`, `itemStates`) or invokes a service. That's the sub-hook's territory.

---

## Checklist: Before writing a complex migration

Use this checklist after Phase 1 analysis, before starting Phase 2:

```
□ Ownership graph drawn — nodes (mutable state), edges (reads/writes between hooks)
□ Single writer per node verified — no shared writers
□ Graph is acyclic — no cycles between sub-hooks
□ No callback-upstream edges — sub-hooks return values, not callbacks to the parent
□ Per-item state pulled out — per-tile expansion / async / resources → widget-level Pattern 1
□ Domains identified (after per-item removal) — each domain becomes a sub-hook file
□ Shared state ownership assigned — one sub-hook owns each field, others receive it
□ `updateX(T)` methods reclassified as reactive inputs — not sub-hook methods
□ Stream pattern chosen per stream — useMemoizedStreamData (default for complete values), or useState + useStreamSubscription (only if stream emits individual events to accumulate)
□ Dynamic stream creation restructured — stream available at declaration time via useMemoizedIf / useMemoized + keys; multi-await setup uses useAutoComputedState<_Plan>
□ Top-level mutable state mapped — each global → service or useState (with scope justification)
□ init/refresh separated — stream = no refresh needed; pull-to-refresh = useAutoComputedState + .refresh()
□ Navigation/UI callbacks listed — each becomes a parameter on the main hook, injected from Screen
□ No sub-hook file expected to exceed ~300 lines
□ No sub-hook expected to have >10 useState calls
□ State class expected to have <15 fields per sub-state
□ No top-level `_helpers()` planned for the state file — each helper has a home in a sub-hook
```

---

## Golden examples

Concrete reference shapes for the patterns in this file live in the foundation skill at `utopia-hooks:references/complex-state-examples.md`. When a section here describes a shape abstractly, the reference file shows the full anonymised code sketch. Use it for "what does good look like?" after reading the patterns. (The examples live in `utopia-hooks` rather than here because the shapes apply to new screens too, not only migrations.)
