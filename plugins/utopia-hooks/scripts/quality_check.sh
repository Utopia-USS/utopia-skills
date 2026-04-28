#!/usr/bin/env bash
# quality_check.sh — enforce utopia_hooks conventions on a single Dart file.
#
# Invoked as a Claude Code PostToolUse hook.
# Contract:
#   - stdin: JSON with {.tool_input.file_path}
#   - env UTOPIA_HOOKS_MODE: "warn" (default, exit 1) or "block" (exit 2)
#   - exit 0: silent success (or file out of scope)
#   - exit 1: warn — user sees stderr, Claude continues
#   - exit 2: block — Claude sees stderr and must address
#
# Guards (exit 0 silently if any fail):
#   - file is *.dart
#   - project has pubspec.yaml with utopia_hooks dependency
#   - file is under lib/
#
# Checks:
#   - No StatefulWidget in lib/screens/ or lib/state/
#   - No copyWith() in lib/state/
#   - No `extends Equatable` anywhere
#   - No package:flutter_hooks imports (utopia_hooks is NOT flutter_hooks)
#   - No BuildContext / Navigator / router in lib/state/
#   - No top-level mutable state in lib/state/
#   - Soft size budgets: state file >300 lines, screen file >200 lines

set -u

mode="${UTOPIA_HOOKS_MODE:-warn}"
violations=()

# --- Read file path from stdin JSON ---
if ! command -v jq >/dev/null 2>&1; then
  exit 0  # no jq, can't parse — fail silent
fi

payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

[[ -z "$file" || ! -f "$file" ]] && exit 0

# --- Guard: Dart files only ---
[[ "$file" == *.dart ]] || exit 0

# --- Find project root (walks up for pubspec.yaml) ---
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

# --- Guard: utopia_hooks must be a declared dependency ---
if ! grep -qE '^[[:space:]]*utopia_hooks[[:space:]]*:' "$project_root/pubspec.yaml"; then
  exit 0
fi

# --- Classify file location ---
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
# state/view classification takes precedence over screen when suffixes overlap
if [[ $in_state -eq 1 || $in_view -eq 1 ]]; then in_screen=0; fi

# --- Helper ---
add() { violations+=("$1"); }

# --- Checks that apply everywhere in lib/ ---

# flutter_hooks is NOT utopia_hooks — common confusion
if grep -qE "^import[[:space:]]+'package:flutter_hooks/" "$file"; then
  add "imports package:flutter_hooks — utopia_hooks is a separate package, not flutter_hooks"
fi

# Equatable on state classes is BLoC thinking
if grep -qE 'extends Equatable\b' "$file"; then
  add "uses 'extends Equatable' — utopia_hooks state classes should be plain classes with final fields"
fi

# --- Checks for lib/state/ or *_state.dart ---
if [[ $in_state -eq 1 ]]; then
  if grep -qE '\bcopyWith\(' "$file"; then
    add "state file uses copyWith() — use one useState per mutable field instead"
  fi
  if grep -qE '\b(BuildContext|Navigator\.|GoRouter|context\.(push|pop|go)|Overlay\.|MediaQuery\.|ScaffoldMessenger)\b' "$file"; then
    add "state file references BuildContext / Navigator / UI APIs — navigation and UI must be injected as callbacks from the Screen"
  fi
  if grep -qE '^final[[:space:]]+(Map|List|Set)\b|^(int|bool|double|String|DateTime\??)[[:space:]]+[a-zA-Z_]+[[:space:]]*=' "$file"; then
    add "state file has top-level mutable state — use useInjected service or _providers global state instead"
  fi
  # Mutable collections in class body / hook body (indented) — flutter-conventions §2
  if grep -qE '^[[:space:]]+final[[:space:]]+(Map|List|Set)<' "$file"; then
    add "state file declares mutable List/Map/Set field — use IList/IMap/ISet from fast_immutable_collections (flutter-conventions §2)"
  fi
  if grep -qE 'void[[:space:]]+emit\(' "$file"; then
    add "state file defines an emit() wrapper — mutate useState fields directly"
  fi
fi

# --- Checks for lib/screens/ or *_screen.dart ---
if [[ $in_screen -eq 1 ]]; then
  if grep -qE 'extends[[:space:]]+StatefulWidget\b' "$file"; then
    add "screen uses StatefulWidget — use HookWidget with useEffect / useStreamSubscription instead"
  fi
  # Screen must be pure wiring — only useXScreenState(...) allowed.
  # Services, global state, effects, local state all belong in the state hook.
  if grep -qE '\b(useInjected|useProvided|useEffect|useImmediateEffect|useStreamSubscription|useAutoComputedState|useComputedState|useSubmitState|useSubmitButtonState|useMemoizedStream|useMemoizedStreamData|useStreamData|useStreamController|useMemoizedFuture|useMemoizedFutureData|useFutureData|useFieldState|useGenericFieldState|usePersistedState|usePreferencesPersistedState|useState|useMemoized|useMemoizedIf|useListenable|useValueListenable|useListenableListener|useListenableValueListener|useNotifiable|useAnimationController|useFocusNode|useScrollController|useAppLifecycleState|useDebounced|usePeriodicalSignal|usePreviousValue|usePreviousIfNull|useValueChanged|useMap|useIf|useIfNotNull|useKeyed|useIsMounted|useCombinedInitializationState)\b' "$file"; then
    add "screen calls a forbidden hook — Screen must only call useXScreenState(...); services, state, and effects belong in the state hook"
  fi
fi

# --- View file checks (screen-state-view rule: View is StatelessWidget, no hooks) ---
if [[ $in_view -eq 1 ]]; then
  if grep -qE 'extends[[:space:]]+HookWidget\b' "$file"; then
    add "view extends HookWidget — View must be StatelessWidget"
  fi
  if grep -qE '\buse[A-Z][A-Za-z0-9_]*\s*\(' "$file"; then
    add "view file calls hooks — View must be StatelessWidget with no hooks (state/logic belongs in the state hook)"
  fi
fi

# --- Global: navigation must not be injected (Screen -> State -> View as callbacks) ---
if grep -qE 'useProvided\s*<\s*NavigatorKey\b' "$file"; then
  add "useProvided<NavigatorKey> is forbidden — navigation flows Screen -> State -> View as callbacks"
fi
if grep -qE 'useInjected\s*<\s*(App)?Router\b' "$file"; then
  add "useInjected<Router> is forbidden — navigation flows Screen -> State -> View as callbacks"
fi

# --- Global: TextEditingController anti-pattern ---
# useMemoized(TextEditingController.new) / useMemoized(() => TextEditingController(...)) — always wrong
if grep -qE 'useMemoized\s*\([^)]*TextEditingController' "$file"; then
  add "useMemoized(TextEditingController...) is forbidden — use useFieldState + TextEditingControllerWrapper (flutter-conventions.md section 9)"
fi
# Manual sync via useEffect + controller.text = ... in state files
if [[ $in_state -eq 1 ]] && ! grep -q 'TextEditingControllerWrapper' "$file"; then
  if grep -qE '\buseEffect\b' "$file" && grep -qE '\.text\s*=\s*[A-Za-z_]' "$file"; then
    add "state file appears to sync controller.text via useEffect — use useFieldState + TextEditingControllerWrapper instead"
  fi
fi

# --- Soft size budgets (advisory at target, red flag at 400+) ---
lines="$(wc -l < "$file" | tr -d ' ')"
if [[ $in_state -eq 1 ]]; then
  if [[ $lines -gt 400 ]]; then
    add "state file is ${lines} lines (RED FLAG >400) — decompose into sub-hooks immediately"
  elif [[ $lines -gt 300 ]]; then
    add "state file is ${lines} lines (budget: 300) — consider decomposing into sub-hooks"
  fi
fi
if [[ $in_screen -eq 1 ]]; then
  if [[ $lines -gt 200 ]]; then
    add "screen file is ${lines} lines (RED FLAG >200) — screen should be a coordinator; move UI to view and logic to state"
  elif [[ $lines -gt 100 ]]; then
    add "screen file is ${lines} lines (budget: 100) — screen should be thin coordinator calling hook + passing to View"
  fi
fi
if [[ $in_view -eq 1 ]]; then
  if [[ $lines -gt 400 ]]; then
    add "view file is ${lines} lines (RED FLAG >400) — extract sub-widgets immediately"
  elif [[ $lines -gt 300 ]]; then
    add "view file is ${lines} lines (budget: 300) — extract sub-widgets into separate files"
  fi
fi

# --- Hook sub-unit: useX hook-call count inside state files ---
if [[ $in_state -eq 1 ]]; then
  usestate_count="$(grep -cE '\b(useState|useAutoComputedState|useSubmitState|useMemoizedStream|useStreamSubscription|useEffect|useMemoized|useInjected|useProvided)\b' "$file" || true)"
  if [[ $usestate_count -gt 10 ]]; then
    add "hook uses ${usestate_count} useX calls (budget: 10) — decompose into sub-hooks"
  fi
fi

# --- Hand-rolled pagination: cursor + hasMore + items in the same state hook ---
# Pattern: useState for cursor/pageToken/offset + hasMore, plus a list and loadMore — classic reinvention.
if [[ $in_state -eq 1 ]] && ! grep -q 'usePaginatedComputedState' "$file"; then
  if grep -qE '\buseState<(int|String\??)>\s*\(.*\).*(cursor|pageToken|page|offset)' "$file" \
      && grep -qE '\b(hasMore|nextPageToken|nextCursor)\b' "$file" \
      && grep -qiE '\bloadMore\b' "$file"; then
    add "state file hand-rolls pagination (cursor + hasMore + loadMore) — use usePaginatedComputedState + PaginatedComputedStateWrapper (paginated.md)"
  fi
fi

# --- Report ---
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

{
  echo "utopia-hooks quality_check: ${#violations[@]} violation(s) in $rel"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "(mode: $mode — set UTOPIA_HOOKS_MODE=block to make these blocking)"
} >&2

if [[ "$mode" == "block" ]]; then
  exit 2
else
  exit 1
fi
