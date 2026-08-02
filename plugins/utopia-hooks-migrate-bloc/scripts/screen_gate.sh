#!/usr/bin/env bash
# screen_gate.sh - per-screen migration gate for BLoC → utopia_hooks.
#
# Invoked as a Claude Code PostToolUse hook. Mechanizes Phase 3 (Self-Review)
# and Phase 4 (Exit Gate) from screen-migration-flow.md, scoped to the single
# edited file.
#
# Contract:
#   - stdin: JSON with {.tool_input.file_path}
#   - stdout: PostToolUse JSON (exit 0). Violations are ALWAYS delivered to the model:
#       warn (default) -> {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}}
#       block          -> {"decision":"block","reason":...}
#   - env UTOPIA_MIGRATE_MODE: "warn" (default) or "block"
#   (Old exit-code contract - exit 1 warn / exit 2 block - dropped: exit 1 stderr never
#   reached the model, making the gate a silent no-op in default mode.)
#
# Guards (exit 0 silently):
#   - file is *.dart under lib/
#   - project has pubspec.yaml with BOTH utopia_hooks AND flutter_bloc
#     (flutter_bloc presence = mid-migration; once removed, migration is done
#     and the general utopia-hooks quality_check takes over)

set -u

mode="${UTOPIA_MIGRATE_MODE:-warn}"
violations=()

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

[[ -z "$file" || ! -f "$file" ]] && exit 0
[[ "$file" == *.dart ]] || exit 0

dir="$(cd "$(dirname -- "$file")" && pwd)"
project_root=""
while [[ "$dir" != "/" && -n "$dir" ]]; do
  if [[ -f "$dir/pubspec.yaml" ]]; then
    project_root="$dir"
    break
  fi
  dir="$(dirname -- "$dir")"
done
[[ -z "$project_root" ]] && exit 0

# Guard: must be mid-migration (both packages declared)
grep -qE '^[[:space:]]*utopia_hooks[[:space:]]*:' "$project_root/pubspec.yaml" || exit 0
grep -qE '^[[:space:]]*(flutter_bloc|bloc|hydrated_bloc|bloc_concurrency)[[:space:]]*:' "$project_root/pubspec.yaml" || exit 0

rel="${file#$project_root/}"
case "$rel" in
  lib/*) ;;
  *) exit 0 ;;
esac

in_state=0
in_screen=0
in_view=0
case "$rel" in
  lib/state/*|lib/*/state/*|*_state.dart) in_state=1 ;;
esac
case "$rel" in
  lib/screens/*|lib/*/screens/*|*_screen.dart|*_page.dart) in_screen=1 ;;
esac
case "$rel" in
  lib/view/*|lib/*/view/*|*_view.dart) in_view=1 ;;
esac
# *_state.dart and *_view.dart can also match *_screen.dart-style suffixes in odd layouts;
# state/view take precedence over screen classification
if [[ $in_state -eq 1 || $in_view -eq 1 ]]; then in_screen=0; fi

add() { violations+=("$1"); }

# --- Filename: old BLoC conventions ---
case "$(basename "$file")" in
  *_cubit.dart|*_bloc.dart)
    add "filename still uses *_cubit.dart / *_bloc.dart - rename to *_state.dart"
    ;;
esac

# --- Phase 4b: leftover BLoC artifacts ---
if grep -qE "^import[[:space:]]+'package:(flutter_bloc|bloc|hydrated_bloc|bloc_concurrency)/" "$file"; then
  add "still imports package:flutter_bloc / bloc / hydrated_bloc - remove after migration"
fi
if grep -qE '\b(BlocBuilder|BlocListener|BlocConsumer|BlocProvider|MultiBlocProvider|RepositoryProvider)\b' "$file"; then
  add "still uses BLoC widgets (BlocBuilder/BlocListener/BlocProvider/…) - convert to HookWidget + useProvided / useEffect"
fi
if grep -qE 'context\.(read|watch|select)<' "$file"; then
  add "still uses context.read / context.watch / context.select - use useProvided<StateType>() instead"
fi
if grep -qE '\bemit\(' "$file"; then
  add "still calls emit() - mutate useState fields directly instead"
fi

# --- Equatable (BLoC idiom) ---
if grep -qE 'extends Equatable\b' "$file"; then
  add "uses 'extends Equatable' - hooks don't need equality; use plain class with final fields"
fi

# --- State file checks (Phase 3a, 3d, 3f, 3g) ---
if [[ $in_state -eq 1 ]]; then
  # 3a: manual stream subscriptions
  if grep -qE '\.listen\(' "$file"; then
    add "uses .listen( in state file - replace with useStreamSubscription / useMemoizedStream"
  fi

  # 3d: manual loading/status state
  if grep -qE 'useState<bool>.*[lL]oading|useState<bool>.*isLoading|useState<[A-Za-z]*Status>' "$file"; then
    add "manual loading/status useState - use useAutoComputedState or useSubmitState instead"
  fi

  # copyWith (BLoC thinking)
  if grep -qE '\bcopyWith\(' "$file"; then
    add "uses copyWith() - one useState per mutable field instead"
  fi

  # 3f: nav / UI in state
  if grep -qE '\b(BuildContext|Navigator\.|GoRouter|context\.(push|pop|go)|Overlay\.|MediaQuery\.|ScaffoldMessenger|showSnackBar)\b' "$file"; then
    add "state file references BuildContext / Navigator / UI APIs - must be callbacks injected from Screen"
  fi

  # 3g: top-level mutable state
  if grep -qE '^final[[:space:]]+(Map|List|Set)\b|^(int|bool|double|String|DateTime\??)[[:space:]]+[a-zA-Z_]+[[:space:]]*=' "$file"; then
    add "state file has top-level mutable state - move to useInjected service or _providers"
  fi

  # 3h: mutable collections in State class body / hook body (indented)
  # flutter-conventions §2 - always use IList / IMap / ISet, not List / Map / Set
  if grep -qE '^[[:space:]]+final[[:space:]]+(Map|List|Set)<' "$file"; then
    add "state file declares mutable List/Map/Set field - use IList/IMap/ISet from fast_immutable_collections (flutter-conventions §2)"
  fi

  # emit() wrapper
  if grep -qE 'void[[:space:]]+emit\(' "$file"; then
    add "defines an emit() wrapper - mutate useState fields directly"
  fi
fi

# --- Screen file checks (Phase 3b) ---
if [[ $in_screen -eq 1 ]]; then
  if grep -qE 'extends[[:space:]]+StatefulWidget\b' "$file"; then
    add "screen uses StatefulWidget - use HookWidget with useEffect / useStreamSubscription"
  fi
  # Screen must be pure wiring - only useXScreenState(...) allowed.
  # Services, global state, effects, local state all belong in the state hook.
  if grep -qE '\b(useInjected|useProvided|useEffect|useImmediateEffect|useStreamSubscription|useAutoComputedState|useComputedState|useSubmitState|useSubmitButtonState|useMemoizedStream|useMemoizedStreamData|useStreamData|useStreamController|useMemoizedFuture|useMemoizedFutureData|useFutureData|useFieldState|useGenericFieldState|usePersistedState|usePreferencesPersistedState|useState|useMemoized|useMemoizedIf|useListenable|useValueListenable|useListenableListener|useListenableValueListener|useNotifiable|useAnimationController|useFocusNode|useScrollController|useAppLifecycleState|useDebounced|usePeriodicalSignal|usePreviousValue|usePreviousIfNull|useValueChanged|useMap|useIf|useIfNotNull|useKeyed|useIsMounted|useCombinedInitializationState)\b' "$file"; then
    add "screen calls a forbidden hook - Screen must only call useXScreenState(...); services, state, and effects belong in the state hook"
  fi
fi

# --- View file checks (screen-state-view rule: View is StatelessWidget, no hooks) ---
if [[ $in_view -eq 1 ]]; then
  if grep -qE 'extends[[:space:]]+HookWidget\b' "$file"; then
    add "view extends HookWidget - View must be StatelessWidget"
  fi
  if grep -qE '\buse[A-Z][A-Za-z0-9_]*\s*\(' "$file"; then
    add "view file calls hooks - View must be StatelessWidget with no hooks (state/logic belongs in the state hook)"
  fi
fi

# --- Global: navigation must not be injected (Screen -> State -> View as callbacks) ---
if grep -qE 'useProvided\s*<\s*NavigatorKey\b' "$file"; then
  add "useProvided<NavigatorKey> is forbidden - navigation flows Screen -> State -> View as callbacks"
fi
if grep -qE 'useInjected\s*<\s*(App)?Router\b' "$file"; then
  add "useInjected<Router> is forbidden - navigation flows Screen -> State -> View as callbacks"
fi

# --- Global: TextEditingController anti-pattern ---
# useMemoized(TextEditingController.new) / useMemoized(() => TextEditingController(...)) - always wrong
if grep -qE 'useMemoized\s*\([^)]*TextEditingController' "$file"; then
  add "useMemoized(TextEditingController...) is forbidden - use useFieldState + TextEditingControllerWrapper (flutter-conventions.md section 9)"
fi
# Manual sync via useEffect + controller.text = ... in state files
if [[ $in_state -eq 1 ]] && ! grep -q 'TextEditingControllerWrapper' "$file"; then
  if grep -qE '\buseEffect\b' "$file" && grep -qE '\.text\s*=\s*[A-Za-z_]' "$file"; then
    add "state file appears to sync controller.text via useEffect - use useFieldState + TextEditingControllerWrapper instead"
  fi
fi

# --- flutter_hooks confusion ---
if grep -qE "^import[[:space:]]+'package:flutter_hooks/" "$file"; then
  add "imports package:flutter_hooks - utopia_hooks is a separate package, not flutter_hooks"
fi

# --- Phase 3c: size budgets (advisory at target, red flag at 400+) ---
lines="$(wc -l < "$file" | tr -d ' ')"
if [[ $in_state -eq 1 ]]; then
  if [[ $lines -gt 400 ]]; then
    add "state file is ${lines} lines (RED FLAG >400) - decompose into sub-hooks immediately (see screen-migration-flow Phase 1c)"
  elif [[ $lines -gt 300 ]]; then
    add "state file is ${lines} lines (budget: 300) - decompose into sub-hooks (see screen-migration-flow Phase 1c)"
  fi
fi
if [[ $in_screen -eq 1 ]]; then
  if [[ $lines -gt 200 ]]; then
    add "screen file is ${lines} lines (RED FLAG >200) - screen should be a coordinator; move UI to view and logic to state"
  elif [[ $lines -gt 100 ]]; then
    add "screen file is ${lines} lines (budget: 100) - screen should be thin coordinator"
  fi
fi
if [[ $in_view -eq 1 ]]; then
  if [[ $lines -gt 400 ]]; then
    add "view file is ${lines} lines (RED FLAG >400) - extract sub-widgets immediately"
  elif [[ $lines -gt 300 ]]; then
    add "view file is ${lines} lines (budget: 300) - extract sub-widgets into separate files"
  fi
fi
if [[ $in_state -eq 1 ]]; then
  usestate_count="$(grep -cE '\b(useState|useAutoComputedState|useSubmitState|useMemoizedStream|useStreamSubscription|useEffect|useMemoized|useInjected|useProvided)\b' "$file" || true)"
  if [[ $usestate_count -gt 10 ]]; then
    add "state hook has ${usestate_count} hook calls (budget: 10) - decompose into sub-hooks"
  fi
fi

# --- Report ---
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

msg="utopia-hooks migration gate: ${#violations[@]} violation(s) in $rel"
for v in "${violations[@]}"; do
  msg+=$'\n'"  - $v"
done
msg+=$'\n'"Fix these before proceeding (references: screen-migration-flow.md Phase 3/4, SKILL.md anti-patterns)."

if [[ "$mode" == "block" ]]; then
  jq -cn --arg reason "$msg" '{"decision": "block", "reason": $reason}'
else
  jq -cn --arg ctx "$msg" \
    '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": $ctx}}'
fi
exit 0
