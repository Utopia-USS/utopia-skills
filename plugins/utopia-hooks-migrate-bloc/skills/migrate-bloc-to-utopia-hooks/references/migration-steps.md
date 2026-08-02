---
title: Full Project Migration - BLoC to utopia_hooks
impact: HIGH
tags: migration, checklist, step-by-step, screen, convert, refactor, full-project
---

# Full Project Migration: BLoC → utopia_hooks

Migrate **screen by screen**, not big-bang. BLoC and hooks coexist during migration - that's fine.
Commit after each working screen. The app must compile and run at every commit.

```
┌─────────────────────────────────────────────────────┐
│ Step 0: pubspec - add utopia_hooks (keep BLoC)       │
│   ↓                                                  │
│ Step 1: useInjected bridge + _providers setup        │
│   ↓                                                  │
│ Step 2: Screen-by-screen loop                        │
│   ├─ Build dependency graph                          │
│   ├─ Per screen → screen-migration-flow.md           │
│   │     (Analysis → Migration → Self-Review → Gate)  │
│   ├─ Commit                                          │
│   └─ Repeat for next screen                          │
│   ↓                                                  │
│ Step 3: Final cleanup - remove BLoC, grep audit      │
└─────────────────────────────────────────────────────┘
```

**Rules:**
- **Never** leave a screen half-migrated (mixing BLoC and hooks in ONE screen)
- **BLoC and hooks CAN coexist across screens** - Screen A uses hooks, Screen B still uses BLoC. That's the normal state during migration.
- **Run `dart analyze` after each screen** - catch errors immediately, not at the end
- **Commit after each working screen** - git history shows incremental progress, easy to bisect if something breaks
- **Migrating a global state may break screens that depend on it** - that's expected. When you get to those screens, you'll fix them.

---

## Step 0: pubspec.yaml - FIRST, before writing any migration code

Update dependencies before touching any Dart file. This ensures `dart analyze` works
as a cross-check from the very first migrated file onward.

Follow [pubspec-migration.md](./pubspec-migration.md) for version resolution.

1. **Fetch** latest `utopia_hooks` version from pub.dev (dynamic - `curl` the API, never from memory)
2. **Add** `utopia_hooks: ^X.Y.Z` alongside existing BLoC packages (both coexist during migration)
3. **Do NOT remove BLoC packages yet** - other screens still need them. Remove only in Step 3.
4. **Never add** `flutter_hooks` - utopia_hooks is a completely separate implementation
5. **Leave existing DI (get_it, provider, etc.) untouched** - no DI migration needed
6. **Run `flutter pub get`** - must pass before writing any code
7. **Run `dart analyze`** - note existing errors (pre-migration baseline); new errors after this point = your problem

Only proceed to Step 1 after `flutter pub get` succeeds.

---

## Step 1: useInjected bridge + _providers setup

Create the infrastructure that all migrated screens will use. See [global-state-migration.md](./global-state-migration.md) for full details.

1. **Create `useInjected` bridge hook** - a one-liner wrapping your existing DI (e.g. `T useInjected<T extends Object>() => GetIt.I<T>();`)
2. **Create `_providers` map** - start empty, global states added in Step 2 as needed
3. **Replace `MultiBlocProvider`** at app root with `HookProviderContainerWidget`
4. **Keep existing RepositoryProviders/DI registrations unchanged** - no DI migration
5. **Keep existing BlocProviders** inside `_providers`'s child - they still work for unmigrated screens
6. **Run `flutter pub get` + `dart analyze`** - must pass before proceeding
7. **Commit** - infrastructure is in place

---

## Step 2: Screen-by-screen migration loop

Migrate **screen by screen**, committing after each. BLoC and hooks coexist during migration.
Same rules as above apply throughout.

**Scope note:** IList/IMap/ISet conversion of existing data structures is out-of-scope for this migration.
Focus on BLoC → hooks conversion. Collection type cleanup is a separate step.

### 2a. Build dependency graph

Before migrating any screen, determine the order:

1. List all screens and which Cubits/Blocs they depend on
2. List all global states (app-root BlocProviders) - these must be migrated before screens that use them
3. If Screen A depends on Cubit X, and Cubit X depends on Cubit Y → migrate Y first, then X, then A

### 2b. Per-screen migration

For each screen, follow the full 4-phase process in [screen-migration-flow.md](./screen-migration-flow.md):

1. **Phase 1: Analysis** - assess Cubit complexity, plan decomposition if needed
2. **Phase 2: Migration** - rename files, design State class, migrate methods, wire up Screen/View
3. **Phase 3: Self-Review** - check for `.listen()`, StatefulWidget leftovers, hook size, async patterns
4. **Phase 4: Exit Gate** - `dart analyze`, BLoC artifact greps, commit

**Do NOT skip the analysis and self-review phases.** They prevent the most common migration failures: monolithic hooks, manual stream management, and StatefulWidget hybrids.

If a screen depends on an unmigrated global state, migrate that state first and add it to `_providers` (see [global-state-migration.md](./global-state-migration.md)).

**After Phase 4 passes: commit this screen and move to the next one (back to 2b).**

---

## Step 3: Final cleanup - remove BLoC, grep audit

Only after ALL screens are migrated.

### 3a. Remove BLoC packages from pubspec.yaml

```yaml
# Remove these:
#   flutter_bloc: ...
#   bloc: ...
#   hydrated_bloc: ...
#   bloc_concurrency: ...
```

Run `flutter pub get`.

### 3b. Grep audit - every one must return zero results

```bash
grep -rn 'package:flutter_bloc\|package:bloc/\|package:hydrated_bloc\|package:bloc_concurrency' lib/
grep -rn 'package:flutter_hooks' lib/
grep -rn 'extends Equatable' lib/state/
find lib/ -name '*_bloc.dart' -o -name '*_cubit.dart'
ls -d lib/blocs lib/cubits 2>/dev/null
grep -E '^\s+(bloc|flutter_bloc|hydrated_bloc|bloc_concurrency|flutter_hooks):' pubspec.yaml
```

### 3c. Stream and lifecycle audit

```bash
# No manual stream subscriptions in state files
grep -rn '\.listen(' lib/state/

# No StatefulWidget in screens (each must have justification if present)
grep -rn 'extends StatefulWidget' lib/screens/
```

### 3d. Zero leftover BLoC artifacts in running code

```bash
grep -rn 'context\.read<\|context\.watch<\|context\.select<\|BlocBuilder\|BlocListener\|BlocConsumer\|BlocProvider\|MultiBlocProvider' lib/
```

**If ANY grep returns results → fix them. The migration is not done.**

### 3e. Delete leftover files

```
□ Remove .freezed.dart generated files for deleted Freezed states
□ Remove empty lib/blocs/ or lib/cubits/ directories
□ Run build_runner if project has other generated code
```

### 3f. Final `dart analyze`

Run `dart analyze` one last time. Zero errors = migration complete.

### 3g. Verify

```
□ App compiles without errors
□ Screen loads data correctly
□ User actions (save, delete, etc.) work
□ Error states show appropriate feedback
□ Navigation works (back, forward, deep links)
```

### Unit test with SimpleHookContext
```dart
test('tasks load on init', () async {
  final context = SimpleHookContext(() => useTaskListScreenState());
  expect(context().tasks, isNull);
  await context.waitUntil((s) => s.tasks != null);
  expect(context().tasks, isNotEmpty);
});
```

---

## Related

- [screen-migration-flow.md](./screen-migration-flow.md) - per-screen 4-phase migration process
- [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) - state-layer pattern mapping (Cubit/Bloc, events, context.read, Status enums, persistence, global mutable state)
- [bloc-to-hooks-widget.md](./bloc-to-hooks-widget.md) - widget-layer pattern mapping (BlocBuilder/Listener/Consumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver)
- [global-state-migration.md](./global-state-migration.md) - provider tree migration
- `utopia-hooks:references/screen-state-view.md` - Screen/State/View pattern
- `utopia-hooks:references/composable-hooks.md` - hook decomposition (Pattern 3)
- `utopia-hooks:references/testing.md` - SimpleHookContext testing
