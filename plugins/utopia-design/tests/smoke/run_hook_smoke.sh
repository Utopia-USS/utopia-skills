#!/usr/bin/env bash
# run_hook_smoke.sh - self-contained smoke test for the utopia-design hooks.
#
# Exercises scripts/session_start.sh and scripts/quality_check.sh against the
# with_utopia_ui / without_utopia_ui fixtures and asserts exit codes plus
# stdout/stderr content. Prints PASS/FAIL per case and a final tally.
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
mkdir -p "$with_copy/design" "$without_copy/design"

valid_tokens="$with_copy/design/valid.tokens.json"
broken_tokens="$with_copy/design/broken.tokens.json"
canonical_tokens="$with_copy/design/tokens.json"
canonical_broken="$with_copy/design/tokens.json"
hardcoded_dart="$with_copy/lib/hardcoded.dart"
swatch_dart="$with_copy/lib/swatch.dart"
dimension_dart="$with_copy/lib/dimension.dart"
radius_dart="$with_copy/lib/radius.dart"
benign_dart="$with_copy/lib/benign.dart"
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

cat >"$hardcoded_dart" <<'EOF'
import 'package:flutter/material.dart';

const swatch = Color(0xFF112233);
EOF

# Rule B - Material palette swatch (must fire).
cat >"$swatch_dart" <<'EOF'
import 'package:flutter/material.dart';

const c = Colors.blueGrey;
EOF

# Rule B - EdgeInsets.symmetric with a named-param px literal (must fire; this is
# the case the original regex silently missed).
cat >"$dimension_dart" <<'EOF'
import 'package:flutter/material.dart';

const p = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
EOF

# Rule B - BorderRadius.circular px literal (must fire).
cat >"$radius_dart" <<'EOF'
import 'package:flutter/material.dart';

final r = BorderRadius.circular(12);
EOF

# Rule B negative - only benign colors, no dimensions (must NOT fire).
cat >"$benign_dart" <<'EOF'
import 'package:flutter/material.dart';

const a = Colors.transparent;
const b = Colors.white;
const d = Colors.black;
EOF

echo '# fixture readme' >"$readme_file"

echo '{not valid json' >"$without_tokens"

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

run_quality_check() {
  # args: file_path mode
  local file="$1" mode="$2" out_file="$3" err_file="$4"
  local payload
  payload="$(printf '{"tool_input":{"file_path":"%s"}}' "$file")"
  printf '%s' "$payload" | UTOPIA_DESIGN_MODE="$mode" bash "$quality_check" >"$out_file" 2>"$err_file"
  return $?
}

# --- Case 3: valid tokens file inside with-fixture, mode=warn -> exit 0 ---
out3="$work_dir/case3.out"; err3="$work_dir/case3.err"
run_quality_check "$valid_tokens" "warn" "$out3" "$err3"
rc3=$?
if [[ $rc3 -eq 0 ]]; then
  pass "valid design/*.tokens.json edit -> exit 0"
else
  fail "valid design/*.tokens.json edit (rc=$rc3, expected 0; stderr: $(cat "$err3"))"
fi

# --- Case 4a: broken tokens file inside with-fixture, mode=warn -> exit 1, mentions file ---
out4a="$work_dir/case4a.out"; err4a="$work_dir/case4a.err"
run_quality_check "$broken_tokens" "warn" "$out4a" "$err4a"
rc4a=$?
if [[ $rc4a -eq 1 ]] && grep -q "design/broken.tokens.json" "$err4a"; then
  pass "broken tokens file, mode=warn -> exit 1 mentioning file"
else
  fail "broken tokens file, mode=warn (rc=$rc4a, expected 1; stderr: $(cat "$err4a"))"
fi

# --- Case 4b: broken tokens file inside with-fixture, mode=block -> exit 2 ---
out4b="$work_dir/case4b.out"; err4b="$work_dir/case4b.err"
run_quality_check "$broken_tokens" "block" "$out4b" "$err4b"
rc4b=$?
if [[ $rc4b -eq 2 ]]; then
  pass "broken tokens file, mode=block -> exit 2"
else
  fail "broken tokens file, mode=block (rc=$rc4b, expected 2; stderr: $(cat "$err4b"))"
fi

# --- Case 5a: dart file with hardcoded Color, mode=warn -> exit 1, mentions hardcoded ---
out5a="$work_dir/case5a.out"; err5a="$work_dir/case5a.err"
run_quality_check "$hardcoded_dart" "warn" "$out5a" "$err5a"
rc5a=$?
if [[ $rc5a -eq 1 ]] && grep -qi "hardcoded" "$err5a"; then
  pass "dart file with hardcoded Color, mode=warn -> exit 1 mentioning hardcoded"
else
  fail "dart file with hardcoded Color, mode=warn (rc=$rc5a, expected 1; stderr: $(cat "$err5a"))"
fi

# --- Case 5b: dart file with hardcoded Color, mode=silent -> exit 0 ---
out5b="$work_dir/case5b.out"; err5b="$work_dir/case5b.err"
run_quality_check "$hardcoded_dart" "silent" "$out5b" "$err5b"
rc5b=$?
if [[ $rc5b -eq 0 ]]; then
  pass "dart file with hardcoded Color, mode=silent -> exit 0"
else
  fail "dart file with hardcoded Color, mode=silent (rc=$rc5b, expected 0; stderr: $(cat "$err5b"))"
fi

# --- Case 6: non-scope file (README.md) inside with-fixture -> exit 0 silent ---
out6="$work_dir/case6.out"; err6="$work_dir/case6.err"
run_quality_check "$readme_file" "warn" "$out6" "$err6"
rc6=$?
if [[ $rc6 -eq 0 ]] && [[ ! -s "$err6" ]]; then
  pass "non-scope file (README.md) -> exit 0 silent"
else
  fail "non-scope file (README.md) (rc=$rc6, expected 0 silent; stderr: $(cat "$err6"))"
fi

# --- Case 7: tokens file inside WITHOUT-fixture (usage gate fails) -> exit 0 silent ---
out7="$work_dir/case7.out"; err7="$work_dir/case7.err"
run_quality_check "$without_tokens" "warn" "$out7" "$err7"
rc7=$?
if [[ $rc7 -eq 0 ]] && [[ ! -s "$err7" ]]; then
  pass "broken tokens file inside without_utopia_ui -> exit 0 silent (usage gate precedence)"
else
  fail "broken tokens file inside without_utopia_ui (rc=$rc7, expected 0 silent; stderr: $(cat "$err7"))"
fi

# --- Case 8: canonical unprefixed design/tokens.json (valid) -> exit 0 ---
cat >"$canonical_tokens" <<'EOF'
{
  "$schema": "https://design-tokens.github.io/community-group/format/",
  "spacing": { "md": { "$type": "dimension", "$value": "16px" } }
}
EOF
out8="$work_dir/case8.out"; err8="$work_dir/case8.err"
run_quality_check "$canonical_tokens" "warn" "$out8" "$err8"
rc8=$?
if [[ $rc8 -eq 0 ]]; then
  pass "valid canonical design/tokens.json edit -> exit 0"
else
  fail "valid canonical design/tokens.json (rc=$rc8, expected 0; stderr: $(cat "$err8"))"
fi

# --- Case 9: canonical unprefixed design/tokens.json (broken) -> exit 1, names file ---
echo '{not valid json' >"$canonical_broken"
out9="$work_dir/case9.out"; err9="$work_dir/case9.err"
run_quality_check "$canonical_broken" "warn" "$out9" "$err9"
rc9=$?
if [[ $rc9 -eq 1 ]] && grep -q "design/tokens.json" "$err9"; then
  pass "broken canonical design/tokens.json, mode=warn -> exit 1 naming file"
else
  fail "broken canonical design/tokens.json (rc=$rc9, expected 1 naming file; stderr: $(cat "$err9"))"
fi

# --- Case 10: Rule B Material palette swatch -> exit 1 ---
out10="$work_dir/case10.out"; err10="$work_dir/case10.err"
run_quality_check "$swatch_dart" "warn" "$out10" "$err10"
rc10=$?
if [[ $rc10 -eq 1 ]] && grep -qi "Colors" "$err10"; then
  pass "dart Colors.<swatch> -> exit 1 nudging tokens"
else
  fail "dart Colors.<swatch> (rc=$rc10, expected 1; stderr: $(cat "$err10"))"
fi

# --- Case 11: Rule B EdgeInsets.symmetric px literal -> exit 1 (regression for the dead-regex bug) ---
out11="$work_dir/case11.out"; err11="$work_dir/case11.err"
run_quality_check "$dimension_dart" "warn" "$out11" "$err11"
rc11=$?
if [[ $rc11 -eq 1 ]] && grep -qi "dimension" "$err11"; then
  pass "dart EdgeInsets.symmetric(named: px) -> exit 1 (dead-regex regression)"
else
  fail "dart EdgeInsets.symmetric px (rc=$rc11, expected 1; stderr: $(cat "$err11"))"
fi

# --- Case 12: Rule B BorderRadius.circular px literal -> exit 1 ---
out12="$work_dir/case12.out"; err12="$work_dir/case12.err"
run_quality_check "$radius_dart" "warn" "$out12" "$err12"
rc12=$?
if [[ $rc12 -eq 1 ]] && grep -qi "dimension" "$err12"; then
  pass "dart BorderRadius.circular(px) -> exit 1"
else
  fail "dart BorderRadius.circular(px) (rc=$rc12, expected 1; stderr: $(cat "$err12"))"
fi

# --- Case 13: Rule B benign colors only -> exit 0 (no false positive) ---
out13="$work_dir/case13.out"; err13="$work_dir/case13.err"
run_quality_check "$benign_dart" "warn" "$out13" "$err13"
rc13=$?
if [[ $rc13 -eq 0 ]] && [[ ! -s "$err13" ]]; then
  pass "dart benign colors (white/black/transparent) -> exit 0 silent (no false positive)"
else
  fail "dart benign colors (rc=$rc13, expected 0 silent; stderr: $(cat "$err13"))"
fi

# --- Case 14: lock-only transitive utopia_ui -> usage gate fires via pubspec.lock ---
out14="$work_dir/case14.out"; err14="$work_dir/case14.err"
run_quality_check "$lockonly_tokens" "warn" "$out14" "$err14"
rc14=$?
if [[ $rc14 -eq 1 ]] && grep -q "design/broken.tokens.json" "$err14"; then
  pass "lock-only transitive utopia_ui -> usage gate fires via pubspec.lock (exit 1)"
else
  fail "lock-only transitive utopia_ui (rc=$rc14, expected 1; stderr: $(cat "$err14"))"
fi

# --- Summary ---
total=$((pass_count + fail_count))
echo ""
echo "SMOKE: $pass_count/$total passed"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
