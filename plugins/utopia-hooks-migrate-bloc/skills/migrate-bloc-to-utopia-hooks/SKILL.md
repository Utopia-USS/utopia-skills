---
name: migrate-bloc-to-utopia-hooks
description: >
  Migrate Flutter BLoC/Cubit codebases to utopia_hooks. Applies when flutter_bloc imports,
  Bloc/Cubit classes, BlocProvider, BlocBuilder, BlocListener, or emit() calls are detected.
  Proactively suggests migration when BLoC patterns are found. Does NOT cover writing new
  hooks-first code in projects without any bloc dependency (use utopia-hooks) or admin/CMS
  screens (use utopia-cms).
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, bloc, cubit, migration, utopia_hooks, state-management
---

# Migrate BLoC → utopia_hooks

## Prerequisites

If the `utopia-hooks` skill is installed, load it now - this migration skill assumes you
understand hook rules and patterns from that skill. If it is not installed, stop and
ask the user to install the `utopia-hooks` plugin/skill before proceeding - its
references provide the target architecture.

## Proactive Detection

**When you encounter ANY of these, suggest migration:**

```dart
// Imports
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc/bloc.dart';

// Patterns in code
class XCubit extends Cubit<XState> { ... }
class XBloc extends Bloc<XEvent, XState> { ... }
BlocProvider(create: ...)
BlocBuilder<XCubit, XState>(builder: ...)
BlocListener<XCubit, XState>(listener: ...)
BlocConsumer<XCubit, XState>(...)
context.read<XCubit>()
context.watch<XCubit>()
emit(newState)
```

**Suggested message:** "This code uses BLoC/Cubit. I can migrate it to utopia_hooks - the
result will be simpler (typically ~30% less code) with the same functionality. Want me to proceed?"

## Concept Map

| BLoC / Cubit | utopia_hooks | Notes |
|---|---|---|
| `Cubit<State>` class | `useXState()` hook function | Hook replaces entire class - no extends, no dispose |
| `Bloc<Event, State>` class | `useXState()` hook + callbacks | Events become function calls, no event classes needed |
| `emit(newState)` | `useState` / `.value =` | Direct state mutation, no immutable state copying |
| Freezed BLoC state (union) | Flat State class with nullable fields | `state.when(loading:, loaded:, error:)` → `if (state.isLoading)` |
| `BlocProvider` | `_providers` map at app root | Global state registered once |
| `BlocProvider` (local, per-screen) | Hook called inside `useXScreenState()` | State lives in the hook, no Provider widget needed |
| `BlocBuilder` | `StatelessWidget` View with State param | View receives state via constructor |
| `BlocListener` | `useEffect` / callback in hook | Side effects live in hook, not in widget tree |
| `BlocConsumer` | `HookWidget` Screen + `StatelessWidget` View | Screen = coordinator, View = pure UI |
| `MultiBlocProvider` | `HookProviderContainerWidget` | Single widget at app root, flat map |
| `RepositoryProvider` | Keep existing DI + `useInjected<T>()` bridge | One-liner hook wrapping your DI (get_it, etc.) |
| `context.read<XCubit>()` | `useProvided<XState>()` | Reads global state (auto-rebuilds) |
| `context.watch<XCubit>()` | `useProvided<XState>()` | Same hook - always reactive |
| `context.select<C, T>()` | `useMemoized(() => derive(state), [state])` | Derived values via memoization |
| `buildWhen: (prev, curr) => ...` | `useMemoized` with selective keys | Rebuild control via dependency array |
| `listenWhen: (prev, curr) => ...` | `useEffect` with selective keys | Effect runs only when keys change |
| `BlocObserver` | No direct equivalent | Use logging in hooks or global error handler |
| `Cubit.close()` / `Bloc.close()` | Automatic | Hooks are disposed when widget unmounts |

## Quick Migration Example

### Before (BLoC)

```dart
// counter_cubit.dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// counter_screen.dart
class CounterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: BlocBuilder<CounterCubit, int>(
        builder: (context, count) {
          return Column(children: [
            Text('$count'),
            ElevatedButton(
              onPressed: () => context.read<CounterCubit>().increment(),
              child: const Text('+'),
            ),
          ]);
        },
      ),
    );
  }
}
```

### After (utopia_hooks)

```dart
// state/counter_screen_state.dart
class CounterScreenState {
  final int count;
  final void Function() onIncrement;
  final void Function() onDecrement;

  const CounterScreenState({
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
  });
}

CounterScreenState useCounterScreenState() {
  final countState = useState(0);
  return CounterScreenState(
    count: countState.value,
    onIncrement: () => countState.value++,
    onDecrement: () => countState.value--,
  );
}

// counter_screen.dart
class CounterScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useCounterScreenState();
    return CounterScreenView(state: state);
  }
}

// view/counter_screen_view.dart
class CounterScreenView extends StatelessWidget {
  final CounterScreenState state;
  const CounterScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('${state.count}'),
      ElevatedButton(
        onPressed: state.onIncrement,
        child: const Text('+'),
      ),
    ]);
  }
}
```

**Result:** 3 classes + BlocProvider → 3 focused files, no framework classes to extend, automatic cleanup.

## References

| File | Impact | Description |
|------|--------|-------------|
| [bloc-to-hooks-state.md][mapping-state] | CRITICAL | State-layer BLoC patterns → hooks (Cubit/Bloc, events, context.read, Status, persistence, global mutable state) |
| [bloc-to-hooks-widget.md][mapping-widget] | CRITICAL | Widget-layer BLoC patterns → hooks (BlocBuilder/Listener/Consumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver) |
| [pubspec-migration.md][pubspec] | CRITICAL | Dependency changes: version resolution, BLoC removal, validation |
| [migration-steps.md][steps] | HIGH | Project-level migration orchestration: pubspec, providers, screen loop, final cleanup |
| [global-state-migration.md][global] | HIGH | Provider tree → _providers, RepositoryProvider → useInjected bridge |
| [screen-migration-flow.md][flow] | HIGH | Per-screen 4-phase migration: analysis (incl. pre-flight cleanup sweep for dead/fake code), migration, self-review, exit gate |
| [complex-cubit-patterns.md][complex] | HIGH | Decomposition, ownership graph, reactive inputs, async-setup → stream, stream accumulation, dynamic streams, navigation callbacks - read for any Complex-classified screen |
| [post-migration-refactor-checklist.md][post] | HIGH | **5th phase** - 14 named anti-patterns with grep-shapes and fix patterns for post-migration bloat that exit-gate greps don't catch (coordination in sub-hooks, per-item state in screen scope, mutable derivations, fat aggregators). Run per Complex screen after exit gate passes. |
| `complex-state-examples.md` (foundation skill - resolve per "Resolving reference paths" below) | HIGH | Five anonymised reference shapes for complex state (pipeline / dashboard / parent-owned list / per-item widget-level / multi-step flow) - what the migrated result looks like. Lives in the foundation skill because the shapes apply to new screens too. |
| `paginated.md` (foundation skill - resolve per "Resolving reference paths" below) | HIGH | `usePaginatedComputedState` + `PaginatedComputedStateWrapper`: cursor/page/token schemes, loadMore, refresh, debounce, dedup, optimistic overlay - target pattern for any BLoC/Cubit that paginated lists manually. |

[mapping-state]: references/bloc-to-hooks-state.md
[mapping-widget]: references/bloc-to-hooks-widget.md
[pubspec]: references/pubspec-migration.md
[steps]: references/migration-steps.md
[global]: references/global-state-migration.md
[flow]: references/screen-migration-flow.md
[complex]: references/complex-cubit-patterns.md
[post]: references/post-migration-refactor-checklist.md

## Problem → Reference

| Situation | Start With |
|-----------|------------|
| Converting a Cubit to hooks | [bloc-to-hooks-state.md][mapping-state] |
| Converting a Bloc with events to hooks | [bloc-to-hooks-state.md][mapping-state] |
| Migrating BlocProvider tree | [global-state-migration.md][global] |
| Migrating RepositoryProvider | [global-state-migration.md][global] |
| Step-by-step process for one screen | [migration-steps.md][steps] |
| Freezed union state → hooks state | [bloc-to-hooks-state.md][mapping-state] |
| BlocListener side effects | [bloc-to-hooks-widget.md][mapping-widget] |
| Adding/removing pubspec dependencies | [pubspec-migration.md][pubspec] |
| Which package version to use | [pubspec-migration.md][pubspec] |
| Per-screen migration with self-review | [screen-migration-flow.md][flow] |
| Complex screen with streams/lifecycle/large state | [complex-cubit-patterns.md][complex] + [screen-migration-flow.md][flow] Phase 1d |
| Multi-domain cubit (fetch + search + scroll) | [complex-cubit-patterns.md][complex] §1 (decomposition) + §0 (ownership graph) |
| Cubit has `updateX(T)` methods that trigger re-fetch | [complex-cubit-patterns.md][complex] §5 "Reactive inputs vs. mutators" |
| Multi-await setup before stream.listen | [complex-cubit-patterns.md][complex] §3 Pattern A (extended) |
| List item has its own state (expand, async, drafts) | `composable-hooks.md` "Per-item state: three archetypes" (foundation skill) |
| Migrating a Cubit/BLoC that loads paginated lists | `paginated.md` (foundation skill) |
| What does good look like? | `complex-state-examples.md` (foundation skill) |
| Migrating stream.listen() calls | [bloc-to-hooks-widget.md][mapping-widget] (section 6) |
| Migrating StatefulWidget with lifecycle | [bloc-to-hooks-widget.md][mapping-widget] (section 7) |
| Screen migrated + exit gate passed, but state/ still feels bloated | [post-migration-refactor-checklist.md][post] |
| Sub-hook grew over ~200 LoC during migration | [post-migration-refactor-checklist.md][post] §A (coordination in wrong layer) |
| Aggregator has 20+ `required` fields mostly proxying sub-state | [post-migration-refactor-checklist.md][post] §D1 (getter-delegate collapse) |
| Screen file has top-level `_onXTapped(context, ...)` helpers | `screen-state-view.md` "Top-level helpers in Screen file" (foundation skill) |

Entries marked *(foundation skill)* are NOT bundled with this plugin - they live in the sibling `utopia-hooks` plugin. Resolve them per "Resolving reference paths" below; never follow a relative path out of this plugin's root.

## Non-Negotiable Migration Rules

- **Never mix BLoC and hooks in the same screen** - migrate a screen completely or leave it as BLoC. BLoC and hooks CAN coexist across different screens during incremental migration.
- **Always create Screen/State/View** - don't replace BlocBuilder with a HookWidget that has inline UI
- **State class must NOT import widgets** - same rule as in utopia-hooks
- **View never calls hooks** - BlocBuilder's `builder:` becomes a StatelessWidget
- **Delete BLoC files after migration** - don't leave dead code
- **Never hardcode package versions** - fetch latest `utopia_hooks` from pub.dev dynamically (see [pubspec-migration.md][pubspec])
- **Never add `flutter_hooks`** - utopia_hooks is a completely separate implementation, not an extension of flutter_hooks
- **Migration is done when `dart analyze` returns zero errors** - not before. Loop: fix → re-run → fix → re-run
- **StatefulWidget with lifecycle → HookWidget** - if a StatefulWidget exists only to manage subscriptions, controllers, or timers in `initState`/`dispose`, convert it to HookWidget with `useEffect`/`useStreamSubscription`
- **The ~30% code reduction is a consequence** - focus on correctness, not size

## Migration Anti-Patterns - NEVER DO THESE

These are the most common mistakes when migrating. Every single one must be absent from migrated code.

```dart
// ❌ NEVER: copyWith() in hooks - this is BLoC thinking, not hooks thinking
state.value = state.value.copyWith(isLoading: true);
// ✅ INSTEAD: one useState per mutable field
final isLoadingState = useState(false);
isLoadingState.value = true;

// ❌ NEVER: Equatable on state classes - hooks don't need equality checks
class MyState extends Equatable {
  @override List<Object?> get props => [field1, field2];
}
// ✅ INSTEAD: plain class with final fields
class MyState {
  final String? data;
  final bool isLoading;
  const MyState({required this.data, required this.isLoading});
}

// ❌ NEVER: Status enum (idle/loading/success/failure) - hooks have built-in state machines
final Status status;
// ✅ INSTEAD: useAutoComputedState has ComputedStateValue (notInitialized/inProgress/ready/failed)
//            useSubmitState has .inProgress bool
//            State class exposes: T? data (via .valueOrNull), bool isSaving (via .inProgress)

// ❌ NEVER: passing Cubit/Bloc instances to hooks
// WHY: breaks reactivity (Cubit changes won't trigger rebuilds), couples to BLoC API,
//      makes testing require real/mocked Cubits instead of plain state objects
FavState useFavState({required AuthBloc authBloc}) {
  authBloc.stream.listen(...);   // BLoC API in hooks
  authBloc.state.username;       // reading .state from BLoC
}
// ✅ INSTEAD: useProvided for global state - reactive, decoupled, testable
FavState useFavState() {
  final authState = useProvided<AuthState>();
  // authState.username - direct field access, reactive

// ❌ NEVER: emit() wrapper function
void emit(MyState newState) { state.value = newState; }
// ✅ INSTEAD: mutate individual useState fields directly

// ❌ NEVER: keeping files named _bloc.dart or _cubit.dart
// ✅ INSTEAD: rename to _state.dart (e.g. auth_bloc.dart → auth_state.dart)

// ❌ NEVER: adding comments like "// State", "// Hook", "// ---" section dividers
// ✅ INSTEAD: clean code, no noise comments

// ❌ NEVER: keeping StatefulWidget with lifecycle management
// WHY: initState/dispose for subscriptions and controllers is exactly what hooks replace.
//      Leaving StatefulWidget means the screen is half-migrated.
class HomeScreen extends StatefulWidget { ... }
class _HomeScreenState extends State<HomeScreen> {
  late final StreamSubscription _sub;
  void initState() { _sub = stream.listen(...); }
  void dispose() { _sub.cancel(); super.dispose(); }
}
// ✅ INSTEAD: HookWidget with useStreamSubscription (auto-disposed)
class HomeScreen extends HookWidget {
  Widget build(BuildContext context) {
    final state = useHomeScreenState();
    return HomeScreenView(state: state);
  }
}

// ❌ NEVER: manual stream subscriptions via useState<StreamSubscription?>
// WHY: manual lifecycle management (forget cancel → leak), wastes a state slot,
//      no error handling strategy - useStreamSubscription does all of this automatically
final subscriptionState = useState<StreamSubscription?>(null);
useEffect(() { subscriptionState.value = stream.listen(...); return () => subscriptionState.value?.cancel(); }, []);
// ✅ INSTEAD: useStreamSubscription for side effects per event (auto-disposed)
useStreamSubscription(stream, (event) async => handleEvent(event));
// ✅ OR: useMemoizedStream / useMemoizedStreamData for reading latest value
final data = useMemoizedStream(service.streamData);

// ❌ NEVER: preserve a fake stream from the service layer (async* over in-memory data)
// WHY: a Stream<T> whose generator body has no real await (just iterating a Map/List/Set)
//      is synchronous iteration in disguise. Preserving it forces useStreamSubscription
//      on synchronous data in the migrated hook - a NEW antipattern worse than the BLoC original.
//      Kill it during Phase 1c cleanup sweep (see screen-migration-flow.md), don't port.
Stream<Comment> getCommentsStream({required List<int> ids}) async* {
  for (final id in ids) {
    final c = _memoryMap[id];   // in-memory lookup, zero real await
    if (c != null) yield c;
  }
}
// ✅ INSTEAD: plain sync iteration, consumed directly
Iterable<Comment> getComments(List<int> ids) sync* { /* ... */ }
// In hook: final comments = ids.map(cache.getComment).whereNotNull().toList();
```

## Exit Gate - migration is NOT done until ALL of these pass

**This is not a checklist to review at the end. It is a hard gate. Do not report completion until every item is green.**

### 1. `flutter pub get` passes

See [pubspec-migration.md][pubspec] for exact steps: fetch version from pub.dev, add `utopia_hooks`, never add `flutter_hooks`. BLoC packages are removed only in the final cleanup after ALL screens are migrated - during incremental migration they coexist.

### 2. `dart analyze` returns zero errors

Run `dart analyze` (prefer Dart MCP `analyze_files`). If it reports ANY issues → fix → re-run → fix → re-run. Loop until `No issues found`.

Before running analyze, always run `dart_fix` + `dart_format` on touched files first - removes analyzer-auto-fixable noise (unused imports, `prefer_const_*`, trailing commas, `lines_longer_than_80_chars`) and strips info-level diagnostics that otherwise swamp the real errors. See the migration agents' Phase 3b / Step 5 for the exact step.

| Common error | Fix |
|---|---|
| `Undefined class 'XCubit'` | Old import → replace with state import |
| `'read' isn't defined for 'BuildContext'` | Leftover `context.read` → use state field |
| `Unused import 'package:flutter_bloc/...'` | Remove the import |
| `Unused import 'package:flutter_hooks/...'` | Remove - utopia_hooks is NOT flutter_hooks |
| `Missing concrete implementation` | State class missing a required field |

### 3. Code audit greps - every one returns zero

```bash
grep -rn 'package:flutter_bloc\|package:bloc/\|package:hydrated_bloc\|package:bloc_concurrency' lib/
grep -rn 'package:flutter_hooks' lib/
grep -rn 'extends Equatable' lib/state/
find lib/ -name '*_bloc.dart' -o -name '*_cubit.dart'
ls -d lib/blocs lib/cubits 2>/dev/null
grep -E '^\s+(bloc|flutter_bloc|hydrated_bloc|bloc_concurrency|flutter_hooks):' pubspec.yaml
```

### 4. Stream and lifecycle audit

```bash
# No manual stream subscriptions in state files
grep -rn '\.listen(' lib/state/

# No StatefulWidget in screens (each must have justification if present)
grep -rn 'extends StatefulWidget' lib/screens/
```

### 5. Zero leftover BLoC artifacts in running code

```bash
grep -rn 'context\.read<\|context\.watch<\|context\.select<\|BlocBuilder\|BlocListener\|BlocConsumer\|BlocProvider\|MultiBlocProvider' lib/
```

### 6. Structural audit

```bash
# Navigation calls in state hooks (must be 0 - navigation injected from Screen)
grep -rn 'router\.\|Navigator\.\|GoRouter\|context\.push\|context\.pop\|context\.go(' lib/state/

# BuildContext / UI framework usage in state hooks (must be 0)
grep -rn 'BuildContext\|Overlay\.\|MediaQuery\.\|showSnackBar\|ScaffoldMessenger' lib/state/

# Top-level mutable state in hook files (must be 0)
grep -rn '^final Map\|^final List\|^final Set\|^DateTime?\|^int \|^bool ' lib/state/
```

### 7. Line count sanity check (soft gate)

Compare total lines in migrated hook+state files vs original cubit+state files. If migrated code exceeds **60%** of original line count for Complex screens (50% for Medium) - investigate. This usually means missed hook features (`useAutoComputedState`, `useSubmitState`, `useMemoizedStream`) or missing decomposition.

**If ANY grep returns results → fix them. The migration is not done.**

## Agent Orientation - canonical reference loading

Every migration agent (`migrate-foundation`, `migrate-global-state`, `migrate-screen`, `migrate-review`) runs in a fresh context and needs to load the authoritative references before writing code. This table is the single source of truth - each agent's pre-flight points here with its own role-specific subset.

### Resolving reference paths (CRITICAL)

Agents run with CWD set to the **target Flutter project**, not this plugin's dev repo. Relative paths like `plugins/utopia-hooks/skills/utopia-hooks/` will NOT resolve - they only work in the plugin source repo.

**Resolve plugin files via `${CLAUDE_PLUGIN_ROOT}`.** This env var is set by the Claude Code harness to the currently-running plugin's install dir, e.g. `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.

- **This plugin's files** (migrate-bloc skill): `${CLAUDE_PLUGIN_ROOT}/skills/migrate-bloc-to-utopia-hooks/<file>`
- **Sibling plugin's files** (utopia-hooks foundation skill): resolve via `~/.claude/plugins/installed_plugins.json` - it gives the current `installPath` for the `utopia-hooks@...` entry (marketplace key is `utopia-flutter-skills`; legacy installs may use `utopia-claude-skills` - match on the `utopia-hooks@` prefix). The skill lives at `<installPath>/skills/utopia-hooks/<file>`.

The installed plugin is the authoritative source - load from there first. If `${CLAUDE_PLUGIN_ROOT}` is unset or the sibling plugin is not installed, fall back to whatever you can find, but note it in `self_report.warnings`.

**Shorthand used throughout this plugin:** `utopia-hooks:references/<file>.md` means "the file `references/<file>.md` inside the installed utopia-hooks plugin's skill directory, resolved by the sibling-plugin rule above". It is a naming convention, not a resolvable path or URL scheme - always resolve it before reading.

### Migrate-bloc references (this skill)

| Reference | Purpose | Loaded by |
|---|---|---|
| `SKILL.md` (this file) | Concept map + anti-patterns + exit gate + this table | all agents |
| `references/bloc-to-hooks-state.md` | State-layer patterns → hooks (Cubit/Bloc, events, context.read, Status, persistence, global mutable state) | migrate-global-state, migrate-screen, migrate-review |
| `references/bloc-to-hooks-widget.md` | Widget-layer patterns → hooks (BlocBuilder/Listener/Consumer, TextEditingController, stream.listen, StatefulWidget lifecycle, WidgetsBindingObserver) | migrate-screen, migrate-review |
| `references/global-state-migration.md` | `_providers` + `useInjected` bridge patterns | migrate-foundation, migrate-global-state, migrate-screen |
| `references/pubspec-migration.md` | Dependency changes, version fetching | migrate-foundation |
| `references/screen-migration-flow.md` | Phase 1–4 per-screen flow | migrate-screen, migrate-review |
| `references/complex-cubit-patterns.md` | Decomposition, streams, lifecycle - **conditional** | migrate-global-state (if Cubit has `.listen`, lifecycle, or >10 methods), migrate-screen (if complexity=complex) |
| `references/migration-steps.md` | Project-level orchestration | orchestrator only |

### Foundation-skill references (sibling `utopia-hooks` plugin)

Path resolution: see "Resolving reference paths" above. In short: read `~/.claude/plugins/installed_plugins.json` → pluck `installPath` for the `utopia-hooks@...` entry (match the prefix) → references live at `<installPath>/skills/utopia-hooks/<file>`.

| Reference | Purpose | Loaded by |
|---|---|---|
| `SKILL.md` (foundation) | Screen/State/View + hook rules | migrate-global-state, migrate-screen |
| `references/async-patterns.md` | Loading/submitting patterns | migrate-global-state, migrate-screen |
| `references/paginated.md` | Pagination - **conditional** | migrate-screen (if Cubit paginates) |
| `references/composable-hooks.md` | Decomposition - **conditional** | migrate-screen (if complex) |
| `references/complex-state-examples.md` | Reference shapes - **conditional** | migrate-global-state, migrate-screen (non-trivial cases) |

**Follow these literally.** When a pattern in the code doesn't match any mapping in the references, return `status: other_error` with the unmapped pattern cited - do not invent a translation.

## Output Hygiene Protocol - canonical for all write-capable agents

The `migrate-foundation`, `migrate-global-state`, and `migrate-screen` agents all write files. Before returning, every such agent must run the same output-hygiene step so the downstream `migrate-review` agent sees formatted code with analyzer-auto-fixable noise removed.

**Prefer Dart MCP** (matches the `utopia-hooks` plugin convention):

1. `dart_fix` on files_touched - applies analyzer-suggested auto-fixes (unused imports, `prefer_const_constructors`, `unnecessary_this`, etc.). Safe, idempotent.
2. `dart_format` on files_touched - normalizes style (line breaks, trailing commas, project-configured line length).

**Bash fallback** when Dart MCP is unavailable:

```bash
dart fix --apply <files_touched>
dart format <files_touched>
```

**Scope strictly to `files_touched`.** Do not format unrelated files - the per-commit diff must be tight and predictable. If `dart_fix` / `dart_format` complains about an untouched file, leave it alone and note in `self_report.warnings`.

**If formatting fails** (syntax error in what you wrote) → fix the syntax, re-run format, then return. Never return unformatted code.

**Report back** in `self_report.formatted: true` once the step succeeds.

**Do NOT run `dart analyze`, `flutter pub get`, or tests here.** The `migrate-review` agent owns verification; `dart_fix`/`dart_format` are the sole exceptions - they are required output hygiene, not verification.

## Attribution

Migration from [flutter_bloc](https://pub.dev/packages/flutter_bloc) to
[utopia_hooks](https://pub.dev/packages/utopia_hooks) by UtopiaSoftware.
