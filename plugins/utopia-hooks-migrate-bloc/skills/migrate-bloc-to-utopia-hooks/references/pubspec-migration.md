---
title: pubspec.yaml Migration
impact: CRITICAL
tags: pubspec, dependencies, version, utopia_hooks, flutter_hooks, cleanup, bloc
---

# pubspec.yaml Migration

Single source of truth for dependency changes during BLoC → utopia_hooks migration.
Referenced by SKILL.md and migration-steps.md - all pubspec logic lives here.

---

## 1. Resolve the target package version - MANDATORY, DYNAMIC

**NEVER use a version from memory, training data, or previous conversations.**
The version MUST come from pub.dev at the time of migration.

### Which package to add

The target package is **`utopia_hooks`**.

**Do NOT add `flutter_hooks`.** `utopia_hooks` is a completely separate implementation - it does
NOT extend or depend on `flutter_hooks`. Adding `flutter_hooks` is wrong and will cause conflicts.

**Leave your existing DI library (get_it, provider, etc.) untouched.** The migration does not
replace your DI - it wraps it with a thin `useInjected<T>()` bridge hook.

### Fetch the latest version

```bash
# Run this BEFORE touching pubspec.yaml
curl -s https://pub.dev/api/packages/utopia_hooks | grep -o '"version":"[^"]*"' | head -1
```

If `curl` is unavailable, use `WebFetch` on `https://pub.dev/packages/utopia_hooks` and read the
version from the page. If that also fails, **ask the user** - do not guess.

### Add to pubspec.yaml

Use the **exact version** returned by the command above:

```yaml
dependencies:
  utopia_hooks: ^X.Y.Z    # version from pub.dev, verified just now
```

This dependency gives you:
- All hooks (useState, useEffect, useMemoized, useAutoComputedState, useSubmitState, ...)
- `HookWidget`
- `HookProviderContainerWidget`
- `HasInitialized`
- `useProvided<T>()` for global state access

---

## 2. Remove BLoC packages - AFTER all screens are migrated

During incremental migration, BLoC and hooks coexist. Keep BLoC packages in pubspec until
every screen is migrated. Only remove them in the **final cleanup commit**.

Packages to remove (when ALL screens are done):

```yaml
# dependencies: - REMOVE all of these
  bloc:                  # core BLoC library
  flutter_bloc:          # BLoC widgets (BlocProvider, BlocBuilder, etc.)
  hydrated_bloc:         # persistent BLoC state
  bloc_concurrency:      # event transformers (concurrent, sequential)
  replay_bloc:           # undo/redo BLoC

# dev_dependencies: - REMOVE all of these
  bloc_test:             # BLoC testing utilities
  bloc_lint:             # BLoC lint rules
  mockingjay:            # BLoC-specific mocking
```

### Packages to KEEP

```yaml
  equatable:             # KEEP if model classes (Item, Story, etc.) use it
                         # (only remove if ZERO non-state classes extend Equatable)
  rxdart:                # KEEP if used for BehaviorSubject or stream operators outside BLoC
  get_it:                # KEEP - existing DI stays as-is
  mocktail:              # KEEP - general-purpose mocking, not BLoC-specific
```

### Packages to NEVER ADD

```yaml
  flutter_hooks:         # WRONG - utopia_hooks is a separate implementation, not an extension
                         # Adding this causes duplicate HookWidget, conflicting useState, etc.
  provider:              # WRONG - utopia_hooks has its own provider system (_providers map)
  riverpod:              # WRONG - different architecture entirely
```

---

## 3. Validate - BLOCKING

After editing pubspec.yaml, run these in order. **Do NOT proceed until both pass.**

```bash
# A: Resolve dependencies
flutter pub get
```

If `flutter pub get` fails:
- **Version not found** → re-run the `curl` command, you may have a typo or stale version
- **Dependency conflict** → read the error, adjust version constraints
- **Package not found** → check the package name spelling (`utopia_hooks`, not `utopia-hooks`)

```bash
# B: Verify no BLoC packages remain
grep -E '^\s+(bloc|flutter_bloc|hydrated_bloc|bloc_concurrency|replay_bloc|bloc_test|bloc_lint|mockingjay|flutter_hooks):' pubspec.yaml
# Expected: zero results
```

If any BLoC package remains → remove it and re-run `flutter pub get`.

---

## 4. Post-migration pubspec audit checklist

Run these greps after ALL code migration is done (not just after pubspec changes):

```bash
# Zero BLoC imports in Dart code
grep -rn 'package:flutter_bloc\|package:bloc/\|package:hydrated_bloc\|package:bloc_concurrency' lib/
# Expected: zero results

# Zero flutter_hooks imports (utopia_hooks is NOT flutter_hooks)
grep -rn 'package:flutter_hooks' lib/
# Expected: zero results

# utopia_hooks is actually imported somewhere
grep -rn 'package:utopia_hooks' lib/
# Expected: at least 1 result per state file

# No leftover _bloc.dart or _cubit.dart files
find lib/ -name '*_bloc.dart' -o -name '*_cubit.dart'
# Expected: zero results

# No leftover blocs/ or cubits/ directories
ls -d lib/blocs lib/cubits 2>/dev/null
# Expected: zero results
```

**Every check must return zero (or the expected count). If any fails, the migration is not done.**
