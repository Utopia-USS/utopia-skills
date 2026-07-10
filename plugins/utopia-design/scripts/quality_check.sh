#!/usr/bin/env bash
# quality_check.sh - Utopia Design Protocol nudges.
#
# Invoked as a Claude Code PostToolUse hook after Edit / Write / MultiEdit.
# Contract:
#   - stdin: JSON with {.tool_input.file_path}
#   - env UTOPIA_DESIGN_MODE: "warn" (default, exit 1), "block" (exit 2), or
#     "silent" (never nudge, exit 0)
#   - exit 0: silent success (file out of scope, project does not resolve
#     utopia_ui, or mode=silent)
#   - exit 1: warn - user sees stderr, Claude continues
#   - exit 2: block - Claude must address
#
# Scope (usage gate): the edited file's project must resolve utopia_ui -
# either declared in its pubspec.yaml or resolved in its pubspec.lock (it may
# be a transitive dependency). The protocol is meaningless without the lib,
# so this is checked before any rule runs.
#
# Rules:
#   A - design/*.tokens.json edits: structural JSON sanity (jq empty) plus a
#       minimal DTCG shape check (top level must be a JSON object).
#   B - hardcoded theme values in Dart: Color(0x..) literals, Material
#       Colors.<swatch> palette use, and raw px dimensions in layout
#       constructors, each pointing at the design tokens the value should
#       come from instead. Generated Dart files are skipped.

set -u

# --- Guard 1: jq required ---
command -v jq >/dev/null 2>&1 || exit 0

# --- Guard 2: read file path from stdin JSON ---
payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$file" ]] && exit 0

# --- Guard 3: file must exist on disk ---
[[ -f "$file" ]] || exit 0

# --- Guard 4: find project root (walk up for pubspec.yaml) ---
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

# --- Guard 5: usage gate - project must resolve utopia_ui ---
resolves_utopia_ui=0
if grep -qE '^[[:space:]]*utopia_ui[[:space:]]*:' "$project_root/pubspec.yaml" 2>/dev/null; then
  resolves_utopia_ui=1
elif [[ -f "$project_root/pubspec.lock" ]] \
  && grep -qE '^[[:space:]]*utopia_ui[[:space:]]*:' "$project_root/pubspec.lock" 2>/dev/null; then
  resolves_utopia_ui=1
fi
[[ $resolves_utopia_ui -eq 1 ]] || exit 0

# --- Guard 6: mode ---
mode="${UTOPIA_DESIGN_MODE:-warn}"
[[ "$mode" == "silent" ]] && exit 0

rel="${file#$project_root/}"
violations=()
add() { violations+=("$1"); }

# --- Rule A: design tokens file ---
# Match the canonical unprefixed design/tokens.json plus any *.tokens.json under
# a design/ dir (prefixed variants), at repo root or nested (melos packages).
case "$rel" in
  design/tokens.json|*/design/tokens.json|design/*.tokens.json|*/design/*.tokens.json)
    if ! jq empty "$file" >/dev/null 2>&1; then
      add "invalid JSON in $rel (jq parse failed) - fix before continuing (utopia-design-tokens skill)"
    else
      top_type="$(jq -r 'type' "$file" 2>/dev/null)"
      if [[ "$top_type" != "object" ]]; then
        add "top level of $rel is not a JSON object - DTCG tokens files must be an object with \$schema and/or token groups (utopia-design-tokens)"
      fi
    fi
    # --- VALIDATOR HOOK (wired in B4 via handoff H1) --------------------
    # When A publishes the CLI contract, run the real validator here, e.g.:
    #   dart run utopia_design_tools:validate_tokens "$file"
    # and translate a non-zero validator exit into an add "..." violation.
    # Until then, structural JSON sanity above is the gate.
  ;;
esac

# --- Rule B: hardcoded theme values in Dart ---
if [[ "$file" == *.dart ]]; then
  case "$(basename -- "$file")" in
    *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|*.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart|*.pbgrpc.dart)
      : # generated file - literals here are expected, skip rule B silently
    ;;
    *)
      if grep -qE '(\bconst\s+)?Color\(0x[0-9A-Fa-f]{6,8}\)' "$file"; then
        add "hardcoded Color(0x..) literal - utopia_ui exposes color.* tokens via the theme; read from UtopiaTheme/context instead (utopia-design-tokens)"
      fi
      if grep -qE '\bColors\.(red|pink|purple|blue|indigo|cyan|teal|green|lime|yellow|amber|orange|brown|grey|gray|blueGrey)\b' "$file"; then
        add "Material Colors.<swatch> in a utopia_ui project - prefer color.* design tokens (utopia-design-tokens)"
      fi
      if grep -qE 'EdgeInsets\.(all|fromLTRB)\([0-9]|EdgeInsets\.(symmetric|only)\([a-zA-Z]+:[[:space:]]*[0-9]|BorderRadius\.circular\([0-9]|SizedBox\((width|height):[[:space:]]*[0-9]' "$file"; then
        add "hardcoded dimension literal - utopia_ui has spacing.* / radius.* tokens; use them for a rebrandable scale (utopia-design-tokens)"
      fi
    ;;
  esac
fi

# --- Report ---
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

{
  echo "utopia-design quality_check: ${#violations[@]} nudge(s) in $rel"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "(mode: $mode - set UTOPIA_DESIGN_MODE=block to make these blocking)"
} >&2

if [[ "$mode" == "block" ]]; then
  exit 2
else
  exit 1
fi
