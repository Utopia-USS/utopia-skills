#!/usr/bin/env bash
# session_start.sh - SessionStart hook: deterministic skill activation.
#
# Detects utopia_hooks / utopia_arch in the project's pubspec(s) and, on a hit,
# prints a short context note instructing Claude to use the utopia-hooks skill.
# Contract:
#   - stdout on exit 0 is appended to the session context
#   - silent exit 0 for non-utopia projects (zero noise outside the ecosystem)
# Compatible with macOS bash 3.2 (no mapfile, no assoc arrays).

set -u

root="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -d "$root" ]] || exit 0

# Shallow scan: root pubspec plus nested package pubspecs (melos monorepos).
# Depth-limited and build/platform dirs pruned, so it stays fast on big repos.
found=""
while IFS= read -r pubspec; do
  if grep -qE '^[[:space:]]*(utopia_hooks|utopia_arch)[[:space:]]*:' "$pubspec" 2>/dev/null; then
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
This project depends on utopia_hooks (directly or via utopia_arch). All Flutter state
management follows the Screen/State/View pattern from the utopia-hooks skill.

Before writing or modifying any screen, state hook, global state, async/pagination
logic, DI wiring, or hook tests, invoke the utopia-hooks skill (Skill tool) and follow
the matching reference file. A PostToolUse hook enforces the core conventions on every
Dart edit - code written without the skill usually fails it.
EOF

if command -v utopia >/dev/null 2>&1; then
  cat <<'EOF'

The utopia CLI is installed. Prefer its deterministic surfaces over manual work:
`utopia describe -o -` to inspect screens/routes/global states, `utopia add screen
<name> --json` to scaffold a Screen/State/View triad, `utopia doctor` for a repo-wide
convention audit. Details: references/utopia-cli.md in the utopia-hooks skill.
EOF
else
  cat <<'EOF'

The utopia CLI is NOT on PATH, so the PostToolUse convention gate cannot run. Install
it with `dart pub global activate utopia_cli` (ensure $HOME/.pub-cache/bin is on PATH)
before editing Dart files.
EOF
fi
exit 0
