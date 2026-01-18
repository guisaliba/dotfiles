#!/bin/bash
set -e

DOTFILES_CLAUDE="$HOME/dotfiles/claude"
CLAUDE_DIR="$HOME/.claude"

echo "Setting up Claude config symlinks..."

# Create .claude if doesn't exist
mkdir -p "$CLAUDE_DIR"

# Config items to symlink
CONFIG_ITEMS="settings.json agents commands hooks rules skills plugins scripts"

for item in $CONFIG_ITEMS; do
    src="$DOTFILES_CLAUDE/$item"
    dest="$CLAUDE_DIR/$item"

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
AGENTS_DEST="$CLAUDE_DIR/CLAUDE.md"

if [ -e "$AGENTS_SRC" ]; then
    [ -L "$AGENTS_DEST" ] && rm "$AGENTS_DEST"
    [ -e "$AGENTS_DEST" ] && mv "$AGENTS_DEST" "$AGENTS_DEST.bak.$(date +%s)"
    ln -s "$AGENTS_SRC" "$AGENTS_DEST"
    echo "  Linked: CLAUDE.md -> AGENTS.md"
else
    echo "  Skipped (not found): AGENTS.md"
fi

echo ""
echo "Done. Start 'claude' and reinstall plugins:"
echo "  /plugin marketplace add <author>/<plugin-name>"
echo "  /plugin install <plugin-name>"
echo "  /<plugin>:setup"
