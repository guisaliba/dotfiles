#!/bin/bash
# https://github.com/xhyrom/zed-discord-presence?tab=readme-ov-file#wsl-guide
SOCKET_PATH="${XDG_RUNTIME_DIR}/discord-ipc-0"

# Deletes the existing socket file if it exists
rm -f "$SOCKET_PATH"

socat UNIX-LISTEN:"$SOCKET_PATH",fork \
  EXEC:"/mnt/c/npiperelay/npiperelay.exe -ep -s //./pipe/discord-ipc-0",nofork
