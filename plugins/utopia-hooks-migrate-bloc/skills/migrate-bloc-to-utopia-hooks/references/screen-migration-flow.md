---
title: Per-Screen Migration Flow
impact: HIGH
tags: migration, screen, analysis, self-review, decomposition, exit-gate, per-screen
---

# Per-Screen Migration Flow

Migrate one screen at a time, in four phases. Do NOT skip phases - the analysis and self-review
are what prevent monolithic, half-migrated hooks.

```
Phase 1: Analysis → Phase 2: Migration → Phase 3: Self-Review → Phase 4: Exit Gate → Commit
```

---

## Phase 1: Analysis

Before writing any code, assess the Cubit/Bloc being migrated.

### 1a. Inventory

```
□ Count public methods / event handlers
□ Count stream.listen() calls
□ Check if the screen uses StatefulWidget with initState/dispose lifecycle
□ Check for top-level mutable variables or static fields on the Cubit
□ List dependencies on other Cubits/Blocs (→ migrate those first)
□ Estimate resulting hook size (rough: 1 Cubit method ≈ 5-15 hook lines)
```

### 1b. Complexity classification

| Indicator | Simple | Complex |
|-----------|--------|---------|
| Cubit public methods | ≤10 | >10 |
| `stream.listen()` calls | 0 | ≥1 |
| StatefulWidget lifecycle | None | `initState`/`dispose` with subscriptions or controllers |
| Global mutable state | None | Static fields, top-level mutable vars |
| Estimated hook size | <300 lines | >300 lines |

### 1c. Pre-flight cleanup sweep

Before Phase 2, identify code that should NOT be ported. Migration is expensive - do NOT port what shouldn't exist. A faithful 1:1 translation of dead or fake code just rehomes the smell with new syntax.

**Scan two things:**

1. **Dead methods** - for each public method on the Cubit and each service/repo method consumed only by this Cubit, grep callers in `lib/`. No callers outside the Cubit/method itself → candidate to delete, don't migrate.

   ```bash
   grep -rn 'cubitInstance\.methodName\|someRepo\.methodName' lib/
   ```

2. **Fake streams in service layer** - for each `Stream<T>` returning method in repos/services consumed by the Cubit, open the `async*` generator body. Does it contain a **non-trivial `await`** (HTTP, disk I/O with real latency, timers)?
   - **NO** (just iterating a `Map`/`List`/`Set` in memory) → fake stream - synchronous iteration in disguise.
   - **YES** → real stream, migrate normally.

   ```dart
   // ❌ FAKE - async* body only reads memory, no non-trivial await
   Stream<Item> streamCached(List<int> ids) async* {
     for (final id in ids) {
       final item = _memoryCache[id];          // sync Map lookup
       if (item != null) yield item;
     }
   }

   // ✅ REAL - each yield awaits actual I/O
   Stream<Item> fetchFromApi(List<int> ids) async* {
     for (final id in ids) {
       final item = await httpClient.get(id);  // real network round-trip
       if (item != null) yield item;
     }
   }
   ```

   Fake streams warrant kill, not preserve. Preserving one forces `useStreamSubscription` on synchronous data in the migrated hook - a new antipattern worse than the BLoC original. See also the "NEVER preserve a fake stream" anti-pattern in [SKILL.md](../SKILL.md#migration-anti-patterns--never-do-these).

**Kill-vs-defer rule (apply per finding):**

```
1. Callers exist at all?
   NO  → kill (zero blast radius, always safe)
   YES → step 2
2. All callers inside files of THIS migration?
   YES → kill + update those callers (they're being rewritten anyway)
   NO  → step 3
3. External callers ≤ 2 and trivial to update?
   YES → kill + touch those 1-2 files
   NO  → defer - note in PR description as follow-up, do NOT fix inline (scope creep)
```

**Output:** a list with action labels, e.g.:

```
[kill]  CommentCache.getCommentsStream - dead (0 callers)
[kill]  ItemCubit.legacyLoad - dead (0 callers)
[kill]  repo.getCachedCommentsStream - fake (async* over Map), only consumed by this Cubit
[defer] SharedStorage.observeAll - fake but used by 5 other screens (out of scope)
```

Phase 2 skips every `[kill]` item - delete, do not port. `[defer]` items go into the PR description as follow-up work; do NOT fix inline.

### 1d. Decomposition plan (complex only)

If any indicator is "Complex", plan the decomposition BEFORE writing code:

1. **Draw the ownership graph** - nodes = mutable state fields, edges = reads/writes between hooks. See [complex-cubit-patterns.md §0](./complex-cubit-patterns.md#0-draw-the-ownership-graph-first-write-code-second). Verify: single writer per node, acyclic, no callback-upstream edges.
2. **Pull out per-item state** - if any state is per-list-item (expansion, per-item async, per-tile resources), it belongs in a widget-level hook per `utopia-hooks:references/composable-hooks.md` "Per-item state: three archetypes," not in screen sub-hooks. Remove from screen scope before continuing.
3. **Reclassify `updateX(T)` methods** - those that change a config flag and re-fetch are reactive inputs, not sub-hook methods. See [complex-cubit-patterns.md §5 "Reactive inputs vs. mutators"](./complex-cubit-patterns.md#reactive-inputs-vs-mutators). Plan them as `MutableValue<T>` at the aggregator, not as sub-hook API.
4. Group remaining methods by domain (e.g., fetching, search, scroll, selection)
5. Each group becomes a sub-hook with its own state object
6. List the sub-hooks and their inputs/outputs
7. Identify how the main screen hook will compose them

See `utopia-hooks:references/composable-hooks.md` Pattern 3 for the decomposition pattern and [complex-cubit-patterns.md](./complex-cubit-patterns.md) section 1 for domain identification techniques and shared state handling.

**Output:** An ownership graph + a sub-hook list like:
```
Graph (state → writer):
  items: IList<Item> → fetch
  order: CommentsOrder → screen (reactive input)
  searchQuery: String → search
  scrollOffset: double → scroll

Sub-hooks:
  useOrderFetchState(order)                - handles initial load + pagination
  useOrderSearchState(items)               - filter/search, takes fetched items as input
  useOrderScrollState(hasMore, loadMore)   - infinite scroll, takes fetch callbacks
  Main useOrderScreenState()               - owns `order`, composes all three
```

For simple screens, skip this - proceed directly to Phase 2.

### 1e. Widget subtree manifest

A **screen** is not just `xxx_screen.dart` - it is the entire widget tree that screen renders. The migration scope MUST include every widget in that tree whose file lives in the screen's subtree directory. Otherwise the screen ends up half-migrated: Screen + State on hooks, child widgets still on BLoC.

Build the manifest by walking the tree:

1. **Start node:** the screen file (`lib/screens/<stem>_screen.dart` or equivalent).
2. **Walk imports:** for each `import` in the current file that resolves inside the screen's subtree directory (`lib/screens/<stem>/**`, `lib/<stem>/widgets/**`, or project-equivalent sibling folders), open the imported file and recurse.
3. **Walk `showDialog` / `showModalBottomSheet` / `Navigator.push(..., MaterialPageRoute(builder: …))` targets** whose builder widget class lives in the screen's subtree - include those widgets too.
4. **Stop at shared folders** (`lib/screens/widgets/**`, `lib/common/**`, `lib/shared/**`). These are NOT in the manifest for this screen. Flag each consumed shared widget in `self_report.shared_widgets_touched` - if its dependencies (Cubits) are already migrated globally, the screen agent may still need to rewire the shared widget, but only if all other consumers of the shared widget either (a) are already migrated or (b) don't use that Cubit. Otherwise defer to a dedicated commit.

**Manifest output shape:**

```
manifest:
  owned:                         # in screen's subtree - MUST be migrated in this commit
    - lib/screens/item/item_screen.dart
    - lib/screens/item/item_screen_view.dart
    - lib/screens/item/widgets/reply_box.dart
    - lib/screens/item/widgets/more_popup_menu.dart
    - ...
  shared:                        # consumed but lives outside subtree - reason per entry
    - path: lib/screens/widgets/fav_icon_button.dart
      action: rewire             # all its Cubit deps are migrated globally, safe to flip
    - path: lib/screens/widgets/tips/tips_overlay.dart
      action: defer              # also consumed by 3 other unmigrated screens
  dialogs:                       # launched via showDialog/showModalBottomSheet from owned files
    - lib/screens/item/widgets/login_dialog.dart
```

**Phase 2 scope = `manifest.owned` + any `shared` entries with `action: rewire`.** No partial migration: if a file is in the migration scope, every `BlocBuilder` / `BlocListener` / `context.read` / `context.watch` in it must be gone by the end of Phase 2, regardless of whether it sits in `_screen.dart` or a deep `widgets/**` file.

### 1f. Target structure plan - MANDATORY for all screens

Before writing any code, produce an explicit **current-state vs target-state** file map. This is the primary gate against the most common migration failure: state-layer gets migrated (sub-hooks done) but the View never gets extracted, producing a 400+ line `*_screen.dart` with inline Scaffold/Stack chrome. Exec-level review checks are a backup; this step catches it upfront.

#### Step 1: scan current structure

For each file in `manifest.owned`, record: path, class base (`StatefulWidget` / `HookWidget` / `StatelessWidget`), line count, hook calls.

```bash
# Screen file lines
wc -l lib/screens/<stem>/*_screen.dart

# All widget files under screen
wc -l lib/screens/<stem>/widgets/*.dart 2>/dev/null

# Find mis-classified Views (HookWidget + useProvided/useInjected in widgets/)
grep -lE "extends HookWidget" lib/screens/<stem>/widgets/*.dart 2>/dev/null | \
  xargs -I{} grep -lE "useProvided|useInjected" {}

# Detect multi-page shell constructs
grep -lE "TabController|TabBarView|PageView|PageController|IndexedStack|BottomNavigationBar|NavigationBar\b|DefaultTabController" \
  lib/screens/<stem>/**/*.dart
```

#### Step 2: flag structural issues

Produce flags for each finding:

- **`[misplaced_view]`** - any `widgets/*.dart` that extends `HookWidget` AND calls `useProvided` or `useInjected`. Classic case: `widgets/main_view.dart` with 500+ lines consuming 3× global state. This is almost always the View wearing a different name. Must be addressed in the target plan (rename + move + convert to StatelessWidget + hoist hooks up to the state hook). See `utopia-hooks:references/screen-state-view.md` → "Mis-classified View living in `widgets/`" in Common Pitfalls.
- **`[multi_page_shell]`** - any owned file contains `TabController` / `TabBarView` / `PageView` / `IndexedStack` / `BottomNavigationBar` / `NavigationBar` / `DefaultTabController`. The screen is a multi-page shell - **every inner tab/page content widget must become its own Screen/State/View triple**, not an inline widget or `HookWidget` in `widgets/`. Load `utopia-hooks:references/multi-page-shell.md` - it is mandatory for this class of screen. The target plan must list every inner page's file paths (page + state + view folder).
- **`[screen_too_large]`** - current `*_screen.dart` > ~100 lines (soft redflag per `utopia-hooks:references/screen-state-view.md` "Screen file size - soft redflag"). Target must include extraction of Scaffold/Stack chrome to a dedicated `view/*_screen_view.dart`.
- **`[view_missing]`** - no `lib/screens/<stem>/view/*_screen_view.dart` file exists. Target must create it.

#### Step 3: produce target file map

List every file that will exist after migration, with path + kind + purpose + rough line-count estimate. Do NOT skip files that already exist correctly - list them explicitly so reviewers can see the full picture.

Example for a misfit screen like item_screen:

```
current:
  lib/screens/item/item_screen.dart           | 481 lines | HookWidget | FLAGS: [screen_too_large]
    - inline Scaffold/Stack/split-view chrome (~200 lines) belongs in View
    - ~100 lines of dialog callbacks are legitimate Screen responsibility (keep)
  lib/screens/item/widgets/main_view.dart     | 598 lines | HookWidget | FLAGS: [misplaced_view]
    - consumes PreferenceGlobalState, EditGlobalState, StoriesGlobalState via useProvided
    - this IS the View, mis-classified
  lib/screens/item/state/item_screen_state.dart | 351 lines | hook | ok
  lib/screens/item/state/comments_state.dart    | 407 lines | hook | ⚠ over 300
  lib/screens/item/view/  (missing)           | - | - | FLAGS: [view_missing]

target:
  lib/screens/item/item_screen.dart           | ~60 lines  | HookWidget - pure wiring
    - args class + build() builds dialog/menu callbacks + calls useItemScreenState + returns ItemScreenView
  lib/screens/item/view/item_screen_view.dart | ~250 lines | StatelessWidget - owns Scaffold/Stack/split-view chrome
    - receives state, assembles all sub-widgets, zero hook calls
  lib/screens/item/state/item_screen_state.dart | ~400 lines | hook - adds preference/edit/stories fields
    - all useProvided calls hoisted here from main_view.dart
  lib/screens/item/state/comments_state.dart    | split per complex-cubit-patterns | decompose further if needed
  lib/screens/item/widgets/                   | existing widgets unchanged (CustomAppBar, ReplyBox, etc.)
  lib/screens/item/widgets/main_view.dart     | DELETED - content migrated into ItemScreenView

transformations:
  1. Hoist useProvided<PreferenceGlobalState>, EditGlobalState, StoriesGlobalState from main_view.dart into useItemScreenState
  2. Add corresponding fields to ItemScreenState
  3. Create view/item_screen_view.dart as StatelessWidget, move main_view.dart body + item_screen.dart chrome into it
  4. Simplify item_screen.dart to pure wiring (~60 lines)
  5. Delete widgets/main_view.dart
```

Example for a multi-page shell like home_screen:

```
current:
  lib/screens/home/home_screen.dart           | 376 lines | StatefulWidget | FLAGS: [screen_too_large], [multi_page_shell], [view_missing]
    - TabController + TabBarView with 5× StoriesListView + ProfileScreen inline
    - 5 stream subscriptions + deep link + share intent + notifications in initState
    - tab order from TabCubit.state.tabs
  lib/screens/home/widgets/mobile_home_screen.dart / tablet_home_screen.dart - responsive variants

target:
  lib/screens/home/home_screen.dart              | ~70 lines  | HookWidget - pure wiring
  lib/screens/home/state/home_screen_state.dart  | ~150 lines | hook - composes sub-hooks
  lib/screens/home/state/_use_deep_link_handling.dart | ~40 lines | sub-hook
  lib/screens/home/state/_use_share_intent.dart       | ~30 lines | sub-hook
  lib/screens/home/state/_use_notification_routing.dart | ~40 lines | sub-hook
  lib/screens/home/state/_use_feature_discovery.dart    | ~30 lines | sub-hook
  lib/screens/home/view/home_screen_view.dart    | ~120 lines | StatelessWidget - shell chrome
  lib/screens/home/pages/stories/stories_page.dart           | ~25 lines | HookWidget - pure wiring
  lib/screens/home/pages/stories/state/stories_page_state.dart | ~80 lines | hook
  lib/screens/home/pages/stories/view/stories_page_view.dart   | ~100 lines | StatelessWidget
  lib/screens/home/pages/profile/profile_page.dart           | existing ProfileScreen - decide: migrate as embedded page or keep as routable screen
  (+ one folder per story-type tab OR a single StoriesPage driven by StoryType argument - the decomposition plan must pick one and justify)
```

The target plan is the artifact Phase 2 executes against. Every file in `target` must exist and match its described role before Phase 4 exit gate passes.

---

## Phase 2: Migration

> **Hard gate (Complex screens only):** If Phase 1 classified the screen as Complex, you MUST have a decomposition plan from Phase 1d with sub-hooks listed. Do NOT proceed without it. Each sub-hook MUST be a separate file. No single hook file may exceed ~300 lines. If you skipped 1d - go back now.

Execute the migration using patterns from [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) (state-layer) and [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) (widget-layer). For complex cubits, also load [complex-cubit-patterns.md](./complex-cubit-patterns.md) - it covers stream accumulation, dynamic stream creation, init/refresh de-duplication, top-level mutable state, and navigation callbacks that simple mappings don't address.

### 2a. Rename + delete files

```
□ Rename _cubit.dart / _bloc.dart → _state.dart (move to lib/state/ or screen's state/)
□ Delete old Freezed state files, event files
□ Apply [kill] list from Phase 1c - delete dead methods, remove fake streams, update their in-scope callers
□ Update barrel exports
```

### 2b. Design State class + hook

Reference mapping files:
- Cubit → hook: [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) sections 1, 2
- Freezed state → flat class: [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) section 4
- Status enum → built-in hooks: [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) section 5
- TextEditingController: [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) section 5

Mandatory rules for State class:
- No `copyWith()`, no `Equatable`, no `Status` enum, no `part` files
- Nullable `T?` for data, `bool` flags for actions, `void Function()` for callbacks
- No widget imports, no `BuildContext`

### 2c. Migrate patterns

For each pattern encountered, use the correct mapping:

| Pattern found | Reference |
|---------------|-----------|
| `stream.listen()` + manual cancel | `bloc-to-hooks-widget.md` §6 - `useStreamSubscription` |
| `StatefulWidget` with `initState`/`dispose` | `bloc-to-hooks-widget.md` §7 - convert to `HookWidget` |
| Top-level mutable vars / static fields | `bloc-to-hooks-state.md` §8 - move to service or `_providers` |
| `BlocBuilder` | `bloc-to-hooks-widget.md` §1 - `StatelessWidget` View |
| `BlocListener` | `bloc-to-hooks-widget.md` §2 - `useEffect` / callback |
| `BlocConsumer` | `bloc-to-hooks-widget.md` §3 - Screen + View |
| `context.read` / `context.watch` | `bloc-to-hooks-state.md` §3 - `useProvided` |

### 2d. Wire up Screen + View

```
□ Screen (HookWidget) - calls hook, passes result to View
□ View (StatelessWidget) - receives State, pure UI
□ All navigation callbacks injected from Screen to hook
```

### 2e. For complex screens: implement sub-hooks

If Phase 1 produced a decomposition plan:
1. Implement each sub-hook with its own state class
2. Main screen hook composes sub-hooks
3. Screen State class aggregates fields from all sub-hooks
4. Sub-hooks live in the same `state/` directory

---

## Phase 3: Self-Review

**Hard gate. Do NOT proceed to Phase 4 until every check passes.**

This is where most migration quality issues are caught. Run each check against the migrated files.

### 3a. Stream subscription hygiene

```bash
grep -n '\.listen(' <migrated_state_files>
```

**Expected: 0 results.** Every `.listen(` should be replaced with `useStreamSubscription`.
If found → see [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) section 6.

### 3b. StatefulWidget audit

```bash
grep -n 'extends StatefulWidget' <migrated_files>
```

**Expected: 0 results**, or each has a documented justification (e.g., platform view wrapper).
If found → see [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) section 7.

### 3c. Hook size check

- Is any hook function > ~300 lines? → Decompose (see `utopia-hooks:references/composable-hooks.md` Pattern 3)
- Does any hook have > ~10 `useState` calls? → Same
- Does the State class have > ~15 fields from unrelated domains? → Decompose into sub-states (see composable-hooks.md Pattern 3)
- **Dumb 1:1 port heuristics** - a state file that's significantly larger than the Cubit it replaced, OR has high `useEffect` count in one hook (each effect is a candidate for `useMemoized` / a plain `final` / a getter / a pure helper - not every effect is a "dummy", but in state hooks they're usually derivations in disguise), OR carries derived-state as fields rather than getters/`useMemoized`, OR has `copyWith`/`Equatable` remnants, is a candidate for bloat from mechanical porting. Run `post-migration-refactor-checklist.md` §A/C/D before handoff - the review agent's §M trigger will make it mandatory anyway if you don't.
- Global state hooks (`lib/state/*.dart`) follow the same ≤300 lines rule - if over, split into multiple globals (one per domain in `_providers`), don't decompose into sub-hooks (sub-hooks are a screen-scope pattern). See `utopia-hooks:SKILL.md` Non-Negotiable Rules.

### 3d. Async patterns

```bash
grep -n 'useState<bool>.*loading\|useState<bool>.*isLoading\|useState.*Status' <migrated_state_files>
```

**Expected: 0 results.** Manual loading/status state should be replaced with:
- `useAutoComputedState` for data loading (reading)
- `useSubmitState` for mutations (writing)
- `useStreamSubscription` / `useMemoizedStream` for stream-based state

**Coexistence check (derived state antipattern).** A file that uses `useAutoComputedState`, `useSubmitState`, or `usePaginatedComputedState` MUST NOT also track `isLoading` / `isInProgress` / `isLoaded` / `isFetching` / `hasLoaded` via `useState<bool>`. Those flags are already derived from the computed state's value (`is ComputedStateValueInProgress`, `.inProgress`, etc.). Tracking both = duplicated state, drift-prone.

```bash
# For each file that uses a computed-state hook, it MUST NOT also have a manual loading flag.
for f in $(grep -l 'useAutoComputedState\|usePaginatedComputedState\|useSubmitState' <migrated_state_files>); do
  grep -nE 'useState<bool>.*\b(isLoading|isInProgress|isLoaded|isFetching|hasLoaded|loading)\b' "$f" \
    && echo "FAIL: $f has both computed-state hook AND manual loading flag"
done
```

**Expected: no FAIL lines.** If found → derive the flag instead:

```dart
// ❌ duplicated state
final planState = useAutoComputedState(...);
final isInProgress = useState(false);
// … manually flip isInProgress.value true/false alongside planState

// ✅ pochodne
final planState = useAutoComputedState(...);
final bool isInProgress = planState.value is ComputedStateValueInProgress;
final bool hasData = planState.value is ComputedStateValueReady;
```

### 3e. Side effects in build

Review the migrated code for:
- State mutation outside `useEffect` (e.g., comparing old/new value in `build()`)
- Navigation calls directly in `build()`
- `WidgetsBinding.instance.addPostFrameCallback` in `build()`

All of these should be `useEffect` with appropriate keys.

### 3f. Navigation and UI in state hooks

```bash
# Navigation calls in state hooks (must be 0 - navigation is injected from Screen)
grep -n 'router\.\|Navigator\.\|GoRouter\|context\.push\|context\.pop\|context\.go(' <migrated_state_files>

# BuildContext / UI framework usage in state hooks (must be 0)
grep -n 'BuildContext\|Overlay\.\|MediaQuery\.\|showSnackBar\|ScaffoldMessenger' <migrated_state_files>
```

**Expected: 0 results.** Navigation and UI operations must be callbacks injected from the Screen, not called directly from the hook. See `screen-state-view.md` in the installed `utopia-hooks` plugin (resolve it per SKILL.md "Resolving reference paths").

### 3g. Top-level mutable state

```bash
grep -n '^final Map\|^final List\|^final Set\|^DateTime?\|^int \|^bool ' <migrated_state_files>
```

**Expected: 0 results.** Top-level mutable variables should become a registered service (`useInjected`) or global state (`_providers`). See [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) section 8.

### 3h. No global-state re-export in State classes

A screen's State class must **not** hold a field whose type is another screen's global State (e.g. `AuthGlobalState authState`, `FavGlobalState favState`). Re-exporting a whole global object forces every child widget to rebuild on any field change of that global, defeating the point of `useProvided`'s granular reactivity. It also couples the View to the global's full surface.

**Two legitimate patterns for passing global data to the View:**

1. **Selective projection in the State class.** State exposes only the specific primitives the View needs:
   ```dart
   class TaskScreenState {
     final bool isLoggedIn;     // from authState.isLoggedIn
     final FontSize fontSize;   // from preferenceState.fontSize
     // NOT: final AuthGlobalState authState;
   }
   ```
2. **Per-widget `useProvided` inside widget-level hooks.** The child widget (if it's a HookWidget) calls `useProvided<XGlobalState>()` itself - it reads exactly what it needs, rebuilds independently.

Sub-hook state objects (from Phase 1d decomposition, e.g. `CommentsFetchState`, `CommentsScrollState` within the same screen's `state/` folder) are NOT globals and MAY be held as fields on the aggregator State class. That's what "aggregator" means. The rule is specifically about **cross-screen global State re-export**.

```bash
# Detect global-state fields: types that live in lib/state/** (the globals folder),
# referenced as field types in files under a screen's state/ folder.
# Heuristic: match `final XGlobalState `/`final XState ` where X's type is defined in lib/state/
for f in <migrated_state_files_in_screen_scope>; do
  grep -nE '^\s+final [A-Z]\w*(GlobalState|State)\s+\w+;' "$f" | while read -r line; do
    type_name=$(echo "$line" | grep -oE '[A-Z]\w*(GlobalState|State)')
    # If the type is defined in lib/state/<lowercase>.dart (global), fail.
    if ls "$repo_root/lib/state/"*.dart 2>/dev/null | xargs grep -l "^class $type_name\b" >/dev/null 2>&1; then
      echo "FAIL: $f: State re-exports global $type_name (line: $line)"
    fi
  done
done
```

**Expected: no FAIL lines.** If found → replace the field with selective projections or have the consuming widget call `useProvided<XGlobalState>` itself.

### 3i. Deep review (if any check failed)

If any check above failed and the fix isn't obvious, load the `utopia-hooks` skill and review the migrated code against its patterns. The skill's Self-Audit Checklist and async-patterns reference are particularly useful here.

---

## Phase 4: Per-Screen Exit Gate

**Blocking - loop until all pass.**

### 4a. Compilation

```bash
flutter pub get
dart analyze
# If ANY errors → fix → re-run → repeat until "No issues found"
```

### 4b. BLoC artifact greps (scoped to manifest)

Scope = full Phase 1e manifest (owned + rewired shared), not just `_screen.dart` / state files. Every file in the manifest is in scope for the BLoC audit - if it still reads a Cubit whose global version is registered, the migration is incomplete.

```bash
grep -n 'context\.read<\|context\.watch<\|context\.select<\|BlocBuilder\|BlocListener\|BlocConsumer\|BlocProvider' <manifest_files>
grep -n 'package:flutter_bloc' <manifest_files>
```

**Expected: 0 results for any Cubit with a migrated hook version.** If a Cubit in the result has no hook version yet (not in `_providers.dart`), it's parallel coexistence - acceptable, note in `self_report.warnings`. If it DOES have a hook version, fail: the widget was missed in Phase 2.

### 4c. Stream and lifecycle greps (repeat from Phase 3, final confirmation)

```bash
grep -n '\.listen(' <migrated_state_files>
grep -n 'extends StatefulWidget' <migrated_files>
```

**Expected: 0 results (or justified).**

### 4d. Structural greps (repeat from Phase 3, final confirmation)

```bash
grep -n 'router\.\|Navigator\.\|GoRouter\|context\.push\|context\.pop\|context\.go(' <migrated_state_files>
grep -n 'BuildContext\|Overlay\.\|MediaQuery\.\|showSnackBar\|ScaffoldMessenger' <migrated_state_files>
grep -n '^final Map\|^final List\|^final Set\|^DateTime?\|^int \|^bool ' <migrated_state_files>
```

**Expected: 0 results.**

### 4e. Target structure conformance (from Phase 1f)

The Phase 1f target file map is the contract Phase 2 executes against. Verify every file in `target` exists and matches its described role. Backup exec checks (not a substitute for matching the target plan - if the plan itself is wrong, these won't catch it, but they catch the most common slippage):

```bash
# View file exists
test -f lib/screens/<stem>/view/*_screen_view.dart || \
  echo "FAIL: missing view/*_screen_view.dart - Screen is not split into Screen/State/View"

# View is StatelessWidget, not HookWidget
grep -l "extends HookWidget" lib/screens/<stem>/view/*.dart && \
  echo "FAIL: View must extend StatelessWidget"

# View must have zero hook calls
grep -lE "useProvided|useInjected|useEffect|useState|useMemoized|useSubmitState|useAutoComputedState|useMemoizedStream" lib/screens/<stem>/view/*.dart && \
  echo "FAIL: View contains hook calls - hoist to state hook"

# Screen file size soft-warn (~100 lines redflag per utopia-hooks:references/screen-state-view.md)
SCREEN_LINES=$(wc -l < lib/screens/<stem>/*_screen.dart)
[ "$SCREEN_LINES" -gt 100 ] && \
  echo "WARN: Screen file $SCREEN_LINES lines (~100 soft redflag) - check for Scaffold/Stack chrome that belongs in View, or business logic that belongs in state hook"

# View file size (≤ ~300 lines per non-negotiable rule)
VIEW_LINES=$(wc -l < lib/screens/<stem>/view/*_screen_view.dart)
[ "$VIEW_LINES" -gt 300 ] && \
  echo "WARN: View $VIEW_LINES lines (>300) - extract sub-widgets to widget/ folder"

# Mis-classified Views still lurking in widgets/ (Phase 1f should have caught these, but belt-and-suspenders)
for f in lib/screens/<stem>/widgets/*.dart; do
  if grep -lE "extends HookWidget" "$f" >/dev/null && \
     grep -lE "useProvided|useInjected" "$f" >/dev/null; then
    echo "WARN: $f is HookWidget calling useProvided/useInjected - probable mis-classified View. See utopia-hooks:references/screen-state-view.md 'Mis-classified View living in widgets/'."
  fi
done

# Multi-page shell: inner pages must each have their own page + state + view
# (Only run this check if Phase 1f flagged [multi_page_shell])
if [ -d lib/screens/<stem>/pages ]; then
  for page_dir in lib/screens/<stem>/pages/*/; do
    page_name=$(basename "$page_dir")
    [ -f "$page_dir/${page_name}_page.dart" ] || echo "FAIL: missing $page_dir/${page_name}_page.dart"
    [ -d "$page_dir/state" ] || echo "FAIL: missing $page_dir/state/ folder"
    [ -d "$page_dir/view" ] || echo "FAIL: missing $page_dir/view/ folder"
  done
fi
```

Any `FAIL` blocks commit. Any `WARN` requires explicit acknowledgement in `self_report.warnings` with a justification - do not silently pass warnings.

### 4f. Ownership-graph sanity (Complex screens only)

Re-read the ownership graph drawn in Phase 1d. For each node:

```
□ Still single writer?
□ No new edges introduced during Phase 2 that point upstream (sub-hook → parent via callback)?
□ No cycles between sub-hooks introduced?
```

Zero-cost if the graph is up to date - it's a 30-second sanity check. Caught-here violations are usually a sub-hook that grew an `onSomething` callback parameter that reaches back into the parent's state, or a top-level `_helper()` in a state file that mutates shared state behind one hook's back.

### 4g. Manual smoke-test handoff

Static greps catch structural violations but not runtime behaviour. Before committing, open the migrated screen manually (runtime) and verify the golden path:

```
□ Screen renders without crash on fresh entry
□ Primary data loads on first render (not just "hook runs" - data actually appears)
□ Pull-to-refresh / retry actions fire and observably update UI
□ Primary user actions (submit, edit, expand, navigate) work end-to-end
□ Cross-screen navigation round-trip works (push, pop back, re-enter)
```

This is not an automated check - it's a handoff to yourself. Catches the class of bug where the hook compiles and all greps pass but nothing actually happens because a trigger wasn't wired (e.g. `init()` port that's never called, `useAutoComputedState` without `shouldCompute: true`, stream subscription on a stream nothing ever produces to).

If automated, it belongs in your app's e2e / widget test suite. If you don't have those for the screen, the manual pass IS the test.

### 4h. Commit

All checks pass → commit this screen. Move to the next screen (back to Phase 1).

---

## Related

- [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) - state-layer pattern mapping (Cubit/Bloc, events, context.read, Status enums, persistence, global mutable state)
- [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) - widget-layer pattern mapping (BlocBuilder/Listener/Consumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver)
- [complex-cubit-patterns.md](./complex-cubit-patterns.md) - decomposition, stream accumulation, dynamic streams, global state (Complex screens)
- [migration-steps.md](./migration-steps.md) - project-level migration orchestration
- [global-state-migration.md](./global-state-migration.md) - provider tree migration
- `utopia-hooks:references/composable-hooks.md` - hook decomposition (Pattern 3)
- `utopia-hooks:references/async-patterns.md` - download/upload mental model
