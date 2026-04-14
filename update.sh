#!/bin/bash
# update.sh — Download latest op-env release binary from GitHub
# Installed to ~/.local/bin/op-env-update by install.sh
# Usage: op-env-update
set -euo pipefail

REPO="DAESA24/op-env"
INSTALL_DIR="${HOME}/.local/bin"
CURRENT_BIN="${INSTALL_DIR}/op-env"

# Require gh CLI
if ! command -v gh >/dev/null 2>&1; then
  echo "op-env-update: gh CLI is required but not found" >&2
  echo "  Install: https://cli.github.com/" >&2
  exit 1
fi

# Fetch latest release tag
LATEST=$(gh release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null) || true
if [ -z "$LATEST" ]; then
  echo "op-env-update: could not fetch latest release from $REPO" >&2
  exit 1
fi

# Check current version (skip download if already up to date)
if [ -x "$CURRENT_BIN" ]; then
  CURRENT=$("$CURRENT_BIN" --version 2>&1 | awk '{print $2}')
  LATEST_NORM="${LATEST#v}"
  if [ "$CURRENT" = "$LATEST_NORM" ]; then
    echo "op-env: already at $LATEST_NORM (up to date)"
    exit 0
  fi
  echo "op-env: updating $CURRENT -> $LATEST_NORM"
else
  echo "op-env: installing $LATEST"
fi

# Asset name must match what the release workflow publishes
ASSET="op-env"

# Atomic download: tmpfile + mv (never leaves a half-written binary)
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if ! gh release download "$LATEST" --repo "$REPO" --pattern "$ASSET" --output "$TMPFILE" --clobber; then
  echo "op-env-update: failed to download $ASSET from release $LATEST" >&2
  exit 1
fi

chmod +x "$TMPFILE"
mkdir -p "$INSTALL_DIR"

# Verify the downloaded binary is functional
if ! "$TMPFILE" --version >/dev/null 2>&1; then
  echo "op-env-update: downloaded binary failed --version check" >&2
  exit 1
fi

mv "$TMPFILE" "$CURRENT_BIN"
trap - EXIT

NEW_VER=$("$CURRENT_BIN" --version 2>&1 | awk '{print $2}')
echo "op-env: updated to $NEW_VER"
