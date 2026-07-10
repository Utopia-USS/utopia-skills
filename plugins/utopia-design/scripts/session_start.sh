#!/usr/bin/env bash
# session_start.sh - SessionStart hook: deterministic skill activation.
#
# Detects whether the project resolves utopia_ui - either as a direct
# dependency in pubspec.yaml or as a resolved package in a sibling
# pubspec.lock (utopia_ui may be pulled in transitively) - and on a hit
# prints a short context note instructing Claude to use the utopia-design
# skills and follow the Utopia Design Protocol.
# Contract:
#   - stdout on exit 0 is appended to the session context
#   - silent exit 0 for projects that do not resolve utopia_ui (zero noise
#     outside the ecosystem)
# Compatible with macOS bash 3.2 (no mapfile, no assoc arrays).

set -u

root="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -d "$root" ]] || exit 0

# Shallow scan: root pubspec plus nested package pubspecs (melos monorepos).
# Depth-limited and build/platform dirs pruned, so it stays fast on big repos.
found=""
while IFS= read -r pubspec; do
  if grep -qE '^[[:space:]]*utopia_ui[[:space:]]*:' "$pubspec" 2>/dev/null; then
    found="$pubspec"
    break
  fi
  lock="$(dirname -- "$pubspec")/pubspec.lock"
  if [[ -f "$lock" ]] && grep -qE '^[[:space:]]*utopia_ui[[:space:]]*:' "$lock" 2>/dev/null; then
    found="$pubspec"
    break
  fi
done < <(find "$root" -maxdepth 3 -name pubspec.yaml \
  -not -path '*/build/*' -not -path '*/.dart_tool/*' -not -path '*/.symlinks/*' \
  -not -path '*/ios/*' -not -path '*/android/*' -not -path '*/macos/*' \
  -not -path '*/windows/*' -not -path '*/linux/*' -not -path '*/.git/*' \
  2>/dev/null | head -40)

[[ -z "$found" ]] && exit 0

cat <<'EOF'
This project uses the Utopia design system (utopia_ui) and follows the
Utopia Design Protocol: a shared design/tokens.json (DTCG format) is the
single source of truth, the Flutter theme and an HTML twin surface are both
generated from it, and screens are built from manifest components.

Four skills cover the protocol - invoke the matching one (Skill tool) before
doing design work:
  - utopia-design-tokens - create design/tokens.json (from the packaged
    default theme) if absent, then edit or rebrand it.
  - utopia-design-sync - regenerate the Flutter theme and twin surfaces from
    tokens.
  - utopia-design-import - bring in an external design source (a Figma DTCG
    export, foreign tokens.css / Tailwind @theme, a Claude Design handoff
    bundle, or a DESIGN.md).
  - utopia-design-screen - build a Flutter screen from an outside design
    using ONLY manifest components; unmapped elements are reported as gaps,
    never hand-rolled.

Screens compose with the utopia-hooks Screen/State/View pattern - defer to
that skill for state management. A PostToolUse hook checks edits to
design/*.tokens.json and flags hardcoded theme values in Dart edits; invoke
the matching skill above before doing design work.
EOF
exit 0
