#!/usr/bin/env bash
# BLUEPRINT - adapt per-repo. Strip this banner after substitution.
# <repo>_quality_check.sh - PostToolUse quality check for the <project> repo.
#
# Contract:
#   - stdin:  JSON with {.tool_input.file_path}
#   - env <REPO>_QUALITY_MODE: "warn" (default, exit 1) or "block" (exit 2)
#     Note: edits to generated files ALWAYS exit 2 regardless of mode.
#   - exit 0: silent (out of scope or clean)
#   - exit 1: warn - user sees stderr, Claude continues
#   - exit 2: block - Claude must address
#
# Scope:
#   - Fires only for edits inside this repo, on file types this layer cares about.
#   - Hard-blocks edits to generated files (extensions configured per repo).
#   - Surfaces path → skill nudges that mirror each skill's `applicability`.
#   - Foundation conventions (hook / Screen-State-View / IList) are enforced
#     by the upstream utopia-hooks plugin - not here.

set -u

mode="${<REPO>_QUALITY_MODE:-warn}"
violations=()

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$file" ]] && exit 0

# ---------------------------------------------------------------------------
# Hard block: generated files (always, regardless of mode).
# Configure extensions per repo.
# ---------------------------------------------------------------------------
case "$(basename "$file")" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|\
  *.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart)
    {
      echo "<repo>_quality_check: BLOCK - attempted edit to generated file"
      echo "  $file"
      echo ""
      echo "Generated files must not be edited manually. Regenerate with:"
      echo "  <repo-specific build_runner / codegen command>"
    } >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Guards - proceed only for in-scope files
# ---------------------------------------------------------------------------
[[ -f "$file" ]] || exit 0
[[ "$file" == *.dart ]] || exit 0  # adjust per repo

# Walk to nearest pubspec.yaml (workspace package root)
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

# Walk to repo root
repo_root=""
dir="$project_root"
while [[ "$dir" != "/" && -n "$dir" ]]; do
  if [[ -e "$dir/.git" ]]; then
    repo_root="$dir"
    break
  fi
  dir="$(dirname -- "$dir")"
done
[[ -z "$repo_root" ]] && exit 0

# Confirm we're inside THIS repo (avoid firing in unrelated workspaces)
[[ "$(basename "$repo_root")" == "<repo-folder-name>" ]] || exit 0

repo_rel="${file#$repo_root/}"

add() { violations+=("$1"); }

# ---------------------------------------------------------------------------
# Universal: relative imports in lib/ (foundation already enforces, but
# this layer surfaces it explicitly for clarity)
# ---------------------------------------------------------------------------
if [[ "$repo_rel" == lib/* || "$repo_rel" == */lib/* ]]; then
  if grep -qE "^import[[:space:]]+['\"](\.\./|\./)" "$file"; then
    add "uses relative Dart import - repo convention requires 'package:...' imports (always_use_package_imports)"
  fi
fi

# ---------------------------------------------------------------------------
# Path → skill nudges. Mirror each skill's `applicability` from §2 of
# .claude/docs/claude-architecture.md.
#
# Each case body adds a single advisory line pointing at the skill whose
# conventions cover this path. Keep the message short - Claude already
# loads the skill's own SKILL.md when description matches.
# ---------------------------------------------------------------------------

case "$repo_rel" in
  <area-1-paths>)
    add "<area-1> edit - consult <repo>-<area-1> skill"
    ;;
esac

case "$repo_rel" in
  <area-2-paths>)
    add "<area-2> edit - consult <repo>-<area-2> skill"
    ;;
esac

# ... add cases per skill with ≥2 references; delete unused blocks ...

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

{
  echo "<repo>_quality_check: ${#violations[@]} nudge(s) in ${repo_rel}"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "(mode: $mode - set <REPO>_QUALITY_MODE=block to make non-generated-file nudges blocking)"
  echo "(foundation conventions are enforced by the upstream utopia-hooks plugin)"
} >&2

if [[ "$mode" == "block" ]]; then
  exit 2
else
  exit 1
fi
