#!/usr/bin/env bash

# Zed + Claude Code Integration Setup Script
# This script sets up the environment variable workaround for Zed's Claude Code ACP integration

set -e

CLAUDE_EXECUTABLE="/home/.local/bin/claude"
DESKTOP_FILE="$HOME/.local/share/applications/dev.zed.Zed.desktop"
DOTFILES_DESKTOP="$HOME/dotfiles/zed/dev.zed.Zed.desktop"

echo "=== Zed + Claude Code Integration Setup ==="
echo ""

# Step 1: Verify Claude Code binary exists
echo "1. Checking for Claude Code binary..."
if [ -f "$CLAUDE_EXECUTABLE" ] || [ -L "$CLAUDE_EXECUTABLE" ]; then
    echo "   ✓ Claude Code found at: $CLAUDE_EXECUTABLE"
else
    echo "   ✗ Claude Code not found at: $CLAUDE_EXECUTABLE"
    echo ""
    echo "Please install Claude Code first or update CLAUDE_EXECUTABLE path in:"
    echo "  - $HOME/dotfiles/fish/config.fish"
    echo "  - $HOME/dotfiles/zed/dev.zed.Zed.desktop"
    echo "  - $HOME/dotfiles/scripts/zed-launcher.sh"
    exit 1
fi

# Step 2: Check if Fish config has the environment variable
echo ""
echo "2. Checking Fish shell configuration..."
if grep -q "CLAUDE_CODE_EXECUTABLE" "$HOME/dotfiles/fish/config.fish" 2>/dev/null; then
    echo "   ✓ CLAUDE_CODE_EXECUTABLE is set in Fish config"
else
    echo "   ✗ CLAUDE_CODE_EXECUTABLE not found in Fish config"
    echo "   Run this command to add it:"
    echo "   echo 'set -gx CLAUDE_CODE_EXECUTABLE $CLAUDE_EXECUTABLE' >> ~/dotfiles/fish/config.fish"
fi

# Step 3: Install desktop file
echo ""
echo "3. Installing Zed desktop file with environment variable..."
if [ -f "$DESKTOP_FILE" ]; then
    echo "   Backing up existing desktop file..."
    cp "$DESKTOP_FILE" "$DESKTOP_FILE.backup"
fi

if [ -f "$DOTFILES_DESKTOP" ]; then
    cp "$DOTFILES_DESKTOP" "$DESKTOP_FILE"
    echo "   ✓ Desktop file installed"
else
    echo "   ✗ Desktop file not found at: $DOTFILES_DESKTOP"
    exit 1
fi

# Step 4: Update desktop database
echo ""
echo "4. Updating desktop database..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications"
    echo "   ✓ Desktop database updated"
else
    echo "   ⚠ update-desktop-database not found, skipping..."
fi

# Step 5: Reload Fish config
echo ""
echo "5. Reloading Fish configuration..."
if [ -n "$FISH_VERSION" ]; then
    source "$HOME/dotfiles/fish/config.fish"
    echo "   ✓ Fish config reloaded"
else
    echo "   ⚠ Not running in Fish shell, please reload manually:"
    echo "   source ~/dotfiles/fish/config.fish"
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Close all Zed instances"
echo "  2. Launch Zed from the application menu (not from terminal)"
echo "  3. Open Zed's Agent panel and try using Claude Code"
echo ""
echo "Alternative launch methods:"
echo "  • From terminal: CLAUDE_CODE_EXECUTABLE=$CLAUDE_EXECUTABLE zed"
echo "  • Using launcher: ~/dotfiles/scripts/zed-launcher.sh"
echo ""
echo "To verify the setup:"
echo "  • Open Zed"
echo "  • Press Ctrl+Shift+P (or Cmd+Shift+P)"
echo "  • Type 'zed: open log'"
echo "  • Check for Claude Code connection messages"
echo ""
