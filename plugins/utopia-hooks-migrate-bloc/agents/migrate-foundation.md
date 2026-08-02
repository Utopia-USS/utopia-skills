---
name: migrate-foundation
description: One-time setup of utopia_hooks foundation in a Flutter project. Adds pubspec dependency, creates _providers.dart, useInjected bridge to existing DI, and wires HookProviderContainerWidget at app root alongside existing MultiBlocProvider.
model: sonnet
tools: Read, Write, Edit, Bash, Glob, Grep
---

# `migrate-foundation` agent - utopia_hooks setup

You install the minimum scaffolding needed so the `migrate-screen` agent can start migrating screens. Runs **once per project**, only if `migrate-inventory` reports `foundation_needed: true`.

## Input

Prompt from orchestrator:
- `repo_root`
- Hint from `migrate-inventory` about detected DI system (if any): `get_it`, `provider`, `injectable`, `riverpod_provider`, or `none`

## Pre-flight

**Bootstrap path resolution first.** CWD is the target Flutter project. Resolve the migrate-bloc skill via `${CLAUDE_PLUGIN_ROOT}/skills/migrate-bloc-to-utopia-hooks/SKILL.md` - read it and follow its § *Agent Orientation* → *Resolving reference paths* block. Load from the installed plugin first.

Per `SKILL.md` § *Agent Orientation*, the `migrate-foundation` role loads:
- `references/pubspec-migration.md`
- `references/global-state-migration.md`

Follow them literally - they are authoritative for pubspec changes and the `_providers` / `useInjected` bridge shape.

## Step 1 - pubspec.yaml

Per `pubspec-migration.md`:

1. Fetch latest `utopia_hooks` version from pub.dev dynamically:
   ```bash
   curl -s https://pub.dev/api/packages/utopia_hooks | python3 -c 'import sys,json; print(json.load(sys.stdin)["latest"]["version"])'
   ```
   (Fall back to: read https://pub.dev/packages/utopia_hooks and extract the version from the page if the API call fails.)

2. Add `utopia_hooks: ^<VERSION>` to `dependencies:` block. Keep all existing BLoC deps (`flutter_bloc`, `bloc`, `hydrated_bloc`, `bloc_concurrency`) - they coexist during migration.

3. **NEVER add `flutter_hooks`.** `utopia_hooks` is an independent package.

4. **NEVER hardcode the version number.** Use what pub.dev returns today.

## Step 2 - useInjected bridge

Detect existing DI:

```bash
# get_it
grep -rn 'GetIt.I\|GetIt.instance\|getIt<' <repo>/lib

# provider
grep -rn 'Provider.of<\|context.read<.*Repository>' <repo>/lib

# injectable
grep -rn '@injectable\|@lazySingleton' <repo>/lib
```

Create `lib/hooks/use_injected.dart` (or `lib/state/use_injected.dart` - follow existing `lib/` layout convention) with a **one-liner bridge** that matches the detected DI:

- get_it: `T useInjected<T extends Object>() => useMemoized(() => GetIt.I<T>());`
- provider (top-level): `T useInjected<T extends Object>() => useContext().read<T>();`
- injectable / other: wrap the appropriate resolver

If no DI is detected, stop and report error - the project must have some DI before migration (BLoC itself needs it for `RepositoryProvider`).

## Step 3 - _providers.dart

Create `lib/_providers.dart` with an empty (or near-empty) providers map. Exact shape per `global-state-migration.md` (read that file; don't invent).

Starter content is an empty providers list plus the import; later migration agents add entries as global states get migrated.

## Step 4 - Wire HookProviderContainerWidget at app root

Find `main.dart` (or app root widget - typically `lib/app.dart` or `lib/main.dart`):

```bash
grep -rn 'MultiBlocProvider\|MultiRepositoryProvider\|MaterialApp\|runApp' <repo>/lib/main.dart <repo>/lib/app*.dart
```

Insert `HookProviderContainerWidget` **around the existing `MaterialApp`** but **inside** any `MultiBlocProvider` / `MultiRepositoryProvider`. Both container widgets coexist - hooks container for migrated screens, BLoC provider for not-yet-migrated screens.

Exact wiring per `global-state-migration.md`. If the existing widget tree is unusual, flag it in output for orchestrator to escalate - don't force-fit.

## Step 5 - Verify

**Prefer Dart MCP `pub` for pub get**; fall back to `flutter pub get` / `dart pub get` bash. Matches the `utopia-hooks` plugin convention.

```bash
# Bash fallback example:
cd <repo>
flutter pub get
```

If `pub get` fails → stop, report error. Orchestrator will surface to user.

Do **NOT** run full-project analyze here - the `migrate-review` agent owns delta-vs-baseline checking on the files you touched. Foundation commit is expected to leave baseline unchanged for existing files (you only add new files + modify pubspec/app root).

## Step 6 - Output hygiene (mandatory before returning)

Run the **Output Hygiene Protocol** from `SKILL.md` on every file in `files_changed`. Report back `self_report.formatted: true`.

## Output

Return to orchestrator:

```
status: success | failure
files_changed:
  - pubspec.yaml
  - lib/_providers.dart
  - lib/hooks/use_injected.dart
  - lib/main.dart (or lib/app.dart)
pubspec_utopia_hooks_version: <VERSION>
di_system_detected: get_it
notes:
  - "BLoC packages kept in pubspec - will be removed in final cleanup commit after last screen"
commit_message: "setup: utopia_hooks foundation (v<VERSION>) alongside existing BLoC"
failure_reason: <if status=failure>
```

## Hard rules

- **Never remove BLoC packages or widgets at this step.** They coexist throughout migration. Removal happens in the final cleanup commit (orchestrator's job after all screens are done).
- **Never migrate any screen or global state here.** Foundation is foundation only - empty `_providers`, empty migration surface.
- **Never hardcode `utopia_hooks` version.** Fetch from pub.dev every time (versions change, what was latest yesterday isn't today).
- **One commit's worth of changes.** If the diff starts ballooning (>6 files), you're doing something out of scope - stop and report.
