#!/usr/bin/env bash
# run_hook_smoke.sh - self-contained smoke test for the utopia-design hooks.
#
# Exercises scripts/session_start.sh and scripts/quality_check.sh against the
# with_utopia_ui / without_utopia_ui fixtures and asserts exit codes plus
# output. In warn mode the gate emits a PostToolUse JSON payload on stdout
# (systemMessage + hookSpecificOutput.additionalContext, exit 0); in block mode
# it prints to stderr and exits 2; silent mode is exit 0 with no output. Rule B
# scans the EDIT PAYLOAD (new_string / content / edits[].new_string), not the
# whole file. Cases 21-29 exercise the Rule A VALIDATOR HOOK (the wired
# `dart run utopia_design_tools:validate_tokens` call) via a fake `dart` PATH
# shim, so they run without a real dart toolchain or the utopia_design_tools
# package. Prints PASS/FAIL per case and a final tally.
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

# --- Validator-hook fixtures (dart shim + resolvable project) used by cases 21-27 ---
# Shim mechanic: a fake `dart` executable placed first on PATH. It touches a
# marker file (proves the validator was actually invoked) and, when pointed at
# a findings file, dumps it to stdout before exiting with a caller-chosen code -
# lets the smoke test drive quality_check.sh's validator branch without a real
# dart toolchain or the utopia_design_tools package.
shim_dir="$work_dir/shim"
mkdir -p "$shim_dir"
cat >"$shim_dir/dart" <<'EOF'
#!/usr/bin/env bash
# dart shim for validator-hook smoke cases.
touch "${DART_SHIM_MARKER:?}"
if [[ -n "${DART_SHIM_FINDINGS:-}" && -f "${DART_SHIM_FINDINGS}" ]]; then
  cat "${DART_SHIM_FINDINGS}"
fi
exit "${DART_SHIM_EXIT:-0}"
EOF
chmod +x "$shim_dir/dart"
dart_shim_marker="$work_dir/dart_shim_marker"

# Resolvable project: pubspec.lock declares utopia_design_tools (dev dep, same
# style as the utopia_ui entry above) AND .dart_tool/package_config.json lists
# it too, so both usage-gate checks in quality_check.sh's VALIDATOR HOOK pass.
validator_copy="$work_dir/validator_copy"
cp -R "$with_copy" "$validator_copy"
mkdir -p "$validator_copy/.dart_tool"
cat >"$validator_copy/pubspec.lock" <<'EOF'
# Generated by hand for smoke-test fixture purposes only - not a real pub lock.
packages:
  utopia_ui:
    dependency: "direct main"
    description:
      name: utopia_ui
      sha256: "0000000000000000000000000000000000000000000000000000000000000000"
      url: "https://pub.dev"
    source: hosted
    version: "0.1.0"
  utopia_design_tools:
    dependency: "direct dev"
    description:
      name: utopia_design_tools
      sha256: "0000000000000000000000000000000000000000000000000000000000000000"
      url: "https://pub.dev"
    source: hosted
    version: "0.1.0"
sdks:
  dart: ">=3.4.0 <4.0.0"
EOF
cat >"$validator_copy/.dart_tool/package_config.json" <<'EOF'
{"configVersion": 2, "packages": [{"name": "utopia_design_tools", "rootUri": "file:///dev/null", "packageUri": "lib/"}]}
EOF
validator_tokens="$validator_copy/design/tokens.json"
cat >"$validator_tokens" <<'EOF'
{
  "$schema": "https://design-tokens.github.io/community-group/format/",
  "color": {
    "primary": { "$type": "color", "$value": "#112233" }
  }
}
EOF
validator_broken_tokens="$validator_copy/design/broken.tokens.json"
echo '{not valid json' >"$validator_broken_tokens"

# Findings the shim prints when told to fail (exit 1): matches the H1 contract
# (ERROR/WARN lines, one per finding, with the summary line last).
findings_file="$work_dir/findings.txt"
cat >"$findings_file" <<'EOF'
ERROR color.primary: hex "#112233" does not match components
WARN spacing.md: derivation "x*3" expected value 12
2 error(s), 1 warning(s)
EOF

# Run quality_check with the dart shim first on PATH and the DART_SHIM_* env
# threaded through on the SAME command line as the hook invocation, so they
# reach the shim through the hook's own `dart run` subshell.
#   args: file mode out_file err_file shim_exit [findings_file] [validator_opt]
run_quality_check_validator() {
  local file="$1" mode="$2" out_file="$3" err_file="$4" shim_exit="$5"
  local findings="${6:-}" validator_opt="${7:-on}"
  local payload
  payload="$(jq -n --arg f "$file" '{tool_input:{file_path:$f}}')"
  rm -f "$dart_shim_marker"
  printf '%s' "$payload" \
    | UTOPIA_DESIGN_MODE="$mode" UTOPIA_DESIGN_VALIDATOR="$validator_opt" \
      PATH="$shim_dir:$PATH" DART_SHIM_MARKER="$dart_shim_marker" \
      DART_SHIM_EXIT="$shim_exit" DART_SHIM_FINDINGS="$findings" \
      bash "$quality_check" >"$out_file" 2>"$err_file"
  return $?
}

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

# --- Case 21: validator wired - shim reports findings (exit 1), warn -> exit 0 + nudge (marker present) ---
o="$work_dir/c21.out"; e="$work_dir/c21.err"
run_quality_check_validator "$validator_tokens" "warn" "$o" "$e" 1 "$findings_file"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "validate_tokens" && warn_has "$o" "color.primary" && [[ -f "$dart_shim_marker" ]]; then
  pass "validator wired: shim findings (exit 1), warn -> exit 0 + additionalContext names validate_tokens + finding (marker present)"
else
  fail "validator wired findings (rc=$rc; out=$(cat "$o"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 22: validator wired - shim passes (exit 0), warn -> exit 0 silent (marker present) ---
o="$work_dir/c22.out"; e="$work_dir/c22.err"
run_quality_check_validator "$validator_tokens" "warn" "$o" "$e" 0; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e" && [[ -f "$dart_shim_marker" ]]; then
  pass "validator wired: shim passes (exit 0), warn -> exit 0 silent, validator ran (marker present)"
else
  fail "validator pass (rc=$rc; out=$(cat "$o"); err=$(cat "$e"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 23: validator opt-out (UTOPIA_DESIGN_VALIDATOR=off) -> exit 0 silent, never invoked (marker absent) ---
o="$work_dir/c23.out"; e="$work_dir/c23.err"
run_quality_check_validator "$validator_tokens" "warn" "$o" "$e" 1 "$findings_file" "off"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e" && [[ ! -f "$dart_shim_marker" ]]; then
  pass "validator opt-out (UTOPIA_DESIGN_VALIDATOR=off) -> exit 0 silent, validator never invoked (marker absent)"
else
  fail "validator opt-out (rc=$rc; out=$(cat "$o"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 24: validator environment/setup error (shim exit 2) -> exit 0 silent, no nag (marker present) ---
o="$work_dir/c24.out"; e="$work_dir/c24.err"
run_quality_check_validator "$validator_tokens" "warn" "$o" "$e" 2; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e" && [[ -f "$dart_shim_marker" ]]; then
  pass "validator exit 2 (env/setup problem) -> exit 0 silent, no nag (marker present)"
else
  fail "validator exit 2 (rc=$rc; out=$(cat "$o"); err=$(cat "$e"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 25: project does not resolve utopia_design_tools -> validator never invoked (marker absent) ---
o="$work_dir/c25.out"; e="$work_dir/c25.err"
run_quality_check_validator "$valid_tokens" "warn" "$o" "$e" 1 "$findings_file"; rc=$?
if [[ $rc -eq 0 ]] && is_silent "$o" "$e" && [[ ! -f "$dart_shim_marker" ]]; then
  pass "project without utopia_design_tools -> exit 0 silent, validator never invoked (marker absent)"
else
  fail "non-resolvable project (rc=$rc; out=$(cat "$o"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 26: validator findings, block -> exit 2 + stderr names finding (marker present) ---
o="$work_dir/c26.out"; e="$work_dir/c26.err"
run_quality_check_validator "$validator_tokens" "block" "$o" "$e" 1 "$findings_file"; rc=$?
if [[ $rc -eq 2 ]] && [[ ! -s "$o" ]] && grep -q "color.primary" "$e" && [[ -f "$dart_shim_marker" ]]; then
  pass "validator findings, block -> exit 2 + stderr names finding (stdout empty, marker present)"
else
  fail "validator block (rc=$rc; out=$(cat "$o"); err=$(cat "$e"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 27: structural violation already fired -> validator skipped (marker absent) ---
o="$work_dir/c27.out"; e="$work_dir/c27.err"
run_quality_check_validator "$validator_broken_tokens" "warn" "$o" "$e" 1 "$findings_file"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "design/broken.tokens.json" && [[ ! -f "$dart_shim_marker" ]]; then
  pass "structural violation already fired -> validator skipped, additionalContext names file (marker absent)"
else
  fail "validator skipped on structural violation (rc=$rc; out=$(cat "$o"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 28: >8 findings -> first 8 surfaced + rollup line, 9th not shown (marker present) ---
findings_many_file="$work_dir/findings_many.txt"
: >"$findings_many_file"
for i in 1 2 3 4 5 6 7 8 9; do
  echo "ERROR color.c$i: bad value $i" >>"$findings_many_file"
done
echo "WARN spacing.md: check derivation" >>"$findings_many_file"
echo "9 error(s), 1 warning(s)" >>"$findings_many_file"
o="$work_dir/c28.out"; e="$work_dir/c28.err"
run_quality_check_validator "$validator_tokens" "warn" "$o" "$e" 1 "$findings_many_file"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "color.c8" && warn_has "$o" "plus 2 more" \
  && ! warn_has "$o" "color.c9" && [[ -f "$dart_shim_marker" ]]; then
  pass "validator >8 findings -> capped at 8 + rollup 'plus 2 more', 9th finding absent (marker present)"
else
  fail "validator rollup (rc=$rc; out=$(cat "$o"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Case 29: exit 1 with no parseable ERROR/WARN lines -> fallback violation, not silence ---
unparseable_file="$work_dir/findings_unparseable.txt"
echo "something unexpected happened" >"$unparseable_file"
o="$work_dir/c29.out"; e="$work_dir/c29.err"
run_quality_check_validator "$validator_tokens" "warn" "$o" "$e" 1 "$unparseable_file"; rc=$?
if [[ $rc -eq 0 ]] && warn_has "$o" "no parseable findings" && [[ -f "$dart_shim_marker" ]]; then
  pass "validator exit 1 without parseable findings -> fallback violation surfaced (marker present)"
else
  fail "validator unparseable fallback (rc=$rc; out=$(cat "$o"); marker=$([[ -f "$dart_shim_marker" ]] && echo present || echo absent))"
fi

# --- Summary ---
total=$((pass_count + fail_count))
echo ""
echo "SMOKE: $pass_count/$total passed"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
