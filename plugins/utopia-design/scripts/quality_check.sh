#!/usr/bin/env bash
# quality_check.sh - Utopia Design Protocol nudges.
#
# Invoked as a Claude Code PostToolUse hook after Edit / Write / MultiEdit.
# Contract:
#   - stdin: JSON with {.tool_input.file_path} plus the edit payload
#     (.tool_input.new_string / .content / .edits[].new_string)
#   - env UTOPIA_DESIGN_MODE:
#       "warn" (default) - emit a PostToolUse JSON payload on stdout, exit 0:
#         systemMessage (shown to the user) + hookSpecificOutput.additionalContext
#         (reaches the model, non-blocking). A plain exit-1 stderr reaches only
#         the user, so warn uses additionalContext to actually steer the agent.
#       "block" - print the nudges to stderr and exit 2 (Claude must address).
#       "silent" - never nudge (exit 0, no output).
#   - exit 0: silent success (out of scope / no utopia_ui / mode=silent) OR warn JSON.
#   - exit 2: block.
#
# Scope (usage gate): the edited file's project must resolve utopia_ui -
# either declared in its pubspec.yaml or resolved in its pubspec.lock (it may
# be a transitive dependency). The protocol is meaningless without the lib,
# so this is checked before any rule runs.
#
# Rules:
#   A - design/tokens.json (and *.tokens.json under design/) edits: structural
#       JSON sanity (jq empty) plus a minimal DTCG shape check (top level must
#       be a JSON object). Reads the whole file - JSON validity is a whole-file
#       property. VALIDATOR HOOK below wires the real validator in B4 (H1).
#   B - hardcoded theme values in NEWLY-EDITED Dart. Scans the edit payload
#       (new_string / content / edits[].new_string), NOT the whole file, so a
#       pre-existing literal in a legacy file does not re-nag on every unrelated
#       edit. Flags Color(0x..), Material Colors.<swatch>, and non-zero px
#       dimensions in layout constructors, pointing at reading from
#       UtopiaTheme/context. Generated Dart files are skipped.

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

# --- Rule B: hardcoded theme values in newly-edited Dart ---
if [[ "$file" == *.dart ]]; then
  case "$(basename -- "$file")" in
    *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|*.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart|*.pbgrpc.dart)
      : # generated file - literals here are expected, skip rule B silently
    ;;
    *)
      # Only the edit payload is scanned, so pre-existing literals in a legacy
      # file do not re-nag. Covers Edit (new_string), Write (content) and
      # MultiEdit (edits[].new_string).
      edited="$(printf '%s' "$payload" | jq -r '
        [ .tool_input.new_string?, .tool_input.content?, (.tool_input.edits[]?.new_string?) ]
        | map(select(. != null)) | join("\n")' 2>/dev/null)"
      if [[ -n "$edited" ]]; then
        # Non-zero dimension literal: excludes EdgeInsets.all(0), SizedBox(width: 0), etc.
        num='([1-9][0-9]*(\.[0-9]+)?|0?\.[0-9]*[1-9])'
        dim_re="EdgeInsets\.(all|fromLTRB)\($num|EdgeInsets\.(symmetric|only)\([a-zA-Z]+:[[:space:]]*$num|BorderRadius\.circular\($num|SizedBox\((width|height):[[:space:]]*$num"
        if printf '%s' "$edited" | grep -qE '(\bconst[[:space:]]+)?Color\(0x[0-9A-Fa-f]{6,8}\)'; then
          add "hardcoded Color(0x..) literal - read the design value from UtopiaTheme/context instead of hardcoding (utopia-design-screen)"
        fi
        if printf '%s' "$edited" | grep -qE '\bColors\.(red|pink|purple|blue|indigo|cyan|teal|green|lime|yellow|amber|orange|brown|grey|gray|blueGrey)\b'; then
          add "Material Colors.<swatch> in a utopia_ui project - read a color.* token from UtopiaTheme/context instead (utopia-design-screen)"
        fi
        if printf '%s' "$edited" | grep -qE "$dim_re"; then
          add "hardcoded dimension literal - read spacing.* / radius.* from UtopiaTheme/context for a rebrandable scale (utopia-design-screen)"
        fi
      fi
    ;;
  esac
fi

# --- Report ---
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

# summary = one user-facing line; detail = full nudge list for the model.
summary="utopia-design: ${#violations[@]} design nudge(s) in $rel"
detail="$summary"
for v in "${violations[@]}"; do
  detail="$detail
  - $v"
done
detail="$detail

Invoke the matching utopia-design skill (Skill tool) before continuing. Set UTOPIA_DESIGN_MODE=block to make these blocking, or =silent to mute."

if [[ "$mode" == "block" ]]; then
  # exit 2 + stderr is the house blocking mechanism - reaches the model, must be addressed.
  printf '%s\n' "$detail" >&2
  exit 2
fi

# warn (default): reach the model without blocking. A plain exit-1 stderr goes only
# to the user, so emit a PostToolUse JSON payload - systemMessage for the user,
# hookSpecificOutput.additionalContext for the model - and exit 0 so it is honored.
jq -n --arg sm "$summary" --arg ac "$detail" \
  '{systemMessage: $sm, hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ac}}'
exit 0
