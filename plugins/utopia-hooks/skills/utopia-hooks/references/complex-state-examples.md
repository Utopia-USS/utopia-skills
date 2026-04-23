---
title: Complex-State Examples
impact: HIGH
tags: reference, examples, complex, pipeline, list, per-item, paginated, multi-step
---

# Complex-State Examples

Concrete hook shapes for genuinely **complex state** — multi-domain screens, multi-stream pipelines, or multi-step flows. Simple screens (≤10 `useState`, single-domain, no streams) don't need this level of patterning; see [hooks-reference.md](./hooks-reference.md) and [screen-state-view.md](./screen-state-view.md) for the baseline.

Code sketches are **anonymised** — no product names, no domain-specific tokens. Use them as "what does good look like?" references after reading [composable-hooks.md](./composable-hooks.md) and [async-patterns.md](./async-patterns.md).

If you're migrating from a BLoC/Cubit, the `utopia-hooks-migrate-bloc` skill's [complex-cubit-patterns.md](../../../../utopia-hooks-migrate-bloc/skills/migrate-bloc-to-utopia-hooks/references/complex-cubit-patterns.md) gives the pattern-by-pattern mapping; these examples are what the final result looks like.

Five shapes, each paired with the problem it solves:

1. **Paginated list with reactive search** — input → transform → output pipeline with memoised derivations
2. **Dashboard combining global-state lift + UI-region state** — one screen, two sub-hooks with different shapes
3. **List with parent-owned state + optimistic updates** — reactive parent-owns-list, per-item mutations patch locally
4. **List with per-item widget-level hooks (Pattern 1 extraction)** — parent owns skeleton only, each item is a full widget hook
5. **Multi-step async flow** — one `useSubmitState.runSimple` wrapping a sequential procedure with step-enum progress

Use the two list examples (3 + 4) together as the decision point for "where does per-item state go?"

---

## 1. Paginated list with reactive search — the pipeline shape

Classic input → transform → output. User types in a search field; debounced query drives a fetch; fetched data is processed into a display-ready list. Each stage is pure or declaratively async.

```dart
class SearchScreenState {
  final FieldState searchField;
  final IList<ContactItem>? contacts;
  final IList<User>? newUsers;
  // actions
  final void Function() onCancel;
  final void Function(ItemId) onItemTap;

  const SearchScreenState({...});
}

SearchScreenState useSearchScreenState({
  required void Function() moveBack,
  required void Function(ItemId) navigateToItem,
}) {
  final searchField = useFieldState();
  final debounced = useDebounced(
    searchField.value,
    duration: const Duration(milliseconds: 300),
  );

  // Stage 1: fetch (download — keys re-trigger on debounced change)
  final fetchState = useSearchFetchState(query: debounced);

  // Stage 2: process (pure derive from fetched data)
  final processState = useSearchProcessState(fetchState: fetchState);

  return SearchScreenState(
    searchField: searchField,
    contacts: processState.contacts,
    newUsers: processState.newUsers,
    onCancel: moveBack,
    onItemTap: navigateToItem,
  );
}

// Stage 1 — download sub-hook
SearchFetchState useSearchFetchState({required String query}) {
  final repo = useInjected<ItemRepository>();

  final contacts = useAutoComputedState(
    () => repo.fetchContacts(query: query),
    keys: [query],
  );
  final users = useAutoComputedState(
    () => repo.fetchUsers(query: query),
    keys: [query],
  );

  return SearchFetchState(
    contacts: contacts.valueOrNull,
    users: users.valueOrNull,
  );
}

// Stage 2 — pure derive (memoised)
SearchProcessState useSearchProcessState({required SearchFetchState fetchState}) {
  final contactIds = useMemoized(
    () => fetchState.contacts?.map((c) => c.id).toISet(),
    [fetchState.contacts],
  );

  final newUsers = useMemoized(
    () {
      if (fetchState.users == null || contactIds == null) return null;
      return fetchState.users!.where((u) => !contactIds.contains(u.id)).toIList();
    },
    [fetchState.users, contactIds],
  );

  return SearchProcessState(
    contacts: fetchState.contacts,
    newUsers: newUsers,
  );
}
```

**Characteristics:**
- Linear dependency chain: `query → fetch → process → screen`
- Each stage re-runs only when its inputs change (useAutoComputedState keys, useMemoized deps)
- No mutation cycles, no shared writers — each sub-hook owns exactly its own output
- Zero `.listen()`, zero manual lifecycle

**When to use this shape:** a user-driven input (search, filter, date range) drives a data fetch whose result is displayed (possibly after transformation). Effectively every "list with filters" screen.

---

## 2. Dashboard — global-state lift + UI-region state combo

One screen with two legitimate sub-hook shapes: one re-exports provided globals (read-only with memoised derivations), another owns UI state for a specific region (tabs, filter pills, expanded cards). Both live as sub-hooks of the main screen state; they have different shapes because they have different responsibilities.

```dart
class DashboardScreenState {
  final DashboardInsightsState insights;      // data-lift shape
  final DashboardFilterState filters;         // area-with-state shape
  final void Function() onExportPressed;

  const DashboardScreenState({...});
}

DashboardScreenState useDashboardScreenState({
  required void Function(ReportId) navigateToReport,
}) {
  final insights = useDashboardInsightsState();
  final filters = useDashboardFilterState(insights: insights);

  return DashboardScreenState(
    insights: insights,
    filters: filters,
    onExportPressed: () => navigateToReport(insights.currentReportId),
  );
}

// Sub-hook A: data-lift — no local state, just exposes globals + derivations
DashboardInsightsState useDashboardInsightsState() {
  final currentClass = useProvided<CurrentClassState>();
  final reportSummaries = useProvided<ReportSummariesState>();

  final totalCount = useMemoized(
    () => reportSummaries.data?.length ?? 0,
    [reportSummaries.data],
  );

  final currentReportId = useMemoized(
    () => reportSummaries.data?.firstOrNull?.id,
    [reportSummaries.data],
  );

  return DashboardInsightsState(
    classInfo: currentClass.value,
    reports: reportSummaries.data,
    totalCount: totalCount,
    currentReportId: currentReportId,
  );
}

// Sub-hook B: area-with-state — owns the filter-panel UI state
DashboardFilterState useDashboardFilterState({required DashboardInsightsState insights}) {
  final selectedCategory = useState<CategoryId?>(null);
  final comparisonMode = useState<ComparisonMode>(ComparisonMode.previous);

  final filteredReports = useMemoized(
    () => insights.reports?.where((r) {
      if (selectedCategory.value == null) return true;
      return r.categoryId == selectedCategory.value;
    }).toIList(),
    [insights.reports, selectedCategory.value],
  );

  return DashboardFilterState(
    selectedCategory: selectedCategory,
    comparisonMode: comparisonMode,
    filteredReports: filteredReports,
  );
}
```

**Characteristics:**
- `useDashboardInsightsState` owns no local state — just provided-globals + memoised derivations. "Data-lift" sub-hook.
- `useDashboardFilterState` owns local UI state (category, comparison mode) only the filter panel region touches. "Area-with-state" sub-hook.
- The two sub-hooks have different shapes because they do different things. Don't force them into one consistent template.
- Dependency direction: `insights → filters` (filters read insights), never the reverse.

**When to use this shape:** a screen mixes re-exporting app-wide state with region-specific UI state. The region's state wouldn't make sense at the app level, but also doesn't need to leak across the whole screen — it's just for that area.

---

## 3. Paginated list with parent-owned optimistic overlay

A cursor-paginated list where the parent drives pagination via `usePaginatedComputedState` and per-item mutations (like/unlike, delete, add) project onto the list via a **local override layer** — overlaid at render time, rolled back on failure. The paginated buffer itself stays honest (always mirrors the server); the overlay is the optimistic view. Items themselves are dumb renderers — they don't own state.

See [paginated.md](./paginated.md) for the full `usePaginatedComputedState` contract.

```dart
class FeedScreenState {
  final MutablePaginatedComputedState<Reaction, String?> reactions;
  final IList<Reaction> visibleReactions;     // reactions + overlays
  final MentionFieldState commentField;
  final bool addCommentInProgress;
  final void Function(Reaction) onToggleLike;
  final void Function() onSubmitComment;

  const FeedScreenState({...});
}

FeedScreenState useFeedScreenState({
  required ActivityId activityId,
}) {
  final client = useInjected<ApiClient>();
  final commentField = useMentionFieldState();
  final addSubmit = useSubmitState();
  final likeSubmit = useSubmitState();

  // Paginated state at parent — owns the authoritative list
  final reactions = usePaginatedComputedState<Reaction, String?>(
    initialCursor: null,
    (token) async {
      final response = await client.fetchReactions(
        activityId: activityId,
        pageToken: token,
      );
      return PaginatedPage(items: response.items, nextCursor: response.nextPageToken);
    },
    keys: [activityId],
    deduplicateBy: (r) => r.id,
  );

  // Override layers — overlaid at render, cleared on refresh
  final edits = useState<IMap<ReactionId, Reaction>>(const IMap.empty());
  final prepended = useState<IList<Reaction>>(const IList.empty());

  final visible = useMemoized(
    () => [
      ...prepended.value,
      ...(reactions.items ?? const <Reaction>[]).map((r) => edits.value[r.id] ?? r),
    ].toIList(),
    [reactions.items, edits.value, prepended.value],
  );

  // Optimistic like — patch overlay first, roll back on failure
  void onToggleLike(Reaction reaction) {
    final isLiked = reaction.ownChildren?['like']?.isNotEmpty ?? false;
    final patched = reaction.copyWith(
      likeCount: reaction.likeCount + (isLiked ? -1 : 1),
      ownChildren: isLiked ? null : {'like': [_stubLike()]},
    );
    likeSubmit.runSimple<void, Never>(
      beforeSubmit: () => edits.modify((it) => it.add(reaction.id, patched)),
      submit: () => client.toggleReaction(reaction),
      afterSubmit: (_) => edits.modify((it) => it.remove(reaction.id)),
      afterError: () => edits.modify((it) => it.remove(reaction.id)),
    );
  }

  // Optimistic add — prepend into overlay, settle on server confirmation
  void onSubmitComment() => addSubmit.runSimple<void, Never>(
    submit: () async {
      final text = commentField.controller.text;
      if (text.isEmpty) return;
      final result = await client.addReaction(activityId, text);
      prepended.modify((it) => it.add(result));
      commentField.controller.clear();
    },
  );

  return FeedScreenState(
    reactions: reactions,
    visibleReactions: visible,
    commentField: commentField,
    addCommentInProgress: addSubmit.inProgress,
    onToggleLike: onToggleLike,
    onSubmitComment: onSubmitComment,
  );
}
```

**Characteristics:**
- Parent owns pagination via `usePaginatedComputedState<T, C>` — cursor, loadMore, refresh, debounce, deduplication all handled
- Per-item mutations patch a **separate override layer** (`edits`, `prepended`), never the paginated buffer directly — `items` is read-only on purpose
- Overlay + buffer are combined in a memoised `visibleReactions` the View renders
- On failure, overlay is rolled back (`afterError`); on success, kept or cleared depending on whether the next refresh will include the change
- Items are dumb `StatelessWidget`s with no per-item hook

**When to use this shape:** feed-style list where the parent coordinates pagination, optimistic updates, and cross-item operations. Items are displayed but don't "do" anything on their own. If each item needs its own async / expansion / drafts → switch to shape 4.

---

## 4. List with per-item widget-level hooks — Pattern 1 extraction

Complementary to shape 3. Here each list item has **non-trivial per-item state**: lazy async loading on expand, per-item edit drafts, per-item animation controller. Each item becomes a full widget-level Pattern 1 (`widget_name/` + `state/` + `view/` subfolder). Parent owns only the skeleton.

```dart
// Parent — thin shell, owns the skeleton
class SectionScreenState {
  final IList<ItemRef>? itemRefs;
  final IMap<ItemId, ItemDetail> resolvedCache;
  final void Function(ItemId, ItemDetail) onItemResolved;

  const SectionScreenState({...});
}

SectionScreenState useSectionScreenState({required SectionId sectionId}) {
  final repo = useInjected<SectionRepository>();

  // Parent has the ids; doesn't load per-item details
  final itemRefs = useMemoizedStreamData(
    () => repo.streamItemRefs(sectionId),
    keys: [sectionId],
  );

  // Shared resolved cache — each item feeds back when its async completes
  final resolvedCache = useState<IMap<ItemId, ItemDetail>>(const IMap.empty());

  return SectionScreenState(
    itemRefs: itemRefs,
    resolvedCache: resolvedCache.value,
    onItemResolved: (id, data) =>
        resolvedCache.value = resolvedCache.value.add(id, data),
  );
}

// Parent view — just renders the shell + items
class SectionScreenView extends StatelessWidget {
  final SectionScreenState state;
  const SectionScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final ref in state.itemRefs ?? const IList.empty())
          ItemCard(  // ← widget-level HookWidget
            itemRef: ref,
            onResolved: state.onItemResolved,
          ),
      ],
    );
  }
}

// widgets/item_card/item_card.dart — HookWidget shell
class ItemCard extends HookWidget {
  final ItemRef itemRef;
  final void Function(ItemId, ItemDetail) onResolved;

  const ItemCard({required this.itemRef, required this.onResolved});

  @override
  Widget build(BuildContext context) {
    final state = useItemCardState(itemRef: itemRef, onResolved: onResolved);
    return ItemCardView(state: state);
  }
}

// widgets/item_card/state/item_card_state.dart — per-item hook
class ItemCardState {
  final ItemRef ref;
  final MutableValue<bool> expandedState;
  final ItemDetail? detail;
  final bool isLoading;

  const ItemCardState({...});
}

ItemCardState useItemCardState({
  required ItemRef itemRef,
  required void Function(ItemId, ItemDetail) onResolved,
}) {
  final repo = useInjected<ItemRepository>();
  final expandedState = useState(false);

  // Per-item async; self-cached across expand/collapse
  final detailState = useComputedState(() async => repo.fetchDetail(itemRef.id));

  // Trigger load on expand; notify parent on completion
  useEffect(() async {
    if (expandedState.value && detailState.value is! ComputedStateValueInProgress) {
      final data = await detailState.refresh();
      onResolved(itemRef.id, data);
    }
    return null;
  }, [expandedState.value, itemRef]);

  return ItemCardState(
    ref: itemRef,
    expandedState: expandedState,
    detail: detailState.valueOrNull,
    isLoading: expandedState.value && !detailState.isInitialized,
  );
}
```

**Characteristics:**
- Parent hook owns only the skeleton (ids, shared cache if needed, feedback sink)
- Each list item is a full widget-level Pattern 1 (`widget/state/view`)
- Per-item async, per-item expansion, per-item caching — all local to the tile
- Tile feeds back to parent via one callback per axis (e.g. `onResolved`) — no callbacks-per-field
- Parent's list concern stays pure: no `loadMore`, no `expandedIds Map`, no per-item state on the screen

**When to use this shape vs. shape 3:**
- If parent needs to **read/modify** per-item state (select-all, submit-all, cross-item validation) → shape 3 (or `useMap` if dynamic N)
- If parent only needs "item signalled it's done, patch my cache" → shape 4
- Rule of thumb: shape 4 when the tile can function without the parent knowing its internal state.

---

## 5. Multi-step async flow — one `useSubmitState` wrapping a procedure

A complex async orchestration where steps must happen in order: scan QR → open session → wait for upload-ready event → download → decrypt → import → finalise. Each step has its own failure mode but collectively they're one user-triggered flow. Resist the urge to split into N hooks — one `useSubmitState` owns the lifecycle; a `stepState` enum drives UI progress.

```dart
enum TransferStep {
  scanQr,
  confirmingKey,
  waitingForPackage,
  downloadingAndImporting,
  finalizing,
}

class TransferScreenState {
  final MobileScannerController scanner;
  final bool isLoading;
  final TransferStep step;
  final void Function(String) onScanned;

  const TransferScreenState({...});
}

TransferScreenState useTransferScreenState({
  required Future<T?> Function<T>(RetryDialogArgs<T>) runRetryable,
  required void Function() navigateToSplash,
}) {
  final sessionSvc = useInjected<SessionService>();
  final packageSvc = useInjected<PackageService>();
  final dskeState = useProvided<DskeState>();

  final submitState = useSubmitState();
  final stepState = useState(TransferStep.scanQr);
  final payloadState = useState<QrPayload?>(null);
  final sessionState = useState<Session?>(null);

  final scanner = useMemoized(
    () => MobileScannerController(formats: [BarcodeFormat.qrCode]),
  );

  // The whole orchestration — not broken into sub-hooks
  Future<void> processTransfer() async {
    final payload = payloadState.value!;
    stepState.value = TransferStep.confirmingKey;

    final session = await sessionSvc.startSession(payload.transferId);
    sessionState.value = session;
    await session.send(ConfirmKey(keyHash: await computeHash(payload.key)));

    stepState.value = TransferStep.waitingForPackage;
    final uploadReady = await session.events
        .whereType<UploadReadyEvent>()
        .first
        .timeout(const Duration(minutes: 15));

    stepState.value = TransferStep.downloadingAndImporting;
    final pkg = await runRetryable(RetryDialogArgs(
      block: () => packageSvc.downloadAndDecrypt(
        payload.transferId, payload.key, uploadReady.nonce,
      ),
      cleanup: abortFlow,
    ));
    if (pkg == null) return;

    stepState.value = TransferStep.finalizing;
    await packageSvc.importPackage(pkg);
    await dskeState.reinitialize();
    await session.send(DownloadConfirmed());
  }

  Future<void> abortFlow() async {
    await sessionState.value?.close();
    sessionState.value = null;
    navigateToSplash();
  }

  bool parsePayload(String raw) {
    try {
      payloadState.value = QrPayload.fromBytes(base64Decode(raw));
      return true;
    } catch (_) {
      return false;
    }
  }

  void onScanned(String data) {
    unawaited(submitState.runSimple<void, Object>(
      skipIfInProgress: true,
      shouldSubmit: () => parsePayload(data),
      submit: processTransfer,
      afterSubmit: (_) => navigateToSplash(),
      afterError: abortFlow,
    ));
  }

  return TransferScreenState(
    scanner: scanner,
    isLoading: submitState.inProgress,
    step: stepState.value,
    onScanned: onScanned,
  );
}
```

**Characteristics:**
- One big `useSubmitState` wraps the entire flow
- `stepState` enum is just a progress indicator — it doesn't gate anything; the `processTransfer` function does
- Steps are set manually at each transition (`stepState.value = ...`) — honest about the imperative nature
- Cleanup via `afterError: abortFlow` (not `try/finally`)
- `skipIfInProgress: true` naturally prevents double-tap re-entry
- Services (`sessionSvc`, `packageSvc`, `dskeState`) are all resolved at hook start via `useInjected` / `useProvided`

**When to use this shape:** a user-triggered flow with inherently sequential steps. Splitting into sub-hooks would fragment the sequence across unrelated lifecycles and lose the natural "try/afterError" recovery path. Keep the sequence in one function, use enum for UI-facing step label.

---

## Related

- [composable-hooks.md](./composable-hooks.md) — Pattern 1 / Pattern 2 / Pattern 3 structures + per-item archetypes (referenced by shapes 2 and 4)
- [async-patterns.md](./async-patterns.md) — `useSubmitState` / `useAutoComputedState` / `useMemoizedStream` in depth
- `utopia-hooks-migrate-bloc:references/complex-cubit-patterns.md` — when migrating from a BLoC/Cubit, the pattern descriptions that map cubit concerns to the shapes above
