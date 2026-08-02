#!/usr/bin/env bash
# BLUEPRINT - adapt per-repo. Strip this banner after substitution.
# <repo>_skills_drift.sh - Drift scan over .claude/**/*.md and CLAUDE.md.
#
# Finds dead markdown links - inline `[text](path)` and reference-style
# `[label]: path` definitions - whose target file is missing. Skips:
# http(s)/mailto/tel/ftp/ssh targets, intra-doc anchors (#...), regex/glob
# metacharacters, angle-bracket placeholders, bare placeholder words, the
# contents of ``` fenced code blocks, and files whose basename starts with
# `_` (authoring templates - their links are examples, not references).
#
# Modes
#   <repo>_skills_drift.sh --all    Full scan across .claude/ + CLAUDE.md.
#                                   Findings to stderr; exit 1 if any dead
#                                   link, 0 if clean.
#   <repo>_skills_drift.sh          PostToolUse hook mode - reads JSON from
#                                   stdin, scans the edited file only.
#
# Hook contract
#   exit 0 - out of scope, or in scope and clean
#   exit 1 - warn (<REPO>_QUALITY_MODE unset or "warn")
#   exit 2 - block (<REPO>_QUALITY_MODE=block)

set -u

repo_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
mode="${<REPO>_QUALITY_MODE:-warn}"

# ---------------------------------------------------------------------------
# check_target <target> <file_dir> <rel> <lineno>
#   Applies the skip rules; prints a finding when the target doesn't resolve.
# ---------------------------------------------------------------------------
check_target() {
  local target="$1" file_dir="$2" rel="$3" lineno="$4"
  [[ -z "$target" ]] && return 0

  # External / non-filesystem targets.
  case "$target" in
    http://*|https://*|mailto:*|tel:*|ftp://*|ssh://*|'#'*) return 0 ;;
    '\'*) return 0 ;;
  esac
  # Regex / glob metacharacters - not a real path.
  [[ "$target" == *'|'* ]] && return 0
  [[ "$target" == *'*'* ]] && return 0
  # Angle-bracket placeholders like <name>.md.
  [[ "$target" == *'<'* || "$target" == *'>'* ]] && return 0
  # Bare placeholder words (no slash, no dot) like `path`, `target`.
  [[ "$target" != */* && "$target" != *.* ]] && return 0

  # Strip any trailing #anchor before the existence check.
  target="${target%%#*}"
  [[ -z "$target" ]] && return 0

  local resolved
  if [[ "$target" = /* ]]; then
    resolved="$repo_root$target"
  else
    resolved="$file_dir/$target"
  fi

  if [[ ! -e "$resolved" ]]; then
    printf '%s:%d - broken link: %s\n' "$rel" "$lineno" "$target"
  fi
}

# ---------------------------------------------------------------------------
# scan_file <path>
#   Emits "<rel>:<lineno> - broken link: <target>" for each dead link.
# ---------------------------------------------------------------------------
scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  # Skip authoring-template files (basename starts with `_`).
  local base
  base="$(basename "$file")"
  [[ "$base" == _* ]] && return 0

  local file_dir
  file_dir="$(cd "$(dirname "$file")" 2>/dev/null && pwd)" || return 0
  local rel="${file#$repo_root/}"

  local lineno=0
  local in_fence=0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))

    # Track triple-backtick fenced code blocks - skip their contents.
    if [[ "$line" == '```'* ]]; then
      in_fence=$((1 - in_fence))
      continue
    fi
    [[ $in_fence -eq 1 ]] && continue

    # Inline links: each ](target) on this line.
    local target
    while IFS= read -r target; do
      check_target "$target" "$file_dir" "$rel" "$lineno"
    done < <(
      printf '%s\n' "$line" \
        | grep -oE '\]\([^)]+\)' \
        | sed -n -E 's/^\]\(([^) "#]+).*\)$/\1/p'
    )

    # Reference-style definitions: `[label]: target` at line start.
    target="$(printf '%s\n' "$line" | sed -n -E 's/^\[[^]]+\]:[[:space:]]*([^ ]+).*$/\1/p')"
    [[ -n "$target" ]] && check_target "$target" "$file_dir" "$rel" "$lineno"
  done < "$file"
}

# ---------------------------------------------------------------------------
# Full-scan mode
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--all" ]]; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  if [[ -d "$repo_root/.claude" ]]; then
    while IFS= read -r -d '' f; do
      scan_file "$f" >> "$tmp"
    done < <(find "$repo_root/.claude" -name '*.md' -type f -print0 2>/dev/null)
  fi
  [[ -f "$repo_root/CLAUDE.md" ]] && scan_file "$repo_root/CLAUDE.md" >> "$tmp"

  found=$(wc -l < "$tmp" | tr -d ' ')
  if [[ "$found" -gt 0 ]]; then
    cat "$tmp" >&2
    {
      echo ""
      echo "<repo>_skills_drift: $found broken reference(s) across .claude/ + CLAUDE.md"
    } >&2
    exit 1
  fi
  echo "<repo>_skills_drift: clean - no broken references in .claude/ or CLAUDE.md"
  exit 0
fi

# ---------------------------------------------------------------------------
# Hook mode (stdin JSON)
# ---------------------------------------------------------------------------
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$file" ]] && exit 0

# In scope: markdown under .claude/ at any depth, or repo-root CLAUDE.md.
case "$file" in
  */.claude/*.md|*/CLAUDE.md) ;;
  *) exit 0 ;;
esac

issues=()
while IFS= read -r line; do
  issues+=("$line")
done < <(scan_file "$file")

[[ ${#issues[@]} -eq 0 ]] && exit 0

{
  echo "<repo>_skills_drift: ${#issues[@]} broken reference(s) in edited file"
  for i in "${issues[@]}"; do
    echo "  $i"
  done
  echo ""
  echo "(mode: $mode - set <REPO>_QUALITY_MODE=block to make this blocking)"
  echo "Full scan: bash \${CLAUDE_PROJECT_DIR}/.claude/scripts/<repo>_skills_drift.sh --all"
} >&2

if [[ "$mode" == "block" ]]; then
  exit 2
else
  exit 1
fi
