#!/bin/bash
# op-env test suite — raw bash, no framework dependencies
# Run: bash test/test-op-env.sh
#
# MANUAL TESTS (cannot be automated in CI):
#
# 1. TTY Preservation:
#    Run: op-env --tpl ~/.claude/.env.tpl claude
#    Verify: Claude Code launches with interactive UI (not --print mode)
#    Verify: Terminal dimensions are correct
#    Verify: Ctrl+C works
#
# 2. Real 1Password Resolution:
#    Run: op-env --check
#    Verify: All keys show "set" with correct 2-char prefixes
#    Verify: Biometric prompt appears once
#
# 3. op-env-scan with Real Secrets:
#    Stage a file containing a real resolved value
#    Run: op-env-scan
#    Verify: BLOCKED message with correct key name and line number

set -uo pipefail
# Note: no set -e — tests intentionally trigger non-zero exits

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OP_ENV="$REPO_DIR/bin/op-env"
OP_ENV_SCAN="$REPO_DIR/bin/op-env-scan"
FIXTURES="$SCRIPT_DIR/fixtures"
HELPERS="$SCRIPT_DIR/helpers"

# shellcheck source=test/helpers/assert.sh
source "$HELPERS/assert.sh"

# Put mock op first in PATH (named 'op' so op-env finds it instead of real op)
export PATH="$HELPERS:$PATH"
chmod +x "$HELPERS/op" "$HELPERS/check-env.sh"

echo "Running op-env test suite..."
echo ""

# ============================================================
# Category 1: Bash 3.2 Compatibility (Regression Prevention)
# ============================================================

echo "--- Bash 3.2 Compatibility ---"

result=$(grep -cE '\bmapfile\b|\breadarray\b' "$OP_ENV" || true)
assert_eq "0" "$result" "op-env has no mapfile/readarray"

result=$(grep -cE '\bmapfile\b|\breadarray\b' "$OP_ENV_SCAN" || true)
assert_eq "0" "$result" "op-env-scan has no mapfile/readarray"

result=$(grep -cE 'declare -A' "$OP_ENV" || true)
assert_eq "0" "$result" "op-env has no associative arrays"

result=$(grep -cE 'declare -A' "$OP_ENV_SCAN" || true)
assert_eq "0" "$result" "op-env-scan has no associative arrays"

# ============================================================
# Category 2: Flag Parsing
# ============================================================

echo "--- Flag Parsing ---"

# --help prints usage and exits 0
stderr=$(bash "$OP_ENV" --help 2>&1 1>/dev/null)
assert_contains "$stderr" "USAGE:" "--help prints usage"
assert_contains "$stderr" "--tpl" "--help lists --tpl flag"
assert_contains "$stderr" "--check" "--help lists --check flag"
assert_contains "$stderr" "op-env-scan" "--help mentions companion tool"

help_exit=0
bash "$OP_ENV" --help >/dev/null 2>&1 || help_exit=$?
assert_eq "0" "$help_exit" "--help exits 0"

# -h short form
stderr=$(bash "$OP_ENV" -h 2>&1 1>/dev/null)
assert_contains "$stderr" "USAGE:" "-h prints usage"

# --version prints version from VERSION file and exits 0
expected_version=$(cat "$REPO_DIR/version.txt")
stderr=$(bash "$OP_ENV" --version 2>&1 1>/dev/null)
assert_contains "$stderr" "op-env $expected_version" "--version prints version from VERSION file"

ver_exit=0
bash "$OP_ENV" --version >/dev/null 2>&1 || ver_exit=$?
assert_eq "0" "$ver_exit" "--version exits 0"

# -v short form
stderr=$(bash "$OP_ENV" -v 2>&1 1>/dev/null)
assert_contains "$stderr" "op-env 0." "-v prints version string"

# --tpl with valid fixture
output=$(bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" --check 2>/dev/null)
assert_contains "$output" "TEST_KEY_A" "--tpl with valid fixture resolves keys"

# --tpl without argument
stderr=$(bash "$OP_ENV" --tpl 2>&1 || true)
assert_contains "$stderr" "requires an argument" "--tpl without argument shows error"

# --tpl with nonexistent file
stderr=$(bash "$OP_ENV" --tpl /nonexistent/path --check 2>&1 || true)
assert_contains "$stderr" "template not found" "--tpl nonexistent shows error"

# OP_ENV_TPL env var
output=$(OP_ENV_TPL="$FIXTURES/test.tpl" bash "$OP_ENV" --check 2>/dev/null)
assert_contains "$output" "TEST_KEY_A" "OP_ENV_TPL env var works"

# Flag order independence
output1=$(bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" 2>/dev/null)
output2=$(bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" --check 2>/dev/null)
assert_eq "$output1" "$output2" "Flag order is independent"

# Unknown flags pass through to command
output=$(bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" "$HELPERS/check-env.sh" 2>/dev/null)
assert_contains "$output" "EXEC_HAPPENED=true" "Unknown args pass through to exec target"

# ============================================================
# Category 3: Check Mode
# ============================================================

echo "--- Check Mode ---"

# Check shows set keys with preview
output=$(bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" 2>/dev/null)
assert_contains "$output" "TEST_KEY_A: set (mo...)" "Check shows set with 2-char preview"
assert_contains "$output" "resolved from" "Check shows summary line"

# Check with missing keys
output=$(MOCK_OP_SKIP_KEYS="TEST_KEY_B" bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" 2>/dev/null || true)
assert_contains "$output" "TEST_KEY_B: MISSING" "Check shows MISSING for skipped key"

# Check does not exec
output=$(bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" echo "SHOULD_NOT_APPEAR" 2>/dev/null)
assert_not_contains "$output" "SHOULD_NOT_APPEAR" "Check mode does not exec target command"

# Check preview does not show full value
output=$(bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" 2>/dev/null)
assert_not_contains "$output" "mock_TEST_KEY_A_value_12345678" "Check does not show full secret value"

# Check exits 1 when keys missing
MOCK_OP_SKIP_KEYS="TEST_KEY_B" bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" >/dev/null 2>&1
check_exit=$?
assert_eq "1" "$check_exit" "Check exits 1 when keys missing"

# Check exits 0 when all resolved
bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" >/dev/null 2>&1
check_exit=$?
assert_eq "0" "$check_exit" "Check exits 0 when all resolved"

# ============================================================
# Category 4: Validation
# ============================================================

echo "--- Validation ---"

# All resolved — exec happens
output=$(bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" "$HELPERS/check-env.sh" TEST_KEY_A 2>/dev/null)
assert_contains "$output" "EXEC_HAPPENED=true" "All resolved: exec happens"
assert_contains "$output" "TEST_KEY_A=mock_TEST_KEY_A_value_12345678" "All resolved: env var exported correctly"

# Missing keys — aborts
stderr=$(MOCK_OP_SKIP_KEYS="TEST_KEY_B,TEST_KEY_C" bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" echo hi 2>&1 1>/dev/null || true)
assert_contains "$stderr" "MISSING" "Missing keys: prints MISSING"
assert_contains "$stderr" "aborting" "Missing keys: prints aborting"

MOCK_OP_SKIP_KEYS="TEST_KEY_B" bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" echo hi >/dev/null 2>&1
val_exit=$?
assert_eq "1" "$val_exit" "Missing keys: exits 1"

# --partial allows launch with missing
output=$(MOCK_OP_SKIP_KEYS="TEST_KEY_B" bash "$OP_ENV" --partial --tpl "$FIXTURES/test.tpl" "$HELPERS/check-env.sh" 2>/dev/null)
assert_contains "$output" "EXEC_HAPPENED=true" "Partial: exec happens despite missing key"

stderr=$(MOCK_OP_SKIP_KEYS="TEST_KEY_B" bash "$OP_ENV" --partial --tpl "$FIXTURES/test.tpl" "$HELPERS/check-env.sh" 2>&1 1>/dev/null)
assert_contains "$stderr" "WARNING" "Partial: prints warning"

# ============================================================
# Category 5: Output Routing
# ============================================================

echo "--- Output Routing ---"

# Count on stderr not stdout
stdout=$(bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" echo hi 2>/dev/null)
assert_not_contains "$stdout" "secrets resolved" "Count is not on stdout"

stderr=$(bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" echo hi 2>&1 1>/dev/null)
assert_contains "$stderr" "secrets resolved" "Count is on stderr"

# --quiet suppresses count
stderr=$(bash "$OP_ENV" -q --tpl "$FIXTURES/test.tpl" echo hi 2>&1 1>/dev/null)
assert_not_contains "$stderr" "secrets resolved" "Quiet suppresses count"

# --quiet long form
stderr=$(bash "$OP_ENV" --quiet --tpl "$FIXTURES/test.tpl" echo hi 2>&1 1>/dev/null)
assert_not_contains "$stderr" "secrets resolved" "Quiet long form suppresses count"

# Check output on stdout
stdout=$(bash "$OP_ENV" --check --tpl "$FIXTURES/test.tpl" 2>/dev/null)
assert_contains "$stdout" "set (" "Check output is on stdout"

# ============================================================
# Category 6: Edge Cases
# ============================================================

echo "--- Edge Cases ---"

# Empty template
output=$(bash "$OP_ENV" --tpl "$FIXTURES/test-empty.tpl" "$HELPERS/check-env.sh" 2>/dev/null)
assert_contains "$output" "EXEC_HAPPENED=true" "Empty template: exec still happens"

# Comments-only template
output=$(bash "$OP_ENV" --tpl "$FIXTURES/test-comments.tpl" "$HELPERS/check-env.sh" 2>/dev/null)
assert_contains "$output" "EXEC_HAPPENED=true" "Comments-only template: exec still happens"

# Empty op output (all resolution fails) — should not crash
stderr=$(MOCK_OP_FAIL=1 bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" echo hi 2>&1 || true)
assert_not_contains "$stderr" "not a valid identifier" "Empty op output: no export crash"
assert_contains "$stderr" "MISSING" "Empty op output: validation catches missing keys"

# ============================================================
# Category 7: Regression Tests
# ============================================================

echo "--- Regression Tests ---"

# Regression: no mapfile in source (bash 3.2 compat)
result=$(grep -c 'mapfile' "$OP_ENV" || true)
assert_eq "0" "$result" "REGRESSION: no mapfile in op-env"

result=$(grep -c 'mapfile' "$OP_ENV_SCAN" || true)
assert_eq "0" "$result" "REGRESSION: no mapfile in op-env-scan"

# Regression: empty export guard
stderr=$(MOCK_OP_FAIL=1 bash "$OP_ENV" --tpl "$FIXTURES/test.tpl" echo hi 2>&1 || true)
assert_not_contains "$stderr" "export" "REGRESSION: no export error on empty op output"

# ============================================================
# Category 8: op-env-scan
# ============================================================

echo "--- op-env-scan ---"

# Create temp git repo for scan tests
SCAN_TMPDIR=$(mktemp -d)
cleanup_scan() { rm -rf "$SCAN_TMPDIR"; }
trap cleanup_scan EXIT

(
  cd "$SCAN_TMPDIR" || exit
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # Need an initial commit for git diff --cached to work
  echo "initial" > init.txt
  git add init.txt
  git commit -q -m "init"
)

# No staged files — exits 0
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1)
scan_exit=$?
assert_eq "0" "$scan_exit" "Scan: no staged files exits 0"
assert_contains "$stderr" "no staged files" "Scan: reports no staged files"

# Staged file with leaked value — exits 1
echo "some code with mock_TEST_KEY_A_value_12345678 hardcoded" > "$SCAN_TMPDIR/leaked.txt"
(cd "$SCAN_TMPDIR" && git add leaked.txt)
scan_exit=0
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1) || scan_exit=$?
assert_eq "1" "$scan_exit" "Scan: leaked value detected exits 1"
assert_contains "$stderr" "BLOCKED" "Scan: prints BLOCKED"
assert_contains "$stderr" "TEST_KEY_A" "Scan: identifies the leaked key"

# Reset for next test
(cd "$SCAN_TMPDIR" && git reset -q HEAD -- leaked.txt 2>/dev/null || true)
rm -f "$SCAN_TMPDIR/leaked.txt"

# Clean file (no leaked value) — exits 0
echo "this file has no secrets in it" > "$SCAN_TMPDIR/clean.txt"
(cd "$SCAN_TMPDIR" && git add clean.txt)
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1)
scan_exit=$?
assert_eq "0" "$scan_exit" "Scan: clean file exits 0"
assert_contains "$stderr" "No leaks found" "Scan: reports no leaks"
(cd "$SCAN_TMPDIR" && git reset -q HEAD -- clean.txt 2>/dev/null || true)
rm -f "$SCAN_TMPDIR/clean.txt"

# Key file by naming convention — exits 1 even though the value is not in the template
echo "placeholder-not-a-real-key" > "$SCAN_TMPDIR/id_ed25519"
(cd "$SCAN_TMPDIR" && git add id_ed25519)
scan_exit=0
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1) || scan_exit=$?
assert_eq "1" "$scan_exit" "Scan: key filename detected exits 1"
assert_contains "$stderr" "naming convention" "Scan: reports naming-convention match"
(cd "$SCAN_TMPDIR" && git reset -q HEAD -- id_ed25519 2>/dev/null || true)
rm -f "$SCAN_TMPDIR/id_ed25519"

# Public counterpart must NOT be flagged — the .pub suffix is safe to commit
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 test@example" > "$SCAN_TMPDIR/id_ed25519.pub"
(cd "$SCAN_TMPDIR" && git add id_ed25519.pub)
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1)
scan_exit=$?
assert_eq "0" "$scan_exit" "Scan: .pub counterpart is not flagged"
(cd "$SCAN_TMPDIR" && git reset -q HEAD -- id_ed25519.pub 2>/dev/null || true)
rm -f "$SCAN_TMPDIR/id_ed25519.pub"

# PEM armour by content — filename is innocuous, content is not
printf -- '-----BEGIN TESTING KEY-----\ncGxhY2Vob2xkZXI=\n-----END TESTING KEY-----\n' > "$SCAN_TMPDIR/blob.txt"
(cd "$SCAN_TMPDIR" && git add blob.txt)
scan_exit=0
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1) || scan_exit=$?
assert_eq "1" "$scan_exit" "Scan: PEM armour detected exits 1"
assert_contains "$stderr" "PEM key armour" "Scan: reports PEM armour match"
(cd "$SCAN_TMPDIR" && git reset -q HEAD -- blob.txt 2>/dev/null || true)
rm -f "$SCAN_TMPDIR/blob.txt"

# PKCS#12 bundle by extension — exits 1
echo "placeholder" > "$SCAN_TMPDIR/cert.p12"
(cd "$SCAN_TMPDIR" && git add cert.p12)
scan_exit=0
stderr=$(cd "$SCAN_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" 2>&1) || scan_exit=$?
assert_eq "1" "$scan_exit" "Scan: .p12 bundle detected exits 1"
(cd "$SCAN_TMPDIR" && git reset -q HEAD -- cert.p12 2>/dev/null || true)
rm -f "$SCAN_TMPDIR/cert.p12"

# --install-hook creates hook file (fresh repo, no existing hook)
HOOK_TMPDIR=$(mktemp -d)
(cd "$HOOK_TMPDIR" && git init -q)
(cd "$HOOK_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" --install-hook 2>/dev/null)
hook_file="$HOOK_TMPDIR/.git/hooks/pre-commit"
TESTS=$((TESTS + 1))
if [ -f "$hook_file" ] && grep -q 'op-env-scan' "$hook_file"; then
  : # pass
else
  FAILURES=$((FAILURES + 1))
  echo "FAIL: --install-hook did not create pre-commit hook" >&2
fi

# --install-hook idempotent (run again, should not duplicate)
(cd "$HOOK_TMPDIR" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" --install-hook 2>/dev/null)
# Count command invocations only (not comments that mention op-env-scan)
count=$(grep -c '^op-env-scan$' "$hook_file")
assert_eq "1" "$count" "Install hook is idempotent (command appears once)"
rm -rf "$HOOK_TMPDIR"

# --install-hook preserves existing content
HOOK_TMPDIR2=$(mktemp -d)
(cd "$HOOK_TMPDIR2" && git init -q)
existing_hook="$HOOK_TMPDIR2/.git/hooks/pre-commit"
echo '#!/bin/bash' > "$existing_hook"
echo 'echo "existing hook"' >> "$existing_hook"
chmod +x "$existing_hook"
(cd "$HOOK_TMPDIR2" && bash "$OP_ENV_SCAN" --tpl "$FIXTURES/test.tpl" --install-hook 2>/dev/null)
assert_contains "$(cat "$existing_hook")" "existing hook" "Install hook preserves existing content"
assert_contains "$(cat "$existing_hook")" "op-env-scan" "Install hook adds scanner"
rm -rf "$HOOK_TMPDIR2"

# ============================================================
# Results
# ============================================================

report
