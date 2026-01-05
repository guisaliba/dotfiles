#!/bin/bash

# Cron environment setup
export HOME="${HOME:-/home/guisaliba}"
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]] && uname -r | grep -qi microsoft; then
    ZED_SOURCE_DIR="/mnt/c/Users/salib/AppData/Roaming/Zed" # WSL2
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ZED_SOURCE_DIR="/home/guisaliba/.config/zed" # Unix
else
    echo "Unsupported platform" >&2
    exit 1
fi

REPO_DIR="$HOME/dotfiles/zed"
ZED_DEST_DIR="$REPO_DIR/.config"

rsync -av --exclude='*.tmp*' "$ZED_SOURCE_DIR/" "$ZED_DEST_DIR/" || true

cd "$REPO_DIR" || exit 1

git fetch origin
git stash push -m "auto-backup-$(date +%Y%m%d-%H%M%S)-$(hostname)" || true
git pull origin main --rebase || true
git stash pop || true

git add .config/ || true
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Auto-sync Zed config $(date) from $(hostname)" || true
    git push origin main || true
fi
