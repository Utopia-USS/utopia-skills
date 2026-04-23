---
title: Post-Migration Refactor Checklist
impact: HIGH
tags: migration, refactor, post-migration, consolidation, sub-hooks, aggregator, cleanup
---

# Post-Migration Refactor Checklist

**When to use:** After the first-pass migration of a Complex screen is committed and the exit gate passes. This checklist catches **the class of bloat that exit-gate greps don't see** — semantic misplacement of state across the sub-hook boundary, not syntactic BLoC leftovers.

**What it is:** A set of 12 named anti-patterns derived from an empirical refactor sweep on a real migrated codebase (§A–§D: 11 from sub-hook/aggregator level; §E: 1 from Screen file level). Each anti-pattern has:

1. A **grep-shape** for mechanical detection,
2. A **fix pattern** with before/after,
3. The **expected LoC delta** (observed in the reference sweep).

A single refactor pass applying all 12 on a 3 500-LoC screen subtree removed ~500 LoC of sub-hook coordination and (if §E1 hits) another ~200 LoC from the Screen file — producing a lean aggregator-owns-coordination shape + a thin Screen. See the "reference sweep" metrics at the bottom.

**This is not a migration step.** Migration is 4 phases (analysis → migration → self-review → exit gate). This checklist is a **5th, separate, post-migration pass** — review the already-migrated code with fresh eyes against these 12 shapes. Skipping it means shipping a "parallel Cubit in hook clothes" instead of idiomatic hooks.

---

## How to run the pass

1. Open the migrated screen's `state/` directory.
2. For each `*_state.dart` that is a **sub-hook** (not the aggregator), walk the 11 anti-patterns below. Each one is checked independently.
3. For each hit: apply the fix pattern. **Commit per anti-pattern**, not per screen — granularity is the safety net (see "Why per-anti-pattern commits" below).
4. After all sub-hooks are clean, run the "Aggregator hygiene" section (§D).
5. Re-run the exit gate from [screen-migration-flow.md Phase 4](./screen-migration-flow.md#phase-4-per-screen-exit-gate).

---

## §A. Hoist cross-cutting coordination UP to the aggregator

Sub-hooks should own a single domain. Cross-cutting logic — lifecycle, navigation, coordination across multiple sub-hooks — does not belong in a sub-hook because it **couples** that sub-hook to the others. The aggregator is the correct home.

### A1. Lifecycle stream subscription in a sub-hook

**Grep-shape:**
```bash
grep -n 'useStreamSubscription.*[Ll]ifecycle\|useStreamSubscription.*appState\|AppLifecycleService' <sub_hook_file>
```

**Why it's wrong:** lifecycle is a cross-cutting concern (applies to multiple sub-hooks' data — e.g. "on inactive, preserve collapse state AND flush pending writes"). If the subscription lives in one sub-hook, the other sub-hook has to thread a callback in, creating an upstream edge (see [complex-cubit-patterns.md §0](./complex-cubit-patterns.md#0-draw-the-ownership-graph-first-write-code-second)).

**Fix:** move `useStreamSubscription(lifecycle.stream, ...)` to the aggregator. The aggregator reads sub-hook outputs (e.g. `fetch.comments`, `collapse.stateMap`) and passes them to the coordinating side-effect.

```dart
// ❌ Before — in sub-hook
CommentsFetchState useCommentsFetchState(...) {
  final lifecycle = useInjected<AppLifecycleService>();
  useStreamSubscription(lifecycle.stream, (s) {
    if (s == AppLifecycleState.inactive) preserveCollapseState();  // couples to collapse
  });
  // ...
}

// ✅ After — in aggregator
CommentsScreenState useCommentsState(...) {
  final lifecycle = useInjected<AppLifecycleService>();
  final fetch = useCommentsFetchState(...);
  final collapse = useCommentsCollapseState();

  void preserveNow() => collapse.preserveCollapseState(
    item: fetch.item, comments: fetch.comments, /* ... */
  );

  useStreamSubscription(
    lifecycle.stream.where((s) => s == AppLifecycleState.inactive),
    (_) => preserveNow(),
  );
  // ...
}
```

**Reference sweep delta:** −30 LoC per affected sub-hook.

---

### A2. Navigation callback in a sub-hook

**Grep-shape:**
```bash
grep -n 'onNavigateTo\|navigateTo\|context\.push\|context\.pop\|context\.go(\|router\.' <sub_hook_file>
```

**Why it's wrong:** navigation is a Screen-level concern (BuildContext bound). A sub-hook that takes `onNavigateToItem` as a parameter **leaks Screen responsibility two levels down** — the aggregator has to accept it from Screen and thread it into the sub-hook. One level of indirection is bearable; two is drift.

**Fix:** navigation callback is injected **only into the aggregator** from the Screen. The sub-hook returns the data needed for navigation (`Item parent`, `Story root`) — the aggregator wraps the call in `useSubmitState.runSimple` and invokes `onNavigateToItem(parent)` in `afterSubmit`.

```dart
// ❌ Before — sub-hook receives navigation
FetchState useCommentsFetchState({
  required void Function(Item) onNavigateToParent,  // ← leaked
  // ...
}) {
  Future<void> loadParentThread() async {
    final parent = await repo.fetchItem(id: item.parent);
    if (parent != null) onNavigateToParent(parent);  // ← navigation 2 levels down
  }
  // ...
}

// ✅ After — navigation at aggregator only
CommentsScreenState useCommentsState({
  required void Function(Item) onNavigateToItem,  // ← Screen injects here, not deeper
  // ...
}) {
  final fetch = useCommentsFetchState(...);       // no navigation param
  final parentNavSubmit = useSubmitState();

  Future<void> loadParentThread() => parentNavSubmit.runSimple<void, Never>(
    submit: () async {
      final parent = await hnRepo.fetchItem(id: fetch.item.parent);
      if (parent != null) onNavigateToItem(parent);
    },
  );
  // ...
}
```

Cross-ref: [complex-cubit-patterns.md §6 "Navigation and UI callbacks"](./complex-cubit-patterns.md#6-navigation-and-ui-callbacks-in-complex-cubits) — this is the per-sub-hook variant of that rule.

**Reference sweep delta:** −15 to −40 LoC per affected sub-hook (depending on how many navigations were leaked).

---

### A3. Sub-hook method that coordinates multiple sub-hooks

**Grep-shape:** visual audit. Red flag: a method on sub-hook S that reads/writes state of sub-hooks T and U. Typical names: `scrollToX`, `jumpToY`, `expandAndScrollTo`, `searchAndFocus`.

**Why it's wrong:** a method on `scroll` sub-hook that ALSO collapses ancestors (from `collapse`) AND reads `fetch.comments` crosses three domains. The method is a **coordinator**, not a scroll primitive. Sub-hook `scroll` ends up with import dependencies on `collapse` and `fetch` — or worse, takes them as parameters, producing an upstream/cross edge in the ownership graph.

**Fix:** pure primitives stay in the sub-hook (`scroll.itemScrollController.scrollTo(index: N)`). The coordinating method moves to the aggregator, where `fetch.comments`, `collapse.uncollapse`, and `scroll.scrollTo` are all in reach.

```dart
// ❌ Before — scroll sub-hook owns coordination
CommentsScrollState useCommentsScrollState({
  required List<Comment> comments,                // ← crosses into fetch domain
  required List<Comment> Function(List<Comment>, Comment) uncollapse,  // ← crosses into collapse
}) {
  Future<void> scrollToComment(Comment c) async {
    // uncollapse ancestors, then scroll, then glow — all cross-domain
  }
  return CommentsScrollState(scrollToComment: scrollToComment, ...);
}

// ✅ After — scroll sub-hook is a primitive
CommentsScrollState useCommentsScrollState() {
  final ctrl = useMemoized(ItemScrollController.new);
  return CommentsScrollState(itemScrollController: ctrl, /* primitives only */);
}

// Aggregator owns scrollToComment
CommentsScreenState useCommentsState(...) {
  final fetch = useCommentsFetchState(...);
  final collapse = useCommentsCollapseState();
  final scroll = useCommentsScrollState();

  Future<void> scrollToComment(Comment target) async {
    // uncollapse ancestors using collapse.uncollapse
    // scroll using scroll.itemScrollController
    // glow using scroll.startShineOn
    // all three in reach here
  }
  // ...
}
```

**Reference sweep delta:** −200 LoC in the reference sweep's scroll sub-hook (289 → 78). The single biggest anti-pattern by LoC.

---

### A4. Reactive input stored as `useState` in a sub-hook

**Grep-shape:**
```bash
grep -n 'useState<\(CommentsOrder\|FetchMode\|SortMode\|FilterType\)>' <sub_hook_file>
```

**Why it's wrong:** config flags like `order`, `fetchMode`, `filter` are **reactive inputs** to data-fetching, not sub-hook-owned state. If `useState<CommentsOrder>` lives in the fetch sub-hook, the aggregator has to expose a setter that reaches into the sub-hook — there's no clean handle for "change this config and re-fetch."

**Fix:** the aggregator owns the config as `useState<T>`; the sub-hook takes a **snapshot** `T` as a parameter. `useAutoComputedState` / `useEffect` keys inside the sub-hook re-run when the snapshot changes. The setter is just `configState.value = newValue`.

```dart
// ❌ Before — config lives in sub-hook
FetchState useCommentsFetchState(...) {
  final order = useState(CommentsOrder.natural);

  void updateOrder(CommentsOrder o) {
    if (o == order.value) return;
    order.value = o;
    subscription?.cancel();
    refetch();  // manual re-trigger
  }

  return FetchState(order: order.value, updateOrder: updateOrder, /* ... */);
}

// ✅ After — config at aggregator, sub-hook takes snapshot
ScreenState useScreenState(...) {
  final order = useState(defaultOrder);
  final fetch = useCommentsFetchState(order: order.value, /* ... */);  // reactive key
  return ScreenState(
    order: order.value,
    onOrderChanged: (o) => order.value = o,  // one-liner
    /* ... */
  );
}

FetchState useCommentsFetchState({required CommentsOrder order}) {
  useAutoComputedState(() => repo.fetch(order: order), keys: [order]);
  // re-fetches automatically when order changes
}
```

Cross-ref: [complex-cubit-patterns.md §5 "Reactive inputs vs. mutators"](./complex-cubit-patterns.md#reactive-inputs-vs-mutators). This checklist item is the post-migration version — catches cases where §5 was missed during migration.

**Reference sweep delta:** −40 to −80 LoC per config flag (removes the `updateX` method + its coordination).

---

## §B. Hoist per-item state DOWN to widget-level hooks

Per-item state (per-tile expansion, per-item async, per-comment resources) does not belong in screen sub-hooks — its natural scope is one-per-widget. Keeping it in a sub-hook creates `Map<Key, X>` fields that grow linearly with list size and force the sub-hook to be an item-registry.

### B1. `Map<Key, Resource>` in a sub-hook for per-item UI resources

**Grep-shape:**
```bash
grep -nE 'Map<int, GlobalKey|Map<\w+, AnimationController|Map<\w+, FocusNode|Map<\w+, TextEditingController' <sub_hook_file>
```

**Why it's wrong:** `Map<int, GlobalKey>` in a scroll sub-hook means the sub-hook registers a key per comment — the registry grows unboundedly and forces the widget to call back into the sub-hook to register. The widget should own its own key.

**Fix:** move the resource into a widget-level hook (see [composable-hooks.md Pattern 1](../../../../utopia-hooks/skills/utopia-hooks/references/composable-hooks.md#pattern-1-widget-level-hook)). The sub-hook keeps only aggregate operations (e.g. "scroll to index N"); the widget owns its `GlobalKey`.

```dart
// ❌ Before — scroll sub-hook owns Map<int, GlobalKey>
CommentsScrollState useCommentsScrollState() {
  final globalKeys = useState(<int, GlobalKey>{});
  void registerKey(int id, GlobalKey k) => globalKeys.value[id] = k;
  return CommentsScrollState(globalKeys: globalKeys.value, registerKey: registerKey);
}

// ✅ After — CommentTile owns its key
class CommentTile extends HookWidget {
  Widget build(BuildContext context) {
    final state = useCommentTileState(comment: comment);
    return Container(key: state.globalKey, /* ... */);
  }
}
```

Cross-ref: [composable-hooks.md "Per-item state: three archetypes"](../../../../utopia-hooks/skills/utopia-hooks/references/composable-hooks.md#per-item-state-three-archetypes).

**Reference sweep delta:** −20 to −50 LoC in the sub-hook + cleaner widget.

---

### B2. `useSubmitState` for a per-item action in a sub-hook

**Grep-shape:**
```bash
grep -nE 'useSubmitState.*loadMore|useSubmitState.*expand|useSubmitState.*fetch\w+Item|Map<\w+, MutableSubmitState' <sub_hook_file>
```

**Why it's wrong:** if "load more replies to comment X" is tracked via a single `MutableSubmitState` in the fetch sub-hook, then clicking "load more" on comment A shows a spinner on comment B too (shared `inProgress` flag). The fix in the sub-hook is a `Map<CommentId, MutableSubmitState>` — unbounded, same problem as B1.

**Fix:** the submit state is per-item → widget-level hook. Each `CommentTile` calls `useSubmitState` in its own hook; the sub-hook exposes `loadMore(comment)` as a plain `Future<void> Function(Comment)`.

```dart
// ❌ Before — single shared inProgress in sub-hook
FetchState useCommentsFetchState(...) {
  final loadMoreSubmit = useSubmitState();  // shared for ALL comments
  Future<void> loadMore(Comment c) => loadMoreSubmit.runSimple(submit: () => /* ... */);
  return FetchState(loadMore: loadMore, isLoadingMore: loadMoreSubmit.inProgress);
}

// ✅ After — per-tile submit state
class CommentTile extends HookWidget {
  Widget build(BuildContext context) {
    final loadMore = useSubmitState();
    return LoadMoreButton(
      onTap: () => loadMore.runSimple(submit: () => state.loadMoreFor(comment)),
      isLoading: loadMore.inProgress,
    );
  }
}
```

**Reference sweep delta:** −10 to −30 LoC in the sub-hook, fixes the shared-spinner UX bug.

---

## §C. Replace mutable state with derived state

A field that is a pure function of other state should be `useMemoized`, not `useState` with manual updates. Mutable mirrors of derived data are the top source of sync bugs.

### C1. `copyWith(flag: derivedFromReactive)` inside a stream/handler

**Grep-shape:**
```bash
grep -nE '\.copyWith\([^)]*\b(filter|search|config)\w*' <sub_hook_file>
```

**Why it's wrong:** annotating each emitted item with a flag derived from a reactive input (`filter.keywords`, `search.query`) **freezes the flag at emission time**. If the input changes later, already-emitted items keep the old flag.

**Fix:** store raw items in the emission handler; derive the annotated list at the aggregator via `useMemoized` with the reactive input as a key.

See [complex-cubit-patterns.md §2 "Do not derive from reactive inputs inside the emission handler"](./complex-cubit-patterns.md#-do-not-derive-from-reactive-inputs-inside-the-emission-handler) for full pattern. This checklist item catches the case where migration preserved the BLoC's emission-time derivation by mistake.

**Reference sweep delta:** −10 LoC + fixes a latent staleness bug.

---

### C2. `MutableValue<T>` for pure derivation

**Grep-shape:**
```bash
# Any useState<X> / useState<Y> where X, Y are Map/Set/derived types
grep -nE 'useState<Map<|useState<int>\s*\(\s*0\s*\).*level|useState<\w+Map' <sub_hook_file>
```

Visual cue: a `MutableValue<T>` that is **updated every time** other state changes — always in sync with its inputs. That's `useMemoized`, not `useState`.

**Fix:**
```dart
// ❌ Before — idMap mirrors comments; updated on every setComments
final comments = useState<List<Comment>>([]);
final idMap = useState<Map<int, Comment>>({});
void setComments(List<Comment> c) {
  comments.value = c;
  idMap.value = { for (final cmt in c) cmt.id: cmt };  // always derived
}

// ✅ After — idMap is memoized
final comments = useState<List<Comment>>([]);
final idMap = useMemoized(
  () => { for (final c in comments.value) c.id: c },
  [comments.value],
);
```

Same for `maxLevel`, `totalCount`, `filteredX`, etc. — anything whose only update site is "whenever input changes."

**Reference sweep delta:** −5 to −15 LoC per derivation + eliminates the class of bug where the mirror drifts from the source.

---

### C3. Manual `StreamSubscription` via `useState<StreamSubscription?>`

**Grep-shape:**
```bash
grep -nE 'useState<StreamSubscription|useState<\w*Subscription\?>|subscription\.cancel\(\)' <sub_hook_file>
```

**Why it's wrong:** `.listen()` + manual `.cancel()` in a hook file is a BLoC pattern that slipped through. `useStreamSubscription` handles subscribe/cancel + re-subscribe on key change.

**Fix:** for **complete-state streams** → `useMemoizedStream` / `useMemoizedStreamData`. For **per-item accumulation streams** → `useStreamSubscription` with an accumulator `useState<IList<T>?>`. For **async-setup + stream** → `useAutoComputedState<_Plan>` returning the stream + metadata, then `useStreamSubscription` on `plan.valueOrNull?.stream`.

See [complex-cubit-patterns.md §2 and §3](./complex-cubit-patterns.md#2-streams-in-complex-cubits) for the full pattern matrix.

**Reference sweep delta:** −30 to −100 LoC per stream (removes the lifecycle bookkeeping).

---

### C4. Counter-as-trigger (`refreshTrigger.value++` in keys)

**Grep-shape:**
```bash
grep -nE 'useState<int>\([^)]*\)[^;]*\b(refresh|reload|trigger|bump|tick|version)' <state_file>
grep -nE '\b(refresh|reload|trigger|bump|tick|version)\w*\.value\s*\+\+' <state_file>
```

**Why it's wrong:** this is the Cubit-emit mindset leaking through. `useAutoComputedState` returns a `MutableComputedState` with a native `.refresh()`. A counter in `keys` is a reimplementation of `.refresh()` with strictly worse ergonomics — the counter carries no information (only "something happened"), hides fan-out in the reactivity graph, and the first conditional in the refresh handler forces a rewrite anyway.

**Fix:** see [async-patterns.md — Anti-pattern: counter-as-trigger](../../../../utopia-hooks/skills/utopia-hooks/references/async-patterns.md#anti-pattern-counter-as-trigger). Imperative refresh → `.refresh()`; reactive refresh → key on a real domain value.

**Reference sweep delta:** −10 to −20 LoC per occurrence; the real value is architectural — removing the counter is the signal that the migrator reframed "Cubit emit" into "hook reactive computation".

---

## §D. Aggregator hygiene

After §A + §B + §C, the aggregator has grown (it now owns what sub-hooks used to). The following rules keep the aggregator readable.

### D1. Collapse straight pass-throughs to getter-delegates

**Grep-shape:**
```bash
# Count required fields vs getter-delegates in aggregator State class
grep -cE '^\s*required this\.' <aggregator_state_file>
grep -cE '^\s*\w+ get \w+ =>' <aggregator_state_file>
```

**Why it matters:** if the aggregator has sub-state fields (`final CommentsFetchState fetch;`) AND also declares `final Item item;` that's just `fetch.item` — that's a straight pass-through. Each such field costs ~5 LoC (declaration + constructor `required` + assignment `item: fetch.item`) for no added value.

**Fix:** keep the sub-state as a field; expose the pass-through as a getter.

```dart
// ❌ Before — 15 LoC per pass-through
class CommentsScreenState {
  const CommentsScreenState({
    required this.fetch,
    required this.item,
    required this.comments,
    required this.idToCommentMap,
    required this.maxLevel,
    // ... 25 more required fields, many are pass-throughs ...
  });
  final CommentsFetchState fetch;
  final Item item;
  final List<Comment> comments;
  final Map<int, Comment> idToCommentMap;
  final int maxLevel;
  // ...
}

// Hook:
return CommentsScreenState(
  fetch: fetch,
  item: fetch.item,                 // pass-through
  comments: fetch.comments,         // pass-through
  idToCommentMap: fetch.idToCommentMap,
  maxLevel: fetch.maxLevel,
  // ...
);

// ✅ After — getter-delegates for pass-throughs, required only for cross-cutting
class CommentsScreenState {
  const CommentsScreenState({
    required this.fetch,
    required this.collapse,
    required this.scroll,
    required this.search,
    required this.comments,          // aggregator-owned (merged + filter applied)
    required this.order,
    required this.refresh,
    required this.loadParentThread,
    required this.scrollToComment,
    // only ~10-15 cross-cutting fields
  });

  final CommentsFetchState fetch;
  final CommentsCollapseState collapse;
  final CommentsScrollState scroll;
  final CommentsSearchState search;
  final List<Comment> comments;
  // ...

  Item get item => fetch.item;                              // pass-through
  Map<int, Comment> get idToCommentMap => fetch.idToCommentMap;
  int get maxLevel => fetch.maxLevel;
  // ...
}
```

**Heuristic:** a `required` field on the aggregator should be **either** a sub-state **or** aggregator-owned cross-cutting data/action. If it's `fetch.X` written verbatim → getter.

**Reference sweep delta:** −80 to −200 LoC on bloated aggregators (constructor args + field declarations + passthrough assignments all collapse).

---

### D2. No top-level `_helpers()` at the end of a state file

**Grep-shape:**
```bash
# Top-level functions after the main hook function
grep -nE '^(Future<\w+>|void|bool|int|\w+) _\w+\(' <state_file>
```

**Why it's wrong:** a `_helper()` at file scope is relocation debt — it reads a map or calls a service that is actually owned by one of the sub-hooks. The helper belongs inside the owning sub-hook, exposed as a method.

Cross-ref: [complex-cubit-patterns.md §7 "Top-level `_helpers()` trailing a state file"](./complex-cubit-patterns.md#top-level-helpers-trailing-a-state-file). This checklist item is a final sweep after the other hoists — helpers often become visible only once coordination has moved around.

**Reference sweep delta:** −20 to −60 LoC per helper (each collapses into its owning sub-hook's method).

---

## §E. Screen file hygiene

The Screen file (HookWidget) is pure wiring. Logic and orchestration belong in the state hook. One named anti-pattern here.

### E1. Top-level `_onXTapped(BuildContext, ..., stateObj)` helpers in Screen file

**Grep-shape:**
```bash
# Any top-level private helper (signature may span multiple lines — single-line BuildContext
# pattern misses multi-line ones, so match any `^<ReturnType> _fn(` at file scope first):
grep -nE '^(Future<[^>]+>|void|bool|int|\w+) _[a-z]\w*\(' <screen_file>
```

Then for each hit, read the signature block (it may span several lines) and classify:

- **Flags as E1:** the function takes `BuildContext` + one-or-more named parameters like `{required AuthGlobalState authState, required FavGlobalState favState, ...}`, OR uses `BuildContext` to open a dialog/sheet AND dispatches on state.
- **Does NOT flag:** factory-style `.phone()`/`.tablet()` helpers on the class (those are class-level, not file-scope), simple `_buildXxx(...)` render helpers without state orchestration, pure utility helpers with no `BuildContext`.

A count > ~3 of flagged helpers is the unambiguous symptom. 1–2 isolated helpers may be legitimate (e.g. one `_showAboutDialog` call) — judge by whether the helper reads state.

**Why it's wrong:** these helpers are **business callbacks wearing a file-scope disguise**. They use `BuildContext` (so they feel Screen-scoped) AND they read state (so they feel like callbacks) AND they're typed to accept `XGlobalState` / `YGlobalState` as keyword args (so they feel parameterized). But semantically they belong on the state hook:

- They orchestrate dialogs / sheets / navigation — exactly what the Screen injects to the hook as **primitives** (`showMoreSheet`, `navigateToItem`, `showSnackBar`).
- They dispatch based on state (`favState.favIds.contains(item.id)`) — dispatch belongs in the action callback the hook builds.
- Tests have to mount a Screen with a fake `BuildContext` to exercise them, not just call the hook.

This is the FT3 item_screen.dart shape — Screen file at 479 LoC with 290 LoC of `_onXTapped` helpers, callable only from the one `build()` method that wires them into the View.

**Fix:** the Screen injects typed UI primitives; the state hook composes the business callbacks using primitives + its own state (obtained via `useProvided<XGlobalState>()` inside the hook, not passed down).

See [screen-state-view.md "The same rule applies to the Screen file — no top-level `_onXTapped(context, ...)` helpers"](../../../../utopia-hooks/skills/utopia-hooks/references/screen-state-view.md) for the full before/after and the list of primitives.

**Reference sweep delta:** a Screen with 9 top-level helpers typically collapses from ~450 LoC to ~85 LoC; the helpers' logic redistributes to the state hook (+150-200 LoC) and the View (+0, it just calls `state.onMoreTapped` instead of receiving a closure). Net: **~−200 LoC** per affected screen, plus the hook's action surface becomes testable without a widget tree.

---

## Why per-anti-pattern commits

Each anti-pattern fix is a **one-purpose change** (e.g. "scroll → pure UI primitives"). Committing each as its own change:

1. Creates a **checkpoint for smoke-testing** — if the app breaks, you know exactly which hoist did it.
2. Makes the diff **readable** — each commit is small (~10-200 LoC) and tells a single story.
3. Enables **bisect** when a regression appears later.
4. Gives the review agent a **focused scope** — a PR with 11 narrow commits is reviewable in a way that a single "refactor comments state" mega-commit is not.

Commit message convention:

```
refactor(<screen>): <anti-pattern name> — <what moved where>

Examples:
  refactor(comments): scroll sub-hook → pure UI primitives; scrollToComment moved to aggregator
  refactor(comments): filter.keywords → reactive useMemoized in aggregator
  refactor(comments): GlobalKey ownership to widget-level hook in CommentTile
  refactor(comments): idMap + maxLevel as useMemoized, not MutableValue
  refactor(comments): loadMore inProgress via widget-level useSubmitState in CommentTile
```

---

## Reference sweep — observed metrics

Applying this checklist to a real migrated `comments/` subtree (≈3 500 LoC across 1 aggregator + 4 sub-hooks + widgets):

| File | Before | After | Δ | Primary anti-pattern fixed |
|---|---:|---:|---:|---|
| scroll sub-hook | 289 | 78 | **−211** | A3 (coordination) + B1 (GlobalKey map) |
| fetch sub-hook | 554 | 365 | **−189** | A1 (lifecycle), A4 (reactive inputs), C3 (manual StreamSubscription), C2 (idMap derivation) |
| search sub-hook | 146 | 97 | **−49** | A3 (receives merged comments from aggregator), C1 (emission-time filter) |
| collapse sub-hook | 185 | 176 | −9 | A1 (partial) |
| aggregator | 97 | 287 | **+190** | absorbs hoisted logic + D1 (getter-delegates limits the growth) |
| per-item widgets | +14 | — | B2 (per-tile useSubmitState) |
| **total** | **~3 500** | **~3 000** | **−500 (−14 %)** | — |

The aggregator **grew by +190 LoC** as cross-cutting logic migrated in — that is expected and correct. Sub-hooks lost **~500 LoC of coordination**. Net: sub-hooks become primitives, aggregator becomes the coordinator, and the overall surface shrinks.

---

## Related

- [screen-migration-flow.md](./screen-migration-flow.md) — the 4-phase migration; this checklist is the 5th phase.
- [complex-cubit-patterns.md](./complex-cubit-patterns.md) — in-migration anti-patterns (this checklist is for **post-migration** bloat).
- [composable-hooks.md](../../../../utopia-hooks/skills/utopia-hooks/references/composable-hooks.md) — Pattern 3 decomposition (what sub-hooks should look like) and "Per-item state: three archetypes" (for §B fixes).
- [complex-state-examples.md](../../../../utopia-hooks/skills/utopia-hooks/references/complex-state-examples.md) — reference shapes a post-migration aggregator should resemble.
