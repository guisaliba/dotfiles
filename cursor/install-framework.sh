#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-$(pwd)}"
SRC="$HOME/dotfiles/cursor/framework/.cursor"
DEST="$TARGET/.cursor"

if [ ! -d "$SRC" ]; then
  echo "error: framework source not found at $SRC" >&2
  exit 1
fi

if [ -e "$DEST" ]; then
  echo "error: $DEST already exists" >&2
  exit 1
fi

mkdir -p "$TARGET"
cp -R "$SRC" "$DEST"

echo "Installed Cursor framework into: $DEST"