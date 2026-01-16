#!/bin/bash
set -e

DOTFILES_OPENCODE="$HOME/dotfiles/opencode"
OPENCODE_DIR="$HOME/.opencode"

echo "Setting up OpenCode config symlinks..."

# Create .opencode if doesn't exist
mkdir -p "$OPENCODE_DIR"

# Config items to symlink
CONFIG_ITEMS="package.json bun.lock .gitignore"

for item in $CONFIG_ITEMS; do
    src="$DOTFILES_OPENCODE/$item"
    dest="$OPENCODE_DIR/$item"

    if [ -e "$src" ]; then
        # Remove existing symlink
        [ -L "$dest" ] && rm "$dest"
        # Backup existing file/dir if not a symlink
        [ -e "$dest" ] && mv "$dest" "$dest.bak.$(date +%s)"
        # Create symlink
        ln -s "$src" "$dest"
        echo "  Linked: $item"
    else
        echo "  Skipped (not found): $item"
    fi
done

echo ""
echo "Done. Install OpenCode dependencies:"
echo "  cd ~/.opencode && bun install"
