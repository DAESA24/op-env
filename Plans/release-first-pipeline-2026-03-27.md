---
title: Release-First Pipeline Pattern
status: planned
created: 2026-03-27
author: Daesa (PAI)
priority: high
scope: install.sh guard, release workflow artifact publishing, update mechanism
depends-on: feat/install-hardening PR merge
pattern-test: op-env (first project to test this pattern)
github-issue: https://github.com/DAESA24/op-env/issues/24
---

# Release-First Pipeline Pattern

## Why This Pattern

On 2026-03-27, a broken symlink at `~/.local/bin/op-env` caused all Claude Code aliases to fail. Root cause: the production binary was a symlink pointing into the dev working tree, not a standalone copy from a release. Renaming the dev directory broke production.

**Lesson:** Production binaries should never depend on the dev working tree. They should come exclusively from releases.

**This pattern is being tested with op-env first.** If it works well, it can be applied to other projects in `~/projects/dev-tools/`.

## Current State (after install-hardening PR)

- install.sh uses `cp` (correct) with symlink detection and readlink-safety
- 14 installation tests validate install.sh behavior
- CI covers install.sh via shellcheck and exfiltration scans
- But: install.sh can still be run from any commit, including dirty working trees

## Release-First Pipeline Design

### Component 1: install.sh Guard

**What:** install.sh checks if it's running from a tagged release commit. If not, it warns and requires `--dev` flag to proceed.

**Why:** Prevents accidental production installs from development state. The `--dev` flag is an explicit "I know what I'm doing" signal.

**How:**
```bash
# After set -e, before any work
TAG=$(git -C "$SCRIPT_DIR" describe --exact-match HEAD 2>/dev/null || true)
if [ -z "$TAG" ] && [ "$1" != "--dev" ]; then
  echo "WARNING: Not a tagged release. Use './install.sh --dev' to install from development." >&2
  echo "For production installs, download from GitHub releases." >&2
  exit 1
fi
```

**Edge cases:**
- First-time users cloning from a tagged release: works (tag present)
- First-time users cloning main after a release: no tag on HEAD, must use `--dev`
- CI tests: already use temp dirs with HOME override, not install.sh directly from repo — unaffected
- test-install.sh: runs install.sh via `bash install.sh`, not `./install.sh` — needs `--dev` flag added to test helper

### Component 2: Release Workflow Binary Publishing

**What:** Enhance `release.yml` to attach a production-ready binary as a release asset after release-please creates the release.

**Why:** Makes the release the single source of truth for production binaries. Users download from releases, not from git clone.

**How:** Add a second job to `release.yml` that runs after `release-please`:
```yaml
  publish-binary:
    runs-on: ubuntu-latest
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created }}
    steps:
      - uses: actions/checkout@v4
      - name: Build production binary
        run: |
          VERSION=$(cat version.txt)
          cp bin/op-env op-env-v${VERSION}
          chmod +x op-env-v${VERSION}
          # Bake version
          sed -i "s|cat \"\$SCRIPT_DIR/../version.txt\" 2>/dev/null|echo \"$VERSION\"|" op-env-v${VERSION}
          # Verify bake
          if grep -q 'cat "\$SCRIPT_DIR/../version.txt"' op-env-v${VERSION}; then
            echo "ERROR: version baking failed" >&2
            exit 1
          fi
      - name: Upload release asset
        env:
          GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
        run: |
          VERSION=$(cat version.txt)
          gh release upload "v${VERSION}" "op-env-v${VERSION}" --clobber
```

**Key detail:** Reuses the same version-baking logic from install.sh. The bake verification check ensures we never publish a binary that still reads version.txt.

### Component 3: Update Mechanism

**What:** An `op-env --update` flag (or standalone `op-env-update` script) that downloads the latest release binary from GitHub.

**Why:** Closes the loop — after a release is published, users can update with a single command instead of cloning and running install.sh.

**How:**
```bash
# In bin/op-env, add --update flag handling:
if [ "$1" = "--update" ]; then
  LATEST=$(gh release view --repo DAESA24/op-env --json tagName -q .tagName 2>/dev/null)
  if [ -z "$LATEST" ]; then
    echo "op-env: could not fetch latest release" >&2
    exit 1
  fi
  ASSET="op-env-${LATEST}"
  TMPFILE=$(mktemp)
  gh release download "$LATEST" --repo DAESA24/op-env --pattern "$ASSET" --output "$TMPFILE" --clobber
  chmod +x "$TMPFILE"
  mv "$TMPFILE" "${HOME}/.local/bin/op-env"
  echo "op-env: updated to $LATEST"
  exit 0
fi
```

**Alternative:** Standalone `update.sh` in the repo, keeping op-env itself minimal. This avoids adding `gh` as a runtime dependency of op-env.

**Recommended:** Standalone `update.sh` — simpler, no new dependencies in the main binary.

## Success Criteria for Pattern Reuse

This pattern is ready to apply to other projects when:

1. [ ] op-env has run through at least 2 release cycles with this pipeline
2. [ ] No manual install.sh runs were needed (all updates via release download)
3. [ ] The install guard has caught at least one accidental dev install
4. [ ] CI has caught at least one issue that local testing missed
5. [ ] The workflow is documented enough that Drew can explain it to another developer

## Implementation Order

1. install.sh guard (smallest change, highest value)
2. Release workflow binary publishing (enables the update mechanism)
3. Update mechanism (completes the loop)
4. Update `pai update` / `ccc` alias chain to use the new update mechanism

Each step should be a separate PR with its own tests.
