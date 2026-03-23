#!/bin/bash
# Install op-env to ~/.local/bin
# Usage: ./install.sh

set -e

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VERSION=$(cat "$SCRIPT_DIR/version.txt" 2>/dev/null || echo "dev")

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/bin/op-env" "$INSTALL_DIR/op-env"
chmod +x "$INSTALL_DIR/op-env"

# Bake version into installed copy (since version.txt won't be adjacent)
sed -i.bak "s|cat \"\$SCRIPT_DIR/../version.txt\" 2>/dev/null|echo \"$VERSION\"|" "$INSTALL_DIR/op-env"
rm -f "$INSTALL_DIR/op-env.bak"

echo "Installed op-env $VERSION to $INSTALL_DIR/op-env"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "Add to your shell config (~/.zshrc or ~/.bashrc):"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
