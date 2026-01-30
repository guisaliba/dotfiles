#!/bin/bash
set -e

DOTFILES_OPENCODE="$HOME/dotfiles/opencode"
OPENCODE_DIR="$HOME/.config/opencode"

echo "Setting up OpenCode config symlinks..."

# Create config dir if it doesn't exist
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

AGENTS_SRC="$HOME/dotfiles/AGENTS.md"
AGENTS_DEST="$OPENCODE_DIR/AGENTS.md"

if [ -e "$AGENTS_SRC" ]; then
    [ -L "$AGENTS_DEST" ] && rm "$AGENTS_DEST"
    [ -e "$AGENTS_DEST" ] && mv "$AGENTS_DEST" "$AGENTS_DEST.bak.$(date +%s)"
    ln -s "$AGENTS_SRC" "$AGENTS_DEST"
    echo "  Linked: AGENTS.md"
else
    echo "  Skipped (not found): AGENTS.md"
fi

echo ""
echo "Done. Install OpenCode dependencies:"
echo "  cd ~/.config/opencode && bun install"
