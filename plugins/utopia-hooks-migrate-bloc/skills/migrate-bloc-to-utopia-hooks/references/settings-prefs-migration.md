# Settings / preferences blocs -> unified persisted state

Nearly every app has a settings surface, and in BLoC codebases it almost always
materializes as one of three shapes (all field-verified across real migrations):

| Variant | Recognition | Field case encountered |
|---|---|---|
| A. Wide thin-setter class | One load handler building a config snapshot + N methods whose body is a single persistence call (`_addConfigUsecase.setConfigX(v)`), often bypassing `emit` entirely so callers re-fire the load event themselves | a `SettingsBloc` with 21 persist-only setters + 9 getters that re-fetch the whole config to return one field |
| B. Generic catalog cubit | One `update<T>(Preference<T>)` method type-switching over a preference model catalog | a `PreferenceCubit` over a `Preference<T>` model catalog |
| C. HydratedBloc/Cubit | Framework-persisted state via `fromJson`/`toJson` | See [bloc-to-hooks-state.md](./bloc-to-hooks-state.md) section 6 - already covered, cross-link only |

Detection greps (run during Phase 1 analysis; 3+ hits in one class = this reference applies):

```bash
# thin persist-setters
grep -En '(void|Future<void>) set[A-Z]' <bloc_file> | wc -l
# 2-line write cases: service write + copyWith emit
grep -En '_settingsService\.[a-z]+ = event\.|copyWith\(' <bloc_file>
# read side split from write side (re-fetch getters)
grep -En 'Future<.*> get[A-Z].*\(\) async' <bloc_file>
```

## The anti-shape - do NOT reproduce the bloc split

A parity-faithful but WRONG-SHAPED migration of variant A produces two parallel
state files: a read-side snapshot state (N pass-through fields off the config
entity) plus a write-side setters state (N hand-wrapped `submitState.runSimple`
one-liners). That is the bloc's own read/write split re-expressed in hooks - it
type-checks, passes review, and costs 4-5 LOC per setting plus a pass-through
field per setting. Field data: a real migration produced a 62-LOC setters file
for 5 settings plus a separate 17-pass-through data class this way.

The unified shape below expresses the same responsibilities in 1-3 LOC per
setting. Rule of thumb: **the moment you write the same `runSimple` wrapper a
third time, stop and extract - or better, switch to the unified shape.**

## Target shape 1: per-setting `usePersistedState` (independent get+set)

`usePersistedState<T extends Object>(Future<T?> Function() get, Future<void>
Function(T?) set, {bool canGet, HookKeys getKeys})` returns a
`PersistedState<T> implements MutableValue<T?>, HasInitialized` with an
`isSynchronized` flag. Reading is `state.value`, writing is `state.value = x` -
optimistic update first, persistence runs through an internal submit state.
One object per setting, no setter methods, no separate snapshot class.

```dart
class SettingsUnitsState {
  final MutableValue<bool?> usesImperialFoodUnits;
  final MutableValue<bool?> usesImperialHeightUnits;
  final MutableValue<BodyWeightUnit?> bodyWeightUnit;
  final MutableValue<bool?> usesKilojoules;
  final bool isSynchronized;

  const SettingsUnitsState({
    required this.usesImperialFoodUnits,
    required this.usesImperialHeightUnits,
    required this.bodyWeightUnit,
    required this.usesKilojoules,
    required this.isSynchronized,
  });
}

SettingsUnitsState useSettingsUnitsState() {
  final getConfig = useInjected<GetConfigUsecase>();
  final addConfig = useInjected<AddConfigUsecase>();

  // Local generic helper: hooks called through it run unconditionally and in
  // fixed order, so this is hook-rules safe (same pattern as composed hooks).
  PersistedState<T> setting<T extends Object>(
    T Function(ConfigEntity) read,
    Future<void> Function(T) write,
  ) => usePersistedState(
    () async => read(await getConfig.getConfig()),
    (value) async => value != null ? await write(value) : null,
  );

  final imperialFood =
      setting((c) => c.usesImperialFoodUnits, addConfig.setConfigUsesImperialFoodUnits);
  final imperialHeight =
      setting((c) => c.usesImperialHeightUnits, addConfig.setConfigUsesImperialHeightUnits);
  final bodyWeightUnit =
      setting((c) => c.bodyWeightUnit, addConfig.setConfigBodyWeightUnit);
  final kilojoules =
      setting((c) => c.usesKilojoules, addConfig.setConfigUsesKilojoules);

  return SettingsUnitsState(
    usesImperialFoodUnits: imperialFood,
    usesImperialHeightUnits: imperialHeight,
    bodyWeightUnit: bodyWeightUnit,
    usesKilojoules: kilojoules,
    isSynchronized: [imperialFood, imperialHeight, bodyWeightUnit, kilojoules]
        .every((it) => it.isSynchronized),
  );
}
```

View side consumes the `MutableValue` directly - a toggle needs no bool
threading through three layers:

```dart
Switch(
  value: state.usesImperialFoodUnits.value ?? false,
  onChanged: (v) => state.usesImperialFoodUnits.value = v,
)
// or a self-reading toggle when the control gives no value:
onTap: () => state.usesKilojoules.value = !(state.usesKilojoules.value ?? false)
```

Per-setting reads mean N storage reads instead of one snapshot read. For local
storage (Hive, SharedPreferences, a config DAO) this is fine. When the app has
one aggregate config read and per-setting reads are wasteful, use shape 2.

## Target shape 2: optimistic field over an ambient snapshot

When a snapshot state already exists (a global `useProvided<ConfigState>()` or
an aggregate loaded once), expose each setting as a `MutableValue<T>` seeded
from the snapshot, with a local helper that writes through and re-syncs. This
is the house shape for entity-backed settings:

```dart
MutableValue<T> useSettingField<T>(
  T value,                                  // current value from the snapshot
  Future<void> Function(T) write, {
  Future<bool?> Function()? confirm,        // optional guard dialog
}) {
  final submitState = useSubmitState();
  final local = useState(value);
  // Re-sync from the snapshot whenever no write is in flight.
  useEffect(() {
    if (!submitState.inProgress) local.value = value;
    return null;
  }, [value, submitState.inProgress]);
  return MutableValue.property(local.value, (newValue) {
    if (newValue == local.value) return;    // change-gate (parity with
    final oldValue = local.value;           // equality-guarded bloc setters)
    local.value = newValue;                 // optimistic
    unawaited(submitState.run(() async {
      if (confirm != null && await confirm() != true) {
        local.value = oldValue;
        return;
      }
      try {
        await write(newValue);
      } catch (_) {
        local.value = oldValue;             // rollback
        rethrow;
      }
    }));
  });
}
```

Call sites are then one line per setting:

```dart
final showMealMacros = useSettingField(config.showMealMacros, addConfig.setConfigShowMealMacros);
final appTheme = useSettingField(config.appTheme, addConfig.setConfigAppTheme);
```

If such a helper already exists in the target project (search for
`useOverridable` or similar before writing one), use it instead of redefining.

## Target shape 3: storage adapter, written once

When settings persist to a key-value store directly, wrap the store once and
reuse - do not re-derive get/set closures per setting:

```dart
PersistedState<T> usePrefsPersistedState<T extends Object>(String key) {
  final prefs = useAutoComputedState(SharedPreferences.getInstance).valueOrNull;
  return usePersistedState<T>(
    () async => prefs?.get(key) as T?,
    (value) async =>
        value != null ? await prefs!.set(key, value) : await prefs!.remove(key),
    canGet: prefs != null,
  );
}
// call site: 1 line per setting
final expanded = usePrefsPersistedState<bool>('onboarding.expanded');
```

## Save-on-demand forms

When the screen batches writes behind a Save button (not per-toggle persist),
do NOT use persisted state per field: hold drafts in plain
`useState`/`useFieldState`, submit once through one `useSubmitState`. One
draft + one submit replaces the whole setters family.

## Variant B (catalog cubit) mapping

The catalog is already the right abstraction - keep it. `update<T>` becomes a
single generic function on the state; per-preference `usePersistedState` over
the catalog's read/write is usually overkill. Migrate the catalog, not the
per-setting surface.

## Parity checklist for the reviewer

- Old bloc setters that bypassed emit (callers re-fired the load event): the
  unified shape makes updates visible immediately (optimistic). This is a
  strictly-better UX delta - note it in the commit body as an accepted delta,
  do not silently rely on it elsewhere.
- Equality-guarded bloc setters (early-out when value unchanged) map to the
  change-gate in shape 2; verify the gate exists.
- Bloc setters that fanned out to other blocs/states after writing keep the
  transition pokes per the orchestrator's binding decisions.
- Persistence failure: bloc usually swallowed it; `usePersistedState` keeps the
  optimistic value and surfaces the failure through the submit pipeline
  (`isSynchronized == false`). Decide per screen whether that needs UI.
- The old thin re-fetch getters (`getDayStartOffsetHours()` style) disappear -
  consumers read `state.x.value`. Check every call site of the deleted getters.

## Wiring (for the skill maintainer landing this file)

- SKILL.md References table: add this file with impact HIGH, loaded by
  migrate-global-state and migrate-screen when detection greps hit.
- SKILL.md Problem -> Reference table: "Bloc/Cubit is a settings/preferences
  surface (3+ thin persist setters)" -> this file.
- bloc-to-hooks-state.md section 6 (HydratedCubit): add a cross-link here for
  the non-Hydrated variants.
- migrate-review checklist: flag any new state file pairing N `runSimple`
  wrappers with a sibling pass-through snapshot class as the anti-shape above.
