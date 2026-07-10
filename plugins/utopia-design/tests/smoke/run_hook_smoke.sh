#!/usr/bin/env bash
# run_hook_smoke.sh - self-contained smoke test for the utopia-design hooks.
#
# Exercises scripts/session_start.sh and scripts/quality_check.sh against the
# with_utopia_ui / without_utopia_ui fixtures and asserts exit codes plus
# output. In warn mode the gate emits a PostToolUse JSON payload on stdout
# (systemMessage + hookSpecificOutput.additionalContext, exit 0); in block mode
# it prints to stderr and exits 2; silent mode is exit 0 with no output. Rule B
# scans the EDIT PAYLOAD (new_string / content / edits[].new_string), not the
# whole file. Prints PASS/FAIL per case and a final tally.
# Compatible with macOS bash 3.2 (no mapfile, no assoc arrays).

set -u

# --- Resolve paths so this runs from anywhere ---
smoke_dir="$(cd "$(dirname -- "$0")" && pwd)"
plugin_root="$(cd "$smoke_dir/../.." && pwd)"
session_start="$plugin_root/scripts/session_start.sh"
quality_check="$plugin_root/scripts/quality_check.sh"
with_fixture="$plugin_root/tests/fixtures/with_utopia_ui"
without_fixture="$plugin_root/tests/fixtures/without_utopia_ui"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

pass_count=0
fail_count=0

pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

# Run quality_check with a crafted PostToolUse payload.
#   args: file mode out_file err_file [content]
# With a 5th arg the payload carries .tool_input.content (Write-shaped), so
# Rule B (which scans the payload) can see it. Without it, only file_path is
# sent (enough for Rule A, which reads the file on disk).
run_quality_check() {
  local file="$1" mode="$2" out_file="$3" err_file="$4"
  local payload
  if [[ $# -ge 5 ]]; then
    payload="$(jq -n --arg f "$file" --arg c "$5" '{tool_input:{file_path:$f, content:$c}}')"
  else
    payload="$(jq -n --arg f "$file" '{tool_input:{file_path:$f}}')"
  fi
  printf '%s' "$payload" | UTOPIA_DESIGN_MODE="$mode" bash "$quality_check" >"$out_file" 2>"$err_file"
  return $?
}

# warn-mode nudge present: stdout is a PostToolUse JSON whose additionalContext
# contains the needle.
warn_has() {
  local out="$1" needle="$2"
  jq -e '.hookSpecificOutput.additionalContext' "$out" >/dev/null 2>&1 || return 1
  jq -r '.hookSpecificOutput.additionalContext' "$out" 2>/dev/null | grep -q "$needle"
}

# silent: no stdout and no stderr.
is_silent() {
  [[ ! -s "$1" ]] && [[ ! -s "$2" ]]
}

# --- Case 1: session_start fires inside with_utopia_ui ---
out1="$work_dir/case1.out"
CLAUDE_PROJECT_DIR="$with_fixture" bash "$session_start" >"$out1" 2>/dev/null
rc1=$?
if [[ $rc1 -eq 0 ]] && grep -q "utopia-design-tokens" "$out1"; then
  pass "session_start fires in with_utopia_ui (exit 0, note printed)"
else
  fail "session_start fires in with_utopia_ui (rc=$rc1, expected 0 with note)"
fi

# --- Case 2: session_start silent inside without_utopia_ui ---
out2="$work_dir/case2.out"
CLAUDE_PROJECT_DIR="$without_fixture" bash "$session_start" >"$out2" 2>/dev/null
rc2=$?
if [[ $rc2 -eq 0 ]] && [[ ! -s "$out2" ]]; then
  pass "session_start silent in without_utopia_ui (exit 0, empty stdout)"
else
  fail "session_start silent in without_utopia_ui (rc=$rc2, stdout size=$(wc -c <"$out2" 2>/dev/null))"
fi

# --- Fixture copies for quality_check cases (usage gate needs a real project root) ---
with_copy="$work_dir/with_copy"
without_copy="$work_dir/without_copy"
cp -R "$with_fixture" "$with_copy"
cp -R "$without_fixture" "$without_copy"
mkdir -p "$with_copy/design" "$without_copy/design" "$with_copy/lib"

valid_tokens="$with_copy/design/valid.tokens.json"
broken_tokens="$with_copy/design/broken.tokens.json"
canonical_tokens="$with_copy/design/tokens.json"
any_dart="$with_copy/lib/widget.dart"
legacy_dart="$with_copy/lib/legacy.dart"
readme_file="$with_copy/README.md"
without_tokens="$without_copy/design/broken.tokens.json"

cat >"$valid_tokens" <<'EOF'
{
  "$schema": "https://design-tokens.github.io/community-group/format/",
  "color": {
    "primary": { "$type": "color", "$value": "#112233" }
  }
}
EOF

echo '{not valid json' >"$broken_tokens"
echo '# fixture readme' >"$readme_file"
echo '{not valid json' >"$without_tokens"

# A Dart file that exists on disk. Rule B reads the payload, not this content,
# so what is on disk only matters for the guard that the file exists - except in
# the payload-scoping case, where the on-disk literal must NOT be nagged.
cat >"$any_dart" <<'EOF'
import 'package:flutter/material.dart';

void build() {}
EOF

# Legacy file with a PRE-EXISTING literal on disk (used by the payload-scoping case).
cat >"$legacy_dart" <<'EOF'
import 'package:flutter/material.dart';

const legacy = Color(0xFF999999);
EOF

# Content payloads for Rule B cases.
color_content='const c = Color(0xFF112233);'
swatch_content='const c = Colors.blueGrey;'
symmetric_content='const p = EdgeInsets.symmetric(horizontal: 16, vertical: 8);'
radius_content='final r = BorderRadius.circular(12);'
benign_content='const a = Colors.transparent; const b = Colors.white; const d = Colors.black;'
zero_content='const p = EdgeInsets.all(0); const s = SizedBox(width: 0);'
clean_content='final x = someService.value;'

# Lock-only project: pubspec.yaml does NOT declare utopia_ui, but a pubspec.lock
# resolves it (transitive). The usage gate must still fire via the lock path.
lockonly_copy="$work_dir/lockonly_copy"
cp -R "$without_fixture" "$lockonly_copy"
mkdir -p "$lockonly_copy/design"
cat >"$lockonly_copy/pubspec.lock" <<'EOF'
packages:
  utopia_ui:
    dependency: transitive
    description:
      name: utopia_ui
      url: "https://pub.dev"
    source: hosted
    version: "0.1.0"
sdks:
  dart: ">=3.4.0 <4.0.0"
EOF
lockonly_tokens="$lockonly_copy/design/broken.tokens.json"
echo '{not valid json' >"$lockonly_tokens"

# --- Case 3: valid prefixed tokens file, warn -> exit 0 silent ---
o="$work_dir/c3.out"; e="$work_dir/c3.err"
run_quality_check "$valid_tokens" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "valid design/*.tokens.json edit -> exit 0 silent"
else
  fail "valid design/*.tokens.json (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 4a: broken prefixed tokens, warn -> exit 0 + JSON additionalContext names file ---
o="$work_dir/c4a.out"; e="$work_dir/c4a.err"
run_quality_check "$broken_tokens" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && [[ ! -s "$e" ]] && warn_has "$o" "design/broken.tokens.json"; then
  pass "broken tokens, warn -> exit 0 + additionalContext names file (stderr empty)"
else
  fail "broken tokens warn (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 4b: broken prefixed tokens, block -> exit 2 + stderr names file ---
o="$work_dir/c4b.out"; e="$work_dir/c4b.err"
run_quality_check "$broken_tokens" "block" "$o" "$e"; rc=$?
if [[ $rc -eq 2 ]] && [[ ! -s "$o" ]] && grep -q "design/broken.tokens.json" "$e"; then
  pass "broken tokens, block -> exit 2 + stderr names file (stdout empty)"
else
  fail "broken tokens block (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 5a: hardcoded Color in payload, warn -> exit 0 + nudge ---
o="$work_dir/c5a.out"; e="$work_dir/c5a.err"
run_quality_check "$any_dart" "warn" "$o" "$e" "$color_content"; rc=$?
if [[ $rc -eq 0 ]] && [[ ! -s "$e" ]] && warn_has "$o" "hardcoded Color"; then
  pass "payload hardcoded Color, warn -> exit 0 + nudge (stderr empty)"
else
  fail "payload hardcoded Color warn (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 5b: hardcoded Color in payload, silent -> exit 0 silent ---
o="$work_dir/c5b.out"; e="$work_dir/c5b.err"
run_quality_check "$any_dart" "silent" "$o" "$e" "$color_content"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "payload hardcoded Color, silent -> exit 0 silent"
else
  fail "payload hardcoded Color silent (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 5c: hardcoded Color in payload, block -> exit 2 + stderr nudge ---
o="$work_dir/c5c.out"; e="$work_dir/c5c.err"
run_quality_check "$any_dart" "block" "$o" "$e" "$color_content"; rc=$?
if [[ $rc -eq 2 ]] && [[ ! -s "$o" ]] && grep -q "hardcoded Color" "$e"; then
  pass "payload hardcoded Color, block -> exit 2 + stderr nudge (stdout empty)"
else
  fail "payload hardcoded Color block (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 6: non-scope file (README.md), warn -> exit 0 silent ---
o="$work_dir/c6.out"; e="$work_dir/c6.err"
run_quality_check "$readme_file" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "non-scope file (README.md) -> exit 0 silent"
else
  fail "non-scope file (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 7: broken tokens inside WITHOUT-fixture (usage gate fails) -> exit 0 silent ---
o="$work_dir/c7.out"; e="$work_dir/c7.err"
run_quality_check "$without_tokens" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "broken tokens in without_utopia_ui -> exit 0 silent (usage gate precedence)"
else
  fail "broken tokens without-fixture (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 8: valid canonical design/tokens.json, warn -> exit 0 silent ---
cat >"$canonical_tokens" <<'EOF'
{
  "$schema": "https://design-tokens.github.io/community-group/format/",
  "spacing": { "md": { "$type": "dimension", "$value": "16px" } }
}
EOF
o="$work_dir/c8.out"; e="$work_dir/c8.err"
run_quality_check "$canonical_tokens" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "valid canonical design/tokens.json -> exit 0 silent"
else
  fail "valid canonical tokens (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 9: broken canonical design/tokens.json, warn -> exit 0 + nudge names file (regression #1) ---
echo '{not valid json' >"$canonical_tokens"
o="$work_dir/c9.out"; e="$work_dir/c9.err"
run_quality_check "$canonical_tokens" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "design/tokens.json"; then
  pass "broken canonical design/tokens.json, warn -> exit 0 + nudge (regression for #1)"
else
  fail "broken canonical tokens (rc=$rc; out=$(cat "$o"))"
fi

# --- Case 10: Material palette swatch in payload, warn -> exit 0 + nudge ---
o="$work_dir/c10.out"; e="$work_dir/c10.err"
run_quality_check "$any_dart" "warn" "$o" "$e" "$swatch_content"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "Material Colors"; then
  pass "payload Colors.<swatch>, warn -> exit 0 + nudge"
else
  fail "payload swatch (rc=$rc; out=$(cat "$o"))"
fi

# --- Case 11: EdgeInsets.symmetric px in payload, warn -> exit 0 + nudge (regression #2 dead-regex) ---
o="$work_dir/c11.out"; e="$work_dir/c11.err"
run_quality_check "$any_dart" "warn" "$o" "$e" "$symmetric_content"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "dimension"; then
  pass "payload EdgeInsets.symmetric(named: px), warn -> exit 0 + nudge (dead-regex regression)"
else
  fail "payload symmetric px (rc=$rc; out=$(cat "$o"))"
fi

# --- Case 12: BorderRadius.circular px in payload, warn -> exit 0 + nudge ---
o="$work_dir/c12.out"; e="$work_dir/c12.err"
run_quality_check "$any_dart" "warn" "$o" "$e" "$radius_content"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "dimension"; then
  pass "payload BorderRadius.circular(px), warn -> exit 0 + nudge"
else
  fail "payload circular px (rc=$rc; out=$(cat "$o"))"
fi

# --- Case 13: benign colors only in payload, warn -> exit 0 silent (no false positive) ---
o="$work_dir/c13.out"; e="$work_dir/c13.err"
run_quality_check "$any_dart" "warn" "$o" "$e" "$benign_content"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "payload benign colors (white/black/transparent) -> exit 0 silent (no false positive)"
else
  fail "payload benign colors (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 14: lock-only transitive utopia_ui -> usage gate fires via pubspec.lock ---
o="$work_dir/c14.out"; e="$work_dir/c14.err"
run_quality_check "$lockonly_tokens" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "design/broken.tokens.json"; then
  pass "lock-only transitive utopia_ui -> usage gate fires via pubspec.lock (warn nudge)"
else
  fail "lock-only transitive (rc=$rc; out=$(cat "$o"))"
fi

# --- Case 15: payload-scoping - file has a literal on disk, payload does NOT -> exit 0 silent (regression #2) ---
o="$work_dir/c15.out"; e="$work_dir/c15.err"
run_quality_check "$legacy_dart" "warn" "$o" "$e" "$clean_content"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "legacy literal on disk but not in payload -> exit 0 silent (payload-scoping)"
else
  fail "payload-scoping (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 16: MultiEdit edits[].new_string with a Color -> exit 0 + nudge (edits[] extraction path) ---
o="$work_dir/c16.out"; e="$work_dir/c16.err"
me_payload="$(jq -n --arg f "$any_dart" \
  '{tool_input:{file_path:$f, edits:[{old_string:"void build() {}", new_string:"final c = Color(0xFF010203);"}]}}')"
printf '%s' "$me_payload" | UTOPIA_DESIGN_MODE=warn bash "$quality_check" >"$o" 2>"$e"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "hardcoded Color"; then
  pass "MultiEdit edits[].new_string Color -> exit 0 + nudge (edits[] path)"
else
  fail "MultiEdit edits path (rc=$rc; out=$(cat "$o"))"
fi

# --- Case 17: zero-value dimensions in payload -> exit 0 silent (no false positive) ---
o="$work_dir/c17.out"; e="$work_dir/c17.err"
run_quality_check "$any_dart" "warn" "$o" "$e" "$zero_content"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "payload EdgeInsets.all(0)/SizedBox(width: 0) -> exit 0 silent (zero excluded)"
else
  fail "zero-exclusion (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 18: warn JSON is well-formed and carries a user-facing systemMessage ---
o="$work_dir/c18.out"; e="$work_dir/c18.err"
run_quality_check "$broken_tokens" "warn" "$o" "$e"
if jq -e '.systemMessage and .hookSpecificOutput.hookEventName == "PostToolUse"' "$o" >/dev/null 2>&1; then
  pass "warn payload is valid JSON with systemMessage + PostToolUse hookEventName"
else
  fail "warn payload shape (out=$(cat "$o"))"
fi

# --- Case 19: generated Dart file skipped even with a literal in the payload ---
o="$work_dir/c19.out"; e="$work_dir/c19.err"
run_quality_check "$with_copy/lib/model.g.dart" "warn" "$o" "$e" "$color_content"; rc=$?
# model.g.dart does not exist on disk, so guard 3 (file must exist) already makes this exit 0
# silent; create it to prove the generated-file skip specifically.
cat >"$with_copy/lib/model.g.dart" <<'EOF'
const generated = 1;
EOF
run_quality_check "$with_copy/lib/model.g.dart" "warn" "$o" "$e" "$color_content"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "generated .g.dart with literal in payload -> exit 0 silent (generated skip)"
else
  fail "generated-file skip (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Case 20: .dart edit with NO edit-payload field -> Rule B skipped silently ---
# legacy_dart has an on-disk Color literal; sending only file_path (no new_string
# /content/edits) must leave Rule B with nothing to scan -> exit 0 silent.
o="$work_dir/c20.out"; e="$work_dir/c20.err"
run_quality_check "$legacy_dart" "warn" "$o" "$e"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e"; then
  pass "dart edit with no payload field -> exit 0 silent (Rule B degrades safely)"
else
  fail "dart no-payload-field (rc=$rc; out=$(cat "$o"); err=$(cat "$e"))"
fi

# --- Summary ---
total=$((pass_count + fail_count))
echo ""
echo "SMOKE: $pass_count/$total passed"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
