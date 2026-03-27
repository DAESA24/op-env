#!/bin/bash
# Install op-env to ~/.local/bin
# Usage: ./install.sh

set -e

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_REAL=$(readlink "$0" 2>/dev/null || echo "$0")
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_REAL")" && pwd)"

VERSION=$(cat "$SCRIPT_DIR/version.txt" 2>/dev/null || echo "dev")

mkdir -p "$INSTALL_DIR"
# Remove existing symlink before copy (prevents cp from following dangling symlinks)
if [ -L "$INSTALL_DIR/op-env" ]; then rm "$INSTALL_DIR/op-env"; fi
cp "$SCRIPT_DIR/bin/op-env" "$INSTALL_DIR/op-env"
chmod +x "$INSTALL_DIR/op-env"

# Bake version into installed copy (since version.txt won't be adjacent)
sed -i.bak "s|cat \"\$SCRIPT_DIR/../version.txt\" 2>/dev/null|echo \"$VERSION\"|" "$INSTALL_DIR/op-env"
rm -f "$INSTALL_DIR/op-env.bak"

# Verify version was baked correctly — fail loudly if sed pattern didn't match
# Literal $SCRIPT_DIR match is intentional (not a variable expansion)
# shellcheck disable=SC2016
if grep -q 'cat "\$SCRIPT_DIR/../version.txt"' "$INSTALL_DIR/op-env"; then
  echo "ERROR: version baking failed — installed binary still reads version.txt" >&2
  exit 1
fi

echo "Installed op-env $VERSION to $INSTALL_DIR/op-env"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "Add to your shell config (~/.zshrc or ~/.bashrc):"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
