# Zed + Claude Code Integration Setup

This guide explains how to set up Claude Code (ACP) integration with Zed editor on Linux.

## Problem

Setting `CLAUDE_CODE_EXECUTABLE` in Zed's `settings.json` doesn't work reliably:

```json
"agent_servers": {
  "claude": {
    "env": {
      "CLAUDE_CODE_EXECUTABLE": "/path/to/claude"
    }
  }
}
```

This is a known issue tracked at: https://github.com/zed-industries/zed/issues/40327

## Solution

The workaround is to set the `CLAUDE_CODE_EXECUTABLE` environment variable globally, outside of Zed's configuration.

## Setup Methods

### Method 1: Automated Setup (Recommended)

Run the setup script:

```bash
cd ~/dotfiles/zed
./scripts/setup-zed-claude.sh
```

This will:
1. Verify Claude Code binary exists
2. Check Fish shell configuration
3. Install a custom desktop file with the environment variable
4. Update the desktop database

### Method 2: Manual Setup

#### Step 1: Add Environment Variable to Shell Config

The environment variable is already set in `~/dotfiles/fish/config.fish`:

```fish
set -gx CLAUDE_CODE_EXECUTABLE /home/.local/bin/claude
```

Reload your Fish config:

```bash
source ~/dotfiles/fish/config.fish
```

#### Step 2: Install Custom Desktop File

Copy the custom desktop file:

```bash
cp ~/dotfiles/zed/dev.zed.Zed.desktop ~/.local/share/applications/dev.zed.Zed.desktop
update-desktop-database ~/.local/share/applications
```

The custom desktop file sets the environment variable when launching Zed:

```desktop
Exec=env CLAUDE_CODE_EXECUTABLE=/home/.local/bin/claude /home/.local/zed.app/bin/zed %U
```

## Usage

### Launching Zed

After setup, launch Zed using any of these methods:

1. **Terminal** (Simplest)
   ```bash
   zed
   ```
   - A shell alias automatically sets `CLAUDE_CODE_EXECUTABLE`
   - Works in both Fish and Bash shells
   - Just reload your config first: `source ~/dotfiles/fish/config.fish` (or `~/.bashrc`)

2. **Application Menu/Launcher**
   - Use your desktop environment's application menu
   - The custom desktop file ensures the environment variable is set

3. **Using the Launcher Script**
   ```bash
   ~/dotfiles/scripts/zed-launcher.sh
   ```

### Verifying the Setup

1. Open Zed
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
3. Type `zed: open log` and press Enter
4. Look for Claude Code connection messages in the logs
5. Try using the Agent panel with Claude Code

## Troubleshooting

### Claude Code Binary Not Found

Check if the binary exists:

```bash
which claude
ls -la /home/.local/bin/claude
```

If the path is different, update it in:
- `~/dotfiles/fish/config.fish`
- `~/dotfiles/zed/dev.zed.Zed.desktop`
- `~/dotfiles/scripts/zed-launcher.sh`

### Zed Still Can't Find Claude Code

1. **Close all Zed instances completely**
   ```bash
   pkill zed
   ```

2. **Reload your shell configuration**
   ```bash
   # For Fish
   source ~/dotfiles/fish/config.fish

   # For Bash
   source ~/.bashrc
   ```

3. **Launch Zed again**
   ```bash
   zed
   ```

4. **Check environment variable in running Zed**
   - Open a terminal in Zed (Terminal > New Terminal)
   - Run: `echo $CLAUDE_CODE_EXECUTABLE`
   - Should output: `/home/.local/bin/claude`

### Desktop File Not Working

If the desktop file doesn't work after installation:

1. Update the desktop database:
   ```bash
   update-desktop-database ~/.local/share/applications
   ```

2. Log out and log back in (or restart your session)

3. Clear desktop environment cache (varies by DE):
   ```bash
   # GNOME
   killall gnome-shell

   # KDE
   kquitapp5 plasmashell && kstart5 plasmashell
   ```

## Files Modified

- `fish/config.fish` - Added `CLAUDE_CODE_EXECUTABLE` environment variable
- `fish/functions/zed.fish` - Fish function wrapper for `zed` command
- `bash/.bashrc` - Added `CLAUDE_CODE_EXECUTABLE` environment variable
- `bash/.bash_aliases` - Added `zed` alias for Bash users
- `zed/dev.zed.Zed.desktop` - Custom desktop launcher with environment variable
- `zed/docs/CLAUDE-CODE.md` - Complete setup documentation
- `zed/scripts/zed-launcher.sh` - Shell script launcher with environment variable
- `zed/scripts/setup-zed-claude.sh` - Automated setup script
- `zed/scripts/verify-zed-claude.sh` - Verification script to test the setup

## Additional Notes

### Why This is Necessary

Zed's agent server environment variable configuration (`agent_servers.claude.env`) is currently not working as documented. The environment variables set there are not being passed to the Claude Code process.

### Future Changes

Once Zed fixes this issue (https://github.com/zed-industries/zed/issues/40327), you can:

1. Remove the environment variable from `fish/config.fish`
2. Restore the original desktop file
3. Use only the `settings.json` configuration

### WSL2 Considerations

If you're using WSL2 (as indicated by your `wsl_connections` in settings):

- The environment variable should be set in your WSL2 environment
- Launch Zed from within WSL2 for the variable to be available
- If launching Zed from Windows, you may need to set the variable differently

## References

- GitHub Issue: https://github.com/zed-industries/zed/issues/40327
- Zed Docs: https://zed.dev/docs/ai/external-agents
- Claude Code: https://docs.anthropic.com/en/docs/build-with-claude/claude-code
