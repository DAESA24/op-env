#!/bin/bash
# install.sh test suite — raw bash, no framework dependencies
# Run: bash test/test-install.sh
#
# Tests the installation process in isolated temp directories.
# Validates dev/prod separation: installed binary must be a standalone
# copy with baked version, no runtime dependency on the source repo.

set -uo pipefail
# Note: no set -e — tests intentionally trigger non-zero exits

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"
HELPERS="$SCRIPT_DIR/helpers"
FIXTURES="$SCRIPT_DIR/fixtures"

# shellcheck source=test/helpers/assert.sh
source "$HELPERS/assert.sh"

# Read expected version from repo
EXPECTED_VERSION=$(cat "$REPO_DIR/version.txt" 2>/dev/null || echo "dev")

echo "Running install.sh test suite..."
echo ""

# ============================================================
# Helper: run install.sh targeting an isolated temp directory
# ============================================================
run_install() {
  local install_dir="$1"
  HOME_BACKUP="$HOME"
  # Override HOME so install.sh writes to our temp dir
  export HOME="$install_dir"
  (cd "$REPO_DIR" && bash install.sh 2>&1)
  local rc=$?
  export HOME="$HOME_BACKUP"
  return $rc
}

# ============================================================
# Category 1: Unit Tests — File Type and Structure
# ============================================================

echo "--- Unit: File type and structure ---"

# Test 1: Creates regular file (not symlink)
TMPDIR1=$(mktemp -d)
run_install "$TMPDIR1" > /dev/null
result="regular"
[ -L "$TMPDIR1/.local/bin/op-env" ] && result="symlink"
[ -f "$TMPDIR1/.local/bin/op-env" ] || result="missing"
assert_eq "regular" "$result" "install creates regular file, not symlink"
rm -rf "$TMPDIR1"

# Test 2: Overwrites existing symlink with regular file
TMPDIR2=$(mktemp -d)
mkdir -p "$TMPDIR2/.local/bin"
ln -s /nonexistent/path "$TMPDIR2/.local/bin/op-env"
run_install "$TMPDIR2" > /dev/null
result="regular"
[ -L "$TMPDIR2/.local/bin/op-env" ] && result="symlink"
[ -f "$TMPDIR2/.local/bin/op-env" ] || result="missing"
assert_eq "regular" "$result" "install overwrites symlink with regular file"
rm -rf "$TMPDIR2"

# Test 3: Overwrites existing regular file (upgrade path)
TMPDIR3=$(mktemp -d)
mkdir -p "$TMPDIR3/.local/bin"
echo "old version" > "$TMPDIR3/.local/bin/op-env"
run_install "$TMPDIR3" > /dev/null
result=$(head -1 "$TMPDIR3/.local/bin/op-env")
assert_eq "#!/bin/bash" "$result" "install overwrites existing file on upgrade"
rm -rf "$TMPDIR3"

# Test 4: Installed binary has executable permissions
TMPDIR4=$(mktemp -d)
run_install "$TMPDIR4" > /dev/null
result="not-executable"
[ -x "$TMPDIR4/.local/bin/op-env" ] && result="executable"
assert_eq "executable" "$result" "installed binary is executable"
rm -rf "$TMPDIR4"

# ============================================================
# Category 2: Unit Tests — Version Baking
# ============================================================

echo "--- Unit: Version baking ---"

# Test 5: Version is baked into installed copy
TMPDIR5=$(mktemp -d)
run_install "$TMPDIR5" > /dev/null
result=$(grep -c "echo \"$EXPECTED_VERSION\"" "$TMPDIR5/.local/bin/op-env" || true)
assert_eq "1" "$result" "version baked into installed copy"
rm -rf "$TMPDIR5"

# Test 6: Installed binary does NOT contain version.txt read pattern
TMPDIR6=$(mktemp -d)
run_install "$TMPDIR6" > /dev/null
result=$(grep -c 'cat "\$SCRIPT_DIR/../version.txt"' "$TMPDIR6/.local/bin/op-env" || true)
assert_eq "0" "$result" "installed binary has no version.txt dependency"
rm -rf "$TMPDIR6"

# ============================================================
# Category 3: Unit Tests — Directory and Path Handling
# ============================================================

echo "--- Unit: Directory and path handling ---"

# Test 7: Creates target directory if missing
TMPDIR7=$(mktemp -d)
# Ensure .local/bin does NOT exist
rm -rf "$TMPDIR7/.local"
run_install "$TMPDIR7" > /dev/null
result="missing"
[ -f "$TMPDIR7/.local/bin/op-env" ] && result="created"
assert_eq "created" "$result" "install creates directory if missing"
rm -rf "$TMPDIR7"

# Test 8: Works from any working directory
TMPDIR8=$(mktemp -d)
HOME_BACKUP="$HOME"
export HOME="$TMPDIR8"
(cd /tmp && bash "$INSTALLER" 2>&1) > /dev/null
rc=$?
export HOME="$HOME_BACKUP"
result="fail"
[ $rc -eq 0 ] && [ -f "$TMPDIR8/.local/bin/op-env" ] && result="pass"
assert_eq "pass" "$result" "install works from any working directory"
rm -rf "$TMPDIR8"

# ============================================================
# Category 4: Functional Tests — Installed Binary Behavior
# ============================================================

echo "--- Functional: Installed binary behavior ---"

# Put mock op in PATH for functional tests
export PATH="$HELPERS:$PATH"
chmod +x "$HELPERS/op"

# Test 9: Installed op-env --version outputs correct version
TMPDIR9=$(mktemp -d)
run_install "$TMPDIR9" > /dev/null
result=$("$TMPDIR9/.local/bin/op-env" --version 2>&1)
assert_eq "op-env $EXPECTED_VERSION" "$result" "installed --version shows correct version"
rm -rf "$TMPDIR9"

# Test 10: Installed op-env --help exits 0 with usage text
TMPDIR10=$(mktemp -d)
run_install "$TMPDIR10" > /dev/null
result=$("$TMPDIR10/.local/bin/op-env" --help 2>&1)
rc=$?
assert_eq "0" "$rc" "installed --help exits 0"
assert_contains "$result" "USAGE:" "installed --help contains usage text"
rm -rf "$TMPDIR10"

# Test 11: Installed op-env with mock op resolves template keys
TMPDIR11=$(mktemp -d)
run_install "$TMPDIR11" > /dev/null
result=$("$TMPDIR11/.local/bin/op-env" --tpl "$FIXTURES/test.tpl" --check 2>&1)
assert_contains "$result" "TEST_KEY_A" "installed binary resolves template keys"
rm -rf "$TMPDIR11"

# Test 12: Installed op-env fails gracefully when op not found
TMPDIR12=$(mktemp -d)
run_install "$TMPDIR12" > /dev/null
# Run with PATH stripped of mock op to simulate op missing
# Capture exit code without || true swallowing it
PATH="/usr/bin:/bin" "$TMPDIR12/.local/bin/op-env" --tpl "$FIXTURES/test.tpl" echo hello > /dev/null 2>&1
rc=$?
# op-env requires op — it should fail (exit non-zero), not succeed silently
pass="no"
[ $rc -ne 0 ] && pass="yes"
assert_eq "yes" "$pass" "installed binary fails when op not available"
rm -rf "$TMPDIR12"

# Test 13: exec "$@" is last non-comment line in installed binary
TMPDIR13=$(mktemp -d)
run_install "$TMPDIR13" > /dev/null
last_line=$(grep -v '^\s*#' "$TMPDIR13/.local/bin/op-env" | grep -v '^\s*$' | tail -1)
result="no"
echo "$last_line" | grep -q 'exec "\$@"' && result="yes"
assert_eq "yes" "$result" "installed binary ends with exec (TTY preserved)"
rm -rf "$TMPDIR13"

# ============================================================
report
