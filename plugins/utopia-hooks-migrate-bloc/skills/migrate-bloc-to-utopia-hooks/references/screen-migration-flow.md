---
title: Per-Screen Migration Flow
impact: HIGH
tags: migration, screen, analysis, self-review, decomposition, exit-gate, per-screen
---

# Per-Screen Migration Flow

Migrate one screen at a time, in four phases. Do NOT skip phases — the analysis and self-review
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

Before Phase 2, identify code that should NOT be ported. Migration is expensive — do NOT port what shouldn't exist. A faithful 1:1 translation of dead or fake code just rehomes the smell with new syntax.

**Scan two things:**

1. **Dead methods** — for each public method on the Cubit and each service/repo method consumed only by this Cubit, grep callers in `lib/`. No callers outside the Cubit/method itself → candidate to delete, don't migrate.

   ```bash
   grep -rn 'cubitInstance\.methodName\|someRepo\.methodName' lib/
   ```

2. **Fake streams in service layer** — for each `Stream<T>` returning method in repos/services consumed by the Cubit, open the `async*` generator body. Does it contain a **non-trivial `await`** (HTTP, disk I/O with real latency, timers)?
   - **NO** (just iterating a `Map`/`List`/`Set` in memory) → fake stream — synchronous iteration in disguise.
   - **YES** → real stream, migrate normally.

   ```dart
   // ❌ FAKE — async* body only reads memory, no non-trivial await
   Stream<Item> streamCached(List<int> ids) async* {
     for (final id in ids) {
       final item = _memoryCache[id];          // sync Map lookup
       if (item != null) yield item;
     }
   }

   // ✅ REAL — each yield awaits actual I/O
   Stream<Item> fetchFromApi(List<int> ids) async* {
     for (final id in ids) {
       final item = await httpClient.get(id);  // real network round-trip
       if (item != null) yield item;
     }
   }
   ```

   Fake streams warrant kill, not preserve. Preserving one forces `useStreamSubscription` on synchronous data in the migrated hook — a new antipattern worse than the BLoC original. See also the "NEVER preserve a fake stream" anti-pattern in [SKILL.md](../SKILL.md#migration-anti-patterns--never-do-these).

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
   NO  → defer — note in PR description as follow-up, do NOT fix inline (scope creep)
```

**Output:** a list with action labels, e.g.:

```
[kill]  CommentCache.getCommentsStream — dead (0 callers)
[kill]  ItemCubit.legacyLoad — dead (0 callers)
[kill]  repo.getCachedCommentsStream — fake (async* over Map), only consumed by this Cubit
[defer] SharedStorage.observeAll — fake but used by 5 other screens (out of scope)
```

Phase 2 skips every `[kill]` item — delete, do not port. `[defer]` items go into the PR description as follow-up work; do NOT fix inline.

### 1d. Decomposition plan (complex only)

If any indicator is "Complex", plan the decomposition BEFORE writing code:

1. Group related methods by domain (e.g., fetching, search, scroll, selection)
2. Each group becomes a sub-hook with its own state object
3. List the sub-hooks and their inputs/outputs
4. Identify how the main screen hook will compose them

See `utopia-hooks:references/composable-hooks.md` Pattern 3 for the decomposition pattern and [complex-cubit-patterns.md](./complex-cubit-patterns.md) section 1 for domain identification techniques and shared state handling.

**Output:** A list like:
```
useOrderFetchState() — handles initial load + pagination
useOrderSearchState(orders) — filter/search, takes fetched orders as input
useOrderScrollState(hasMore, loadMore) — infinite scroll, takes fetch callbacks
Main useOrderScreenState() — composes all three
```

For simple screens, skip this — proceed directly to Phase 2.

---

## Phase 2: Migration

> **Hard gate (Complex screens only):** If Phase 1 classified the screen as Complex, you MUST have a decomposition plan from Phase 1d with sub-hooks listed. Do NOT proceed without it. Each sub-hook MUST be a separate file. No single hook file may exceed ~300 lines. If you skipped 1d — go back now.

Execute the migration using patterns from [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md). For complex cubits, also load [complex-cubit-patterns.md](./complex-cubit-patterns.md) — it covers stream accumulation, dynamic stream creation, init/refresh de-duplication, top-level mutable state, and navigation callbacks that simple mappings don't address.

### 2a. Rename + delete files

```
□ Rename _cubit.dart / _bloc.dart → _state.dart (move to lib/state/ or screen's state/)
□ Delete old Freezed state files, event files
□ Apply [kill] list from Phase 1c — delete dead methods, remove fake streams, update their in-scope callers
□ Update barrel exports
```

### 2b. Design State class + hook

Reference [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md):
- Cubit → hook: sections 1, 2
- Freezed state → flat class: section 7
- Status enum → built-in hooks: section 9
- TextEditingController: section 12

Mandatory rules for State class:
- No `copyWith()`, no `Equatable`, no `Status` enum, no `part` files
- Nullable `T?` for data, `bool` flags for actions, `void Function()` for callbacks
- No widget imports, no `BuildContext`

### 2c. Migrate patterns

For each pattern encountered, use the correct mapping:

| Pattern found | Reference |
|---------------|-----------|
| `stream.listen()` + manual cancel | Section 13 — `useStreamSubscription` |
| `StatefulWidget` with `initState`/`dispose` | Section 14 — convert to `HookWidget` |
| Top-level mutable vars / static fields | Section 15 — move to service or `_providers` |
| `BlocBuilder` | Section 3 — `StatelessWidget` View |
| `BlocListener` | Section 4 — `useEffect` / callback |
| `BlocConsumer` | Section 5 — Screen + View |
| `context.read` / `context.watch` | Section 6 — `useProvided` |

### 2d. Wire up Screen + View

```
□ Screen (HookWidget) — calls hook, passes result to View
□ View (StatelessWidget) — receives State, pure UI
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
If found → see [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) section 13.

### 3b. StatefulWidget audit

```bash
grep -n 'extends StatefulWidget' <migrated_files>
```

**Expected: 0 results**, or each has a documented justification (e.g., platform view wrapper).
If found → see [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) section 14.

### 3c. Hook size check

- Is any hook function > ~300 lines? → Decompose (see `utopia-hooks:references/composable-hooks.md` Pattern 3)
- Does any hook have > ~10 `useState` calls? → Same
- Does the State class have > ~15 fields from unrelated domains? → Decompose into sub-states (see composable-hooks.md Pattern 3)

### 3d. Async patterns

```bash
grep -n 'useState<bool>.*loading\|useState<bool>.*isLoading\|useState.*Status' <migrated_state_files>
```

**Expected: 0 results.** Manual loading/status state should be replaced with:
- `useAutoComputedState` for data loading (reading)
- `useSubmitState` for mutations (writing)
- `useStreamSubscription` / `useMemoizedStream` for stream-based state

### 3e. Side effects in build

Review the migrated code for:
- State mutation outside `useEffect` (e.g., comparing old/new value in `build()`)
- Navigation calls directly in `build()`
- `WidgetsBinding.instance.addPostFrameCallback` in `build()`

All of these should be `useEffect` with appropriate keys.

### 3f. Navigation and UI in state hooks

```bash
# Navigation calls in state hooks (must be 0 — navigation is injected from Screen)
grep -n 'router\.\|Navigator\.\|GoRouter\|context\.push\|context\.pop\|context\.go(' <migrated_state_files>

# BuildContext / UI framework usage in state hooks (must be 0)
grep -n 'BuildContext\|Overlay\.\|MediaQuery\.\|showSnackBar\|ScaffoldMessenger' <migrated_state_files>
```

**Expected: 0 results.** Navigation and UI operations must be callbacks injected from the Screen, not called directly from the hook. See [screen-state-view.md](utopia-hooks:references/screen-state-view.md).

### 3g. Top-level mutable state

```bash
grep -n '^final Map\|^final List\|^final Set\|^DateTime?\|^int \|^bool ' <migrated_state_files>
```

**Expected: 0 results.** Top-level mutable variables should become a registered service (`useInjected`) or global state (`_providers`). See [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) section 15.

### 3h. Deep review (if any check failed)

If any check above failed and the fix isn't obvious, load the `utopia-hooks` skill and review the migrated code against its patterns. The skill's Self-Audit Checklist and async-patterns reference are particularly useful here.

---

## Phase 4: Per-Screen Exit Gate

**Blocking — loop until all pass.**

### 4a. Compilation

```bash
flutter pub get
dart analyze
# If ANY errors → fix → re-run → repeat until "No issues found"
```

### 4b. BLoC artifact greps (scoped to migrated files)

```bash
grep -n 'context\.read<\|context\.watch<\|BlocBuilder\|BlocListener\|BlocProvider' <migrated_files>
grep -n 'package:flutter_bloc' <migrated_files>
```

**Expected: 0 results.**

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

### 4e. Commit

All checks pass → commit this screen. Move to the next screen (back to Phase 1).

---

## Related

- [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) — pattern-by-pattern mapping (sections 1-15)
- [complex-cubit-patterns.md](./complex-cubit-patterns.md) — decomposition, stream accumulation, dynamic streams, global state (Complex screens)
- [migration-steps.md](./migration-steps.md) — project-level migration orchestration
- [global-state-migration.md](./global-state-migration.md) — provider tree migration
- `utopia-hooks:references/composable-hooks.md` — hook decomposition (Pattern 3)
- `utopia-hooks:references/async-patterns.md` — download/upload mental model
