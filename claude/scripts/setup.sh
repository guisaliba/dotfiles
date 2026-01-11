#!/bin/bash
set -e

DOTFILES_CLAUDE="$HOME/dotfiles/claude"
CLAUDE_DIR="$HOME/.claude"

echo "Setting up Claude config symlinks..."

# Create .claude if doesn't exist
mkdir -p "$CLAUDE_DIR"

# Config items to symlink
CONFIG_ITEMS="CLAUDE.md settings.json agents commands hooks rules skills plugins scripts"

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

echo ""
echo "Done. Start 'claude' and reinstall plugins:"
echo "  /plugin marketplace add <author>/<plugin-name>"
echo "  /plugin install <plugin-name>"
echo "  /<plugin>:setup"
