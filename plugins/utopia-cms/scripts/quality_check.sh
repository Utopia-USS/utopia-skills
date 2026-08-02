#!/usr/bin/env bash
# quality_check.sh - catch the hand-rolled-CMS anti-pattern.
#
# Invoked as a Claude Code PostToolUse hook after Edit / Write / MultiEdit.
# Contract:
#   - stdin: JSON with {.tool_input.file_path}
#   - env UTOPIA_CMS_MODE: "warn" (default, exit 1) or "block" (exit 2)
#   - exit 0: silent success (file out of scope)
#   - exit 1: warn - user sees stderr, Claude continues
#   - exit 2: block - Claude must address
#
# Scope:
#   - file is *.dart inside lib/
#   - project's pubspec.yaml depends on utopia_cms OR sits in a known admin/cms package
#
# Anti-patterns we flag (each maps to a section in skills/utopia-cms/references/anti-patterns.md):
#   - Flutter DataTable inside an admin-context file
#   - hand-rolled loading triplet (useState<List<T>?> + isLoading + error)
#   - hand-rolled CRUD service shape in *_service.dart inside an admin package
#   - AlertDialog used as delete confirmation in admin context
#   - Navigator.pushNamedAndRemoveUntil for switching between admin tables
#   - utopia_cms not declared in pubspec for a recognizable admin package

set -u

mode="${UTOPIA_CMS_MODE:-warn}"
violations=()

# --- Read file path from stdin JSON ---
if ! command -v jq >/dev/null 2>&1; then
  echo "utopia-cms hook: jq not found - quality gate disabled (brew install jq)" >&2
  exit 1
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

# --- Classify file location ---
rel="${file#$project_root/}"
case "$rel" in
  lib/*) ;;
  *) exit 0 ;;
esac

# --- Detect "is this an admin/CMS package?" ---
# Heuristic 1: pubspec depends on utopia_cms
declares_utopia_cms=0
if grep -qE '^[[:space:]]*utopia_cms[[:space:]]*:' "$project_root/pubspec.yaml"; then
  declares_utopia_cms=1
fi

# Heuristic 1b: pubspec declares a backend delegate package without the core
# package. Delegate packages do NOT re-export utopia_cms, so the core dep is
# still required - used to pick a clearer rule-1 message below.
delegate_pkg="$(grep -E '^[[:space:]]*utopia_cms_(firebase|supabase|hasura|graphql)[[:space:]]*:' "$project_root/pubspec.yaml" 2>/dev/null \
  | head -1 | sed -E 's/^[[:space:]]*//; s/[[:space:]]*:.*$//')"

# Heuristic 2: package / directory name suggests admin
pkg_name="$(grep -E '^name:' "$project_root/pubspec.yaml" | head -1 | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
admin_like=0
case "$pkg_name" in
  *admin*|*cms*|*panel*|*backoffice*|*back_office*|*management*) admin_like=1 ;;
esac
# Also catch directory ancestors named admin/cms/panel
case "$project_root" in
  */admin|*/admin/*|*/cms|*/cms/*|*/panel|*/panel/*|*/backoffice|*/backoffice/*) admin_like=1 ;;
esac

# If neither indicator says "admin/CMS", we're out of scope.
if [[ $declares_utopia_cms -eq 0 && $admin_like -eq 0 ]]; then
  exit 0
fi

# Heuristic for whether file is "admin context" - used to reduce false positives
# on screen/page files. Service files always count if admin_like.
in_screen=0
case "$rel" in
  lib/screen/*|lib/screens/*|lib/*/screen/*|lib/*/screens/*|lib/*/pages/*|lib/pages/*|*_screen.dart|*_page.dart) in_screen=1 ;;
esac
in_service=0
case "$rel" in
  lib/services/*|lib/*/services/*|*_service.dart) in_service=1 ;;
esac
in_delegate=0
case "$rel" in
  lib/delegate/*|lib/*/delegate/*|*_delegate.dart) in_delegate=1 ;;
esac

# --- Helper ---
add() { violations+=("$1"); }

# --- 1) Admin-like package missing utopia_cms dependency ---
# Fire on any screen / service / app entry file to maximize visibility - the
# whole point is to nudge the agent to adopt the framework before it ships
# more hand-rolled CRUD code.
if [[ $admin_like -eq 1 && $declares_utopia_cms -eq 0 ]]; then
  case "$rel" in
    lib/main.dart|lib/app/app.dart|lib/app/app_*.dart|*_screen.dart|*_page.dart|*_view.dart|*_service.dart|lib/services/*|lib/screen/*|lib/screens/*|lib/pages/*)
      if [[ -n "$delegate_pkg" ]]; then
        add "pubspec declares $delegate_pkg but not utopia_cms core - add 'utopia_cms:' too; delegate packages do not re-export it (anti-patterns.md §1)"
      else
        add "admin/CMS-looking package '${pkg_name:-?}' does not depend on utopia_cms - add it and use CmsTablePage instead of hand-rolling tables (anti-patterns.md §1)"
      fi
    ;;
  esac
fi

# --- 2) Flutter DataTable inside an admin context ---
# DataTable in any admin lib/ file is almost always wrong.
if grep -qE '\bDataTable\s*\(' "$file"; then
  add "uses Flutter DataTable - admin tables should be CmsTablePage + CmsEntry list (anti-patterns.md §5)"
fi

# --- 3) Hand-rolled loading triplet (screen-context only) ---
if [[ $in_screen -eq 1 ]]; then
  has_list_state=0
  has_isLoading=0
  has_error=0
  # Match useState<List<...>?> or useState<IList<...>?> - the row buffer.
  # The '?' is optional: useState<List<Order>>([]) (init-with-empty-list) is
  # the same anti-pattern as the nullable variant.
  # `.+` (not `[^>]+`) so nested generics match: useState<List<Map<String, dynamic>>?>
  if grep -qE 'useState<[^>]*(List|IList)<.+>\??>' "$file"; then has_list_state=1; fi
  # Match useState<bool>(...) when paired with an isLoading variable. Don't require the literal `true`.
  if grep -qE 'useState<bool>\(' "$file" && grep -qE '\bisLoading(State)?\b' "$file"; then has_isLoading=1; fi
  # Match useState<String?>(...) when paired with an error variable.
  if grep -qE 'useState<String\?>\(' "$file" && grep -qE '\b(error(State|Message)?)\b' "$file"; then has_error=1; fi

  triplet=$((has_list_state + has_isLoading + has_error))
  # Require all three signals to avoid false positives on screens that legitimately track loading.
  if [[ $triplet -eq 3 ]] && ! grep -q 'CmsTablePage' "$file"; then
    add "hand-rolled loading-state triplet (useState<List> + isLoading + error) - replace with CmsTablePage (anti-patterns.md §4)"
  fi
fi

# --- 4) Hand-rolled CRUD service ---
if [[ $in_service -eq 1 ]] && ! grep -q 'CmsDelegate\|extends Cms.*Delegate\|implements CmsDelegate' "$file"; then
  crud_hits=0
  grep -qE 'Future<[^>]+>\s+load[A-Z]'   "$file" && crud_hits=$((crud_hits+1))
  grep -qE 'Future<[^>]+>\s+create[A-Z]' "$file" && crud_hits=$((crud_hits+1))
  grep -qE 'Future<[^>]+>\s+update[A-Z]' "$file" && crud_hits=$((crud_hits+1))
  grep -qE 'Future<[^>]+>\s+delete[A-Z]' "$file" && crud_hits=$((crud_hits+1))
  if [[ $crud_hits -ge 3 ]]; then
    add "service file declares load/create/update/delete - convert into a CmsDelegate subclass (delegates.md, anti-patterns.md §6)"
  fi
fi

# --- 5) AlertDialog as delete confirmation in admin context ---
# Require BOTH AlertDialog AND a confirm-delete-shaped string nearby - avoids
# tripping on every screen that mentions "delete" in unrelated code. "are you
# sure" alone is not delete-shaped (sign-out confirmations use it too); it must
# co-occur with delete/remove on the same line.
if [[ $in_screen -eq 1 ]] && grep -q 'AlertDialog' "$file"; then
  if grep -qiE "(delete this|delete \"|delete '|delete \\\$|are you sure.*(delete|remove)|confirm delete)" "$file"; then
    add "AlertDialog used for delete confirmation - CmsTablePage's delete flow uses CmsDialog automatically (anti-patterns.md §7)"
  fi
fi

# --- 6) Cross-admin navigation between tables ---
if grep -q 'pushNamedAndRemoveUntil' "$file" && grep -qE '(AppRoutes\.[a-zA-Z_]+|/admin/|/cms/)' "$file"; then
  # Auth-flow guard: when the only AppRoutes references are auth-ish
  # (login / sign-in / splash), this is a legitimate sign-out flow, not
  # table-to-table navigation. BSD-safe: extract all AppRoutes refs and
  # check whether any non-auth ref remains.
  flag_nav=1
  if grep -qE 'AppRoutes\.(login|signIn|signin|auth|splash)' "$file" \
     && ! grep -oE 'AppRoutes\.[a-zA-Z_]+' "$file" \
        | grep -vE '^AppRoutes\.(login|signIn|signin|auth|splash)$' \
        | grep -q .; then
    flag_nav=0
  fi
  if [[ $flag_nav -eq 1 ]]; then
    add "Navigator.pushNamedAndRemoveUntil between admin pages - use one CmsWidget with CmsWidgetItem.page entries (anti-patterns.md §3)"
  fi
fi

# --- 7) Re-export utopia_cms src/ (private import) ---
if grep -qE "import 'package:utopia_cms/src/" "$file"; then
  add "imports from package:utopia_cms/src/ - use the public export 'package:utopia_cms/utopia_cms.dart' (SKILL.md rules)"
fi

# --- 8) Custom IconButton column with edit + delete in same file ---
if [[ $in_screen -eq 1 ]] && grep -qE 'Icons\.edit\b' "$file" && grep -qE 'Icons\.delete\b' "$file"; then
  # only flag if we see both per-row edit and delete handcrafted AND a row-ish
  # context (table / list builder) in the same file - an AppBar edit icon plus
  # an unrelated delete icon elsewhere is not the per-row anti-pattern
  if grep -qE 'IconButton\s*\(' "$file" \
     && grep -qE 'DataRow|DataTable|itemBuilder|ListView|ListTile|TableRow' "$file"; then
    add "per-row IconButton edit/delete - use CmsTableParams(canEdit/canDelete) and customActions for the rest (anti-patterns.md §8)"
  fi
fi

# --- Report ---
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

{
  echo "utopia-cms quality_check: ${#violations[@]} violation(s) in $rel"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "Fix guidance: invoke the utopia-cms skill (Skill tool) - each rule above maps to a references/anti-patterns.md section (delegates live in delegates.md)."
  echo "(mode: $mode - set UTOPIA_CMS_MODE=block to make these blocking)"
} >&2

if [[ "$mode" == "block" ]]; then
  exit 2
else
  exit 1
fi
