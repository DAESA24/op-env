---
title: Dev/Prod Separation with TDD Test Plan and CI/CD Audit
status: complete
created: 2026-03-27
author: Daesa (PAI)
priority: high
scope: install.sh hardening, installation tests, CI/CD coverage expansion
related-issue: broken symlink at ~/.local/bin/op-env after dev directory rename
---

# Dev/Prod Separation with TDD Test Plan

## Context

Drew's `op-env` production binary at `~/.local/bin/op-env` was a broken symlink pointing to the old dev directory path (`~/projects/dev-tools/op-env/bin/op-env`). The directory was renamed to `op-env-dev` and later relocated to `~/projects/dev/dev-tools/infra-dev/op-env-dev/`. The `install.sh` script correctly uses `cp` (not symlink), but the symlink was likely created manually at some point, bypassing install.sh. PR #23 fixed this — the production binary is now a standalone copy.

**Goal:** The dev directory is purely for development. The production binary is an independent copy deployed by running `install.sh` after releases. CI/CD validates that the installation process works correctly. No future directory rename or dev-side change should ever break the production binary.

**CI/CD audit findings:**
- `pr-check.yml` B1 (exfiltration) and B3 (shellcheck) only scan `bin/*` — install.sh is not covered
- No test covers install.sh behavior (file type, version baking, permissions)
- `release.yml` only runs release-please — no post-release installation verification
- F2 allowlist already includes `readlink`, `realpath`, `rm`, `ln` — no flags expected from our changes

**First Principles insight:** The architecture was already correct — `install.sh` uses `cp`. The gap was enforcement and verification. Nothing tested that install.sh produces a standalone binary, nothing caught when a manual symlink bypassed it. The fix is tests and hardening, not redesign.

## Plan

### Step 1: Harden install.sh (3 surgical changes)

**File:** `install.sh`

1. **Symlink detection and removal** — before the `cp`, check if the destination is a symlink and remove it. Prevents `cp` from following the symlink and writing to the wrong place.

2. **Readlink-safety** — resolve install.sh's own path through symlinks using macOS-compatible `readlink` (NOT `readlink -f` which doesn't exist on macOS). Same pattern as `bin/op-env` line 8: `SCRIPT_REAL=$(readlink "$0" 2>/dev/null || echo "$0")`.

3. **Version bake verification** — after the sed, grep the installed file to confirm the bake succeeded. If the original `cat "$SCRIPT_DIR/../version.txt"` pattern still exists in the installed copy, fail loudly rather than silently deploying a broken version.

### Step 2: Write TDD Tests — New file `test/test-install.sh`

Uses the same `assert.sh` helper library and raw-bash test pattern as `test-op-env.sh`. All tests run in an isolated temp directory (`INSTALL_DIR=$(mktemp -d)`) and clean up after themselves.

**Unit tests (8):**
1. install.sh creates target as regular file (not symlink)
2. install.sh overwrites existing symlink with regular file
3. install.sh overwrites existing regular file (upgrade path)
4. Installed binary has executable permissions
5. Version is baked into installed copy (grep for `echo "VERSION"`)
6. Installed binary does NOT contain `version.txt` read pattern
7. install.sh creates target directory if missing
8. install.sh works from any working directory (run from `/tmp`)

**Functional tests (5):**
9. Installed `op-env --version` outputs correct version string
10. Installed `op-env --help` exits 0 with usage text
11. Installed `op-env` with mock `op` resolves template keys
12. Installed `op-env` fails gracefully when `op` not found
13. Installed binary's `exec "$@"` is last non-comment line (TTY preserved)

### Step 3: Extend CI/CD — Modify `pr-check.yml`

Three changes:

1. **Add installation test step** — new step after "Tests" that runs `test/test-install.sh` in an isolated temp dir on every PR.

2. **Extend B3 shellcheck to cover install.sh** — add `install.sh` to the file list alongside `bin/*`.

3. **Extend B1 exfiltration check to cover install.sh** — change git diff pattern from `-- 'bin/*'` to `-- 'bin/*' 'install.sh'`. Defense-in-depth.

### Step 4: Fix the immediate broken symlink

Run `install.sh` to replace the broken symlink with a standalone copy. The hardened install.sh will detect the symlink, remove it, and install a proper copy.

## Files Modified

| File | Change |
|------|--------|
| `install.sh` | Harden: symlink detection, readlink-safety, bake verification |
| `test/test-install.sh` | **NEW**: 13 tests for install.sh (unit + functional) |
| `.github/workflows/pr-check.yml` | Add install test step, extend B3 + B1 scope |

## Files NOT Modified

| File | Why |
|------|-----|
| `bin/op-env` | Already symlink-safe, no changes needed |
| `bin/op-env-scan` | Not related |
| `test/test-op-env.sh` | Existing 56 tests untouched |
| `.github/workflows/release.yml` | release-please config unchanged |

## Verification Checklist

- [ ] Existing test suite passes: `bash test/test-op-env.sh` (all 56 tests)
- [ ] New install tests pass: `bash test/test-install.sh` (all 13 tests)
- [ ] Shellcheck passes on install.sh: `shellcheck install.sh`
- [ ] Run `./install.sh` on Drew's machine — replaces broken symlink
- [ ] `op-env --version` outputs `0.3.0`
- [ ] `ls -la ~/.local/bin/op-env` shows regular file, not symlink
- [ ] pr-check.yml B1 and B3 scope includes install.sh (expanded, not weakened)
