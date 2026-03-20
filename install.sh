#!/bin/bash
# Install op-env to ~/.local/bin
# Usage: ./install.sh

set -e

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/bin/op-env" "$INSTALL_DIR/op-env"
chmod +x "$INSTALL_DIR/op-env"

echo "Installed op-env to $INSTALL_DIR/op-env"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "Add to your shell config (~/.zshrc or ~/.bashrc):"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
