#!/bin/bash
DOTFILES_ZED="$HOME/dotfiles/zed/settings.json"

if [[ "$OSTYPE" == "linux-gnu"* ]] && uname -r | grep -qi microsoft; then
    sudo ln -sf "$DOTFILES_ZED" "/mnt/c/Users/salib/AppData/Roaming/Zed/settings.json"
    echo "WSL2 symlink created"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ln -sf "$DOTFILES_ZED" ~/.config/zed/settings.json
    echo "Unix symlink created"
fi
