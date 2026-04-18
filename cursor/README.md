# Cursor

Cursor picks up **user-level rules** from `~/.cursor/rules/` and applies them to every workspace. The global agent rules and the always-on Caveman rule are generated from this repo by `agents/sync-agents.sh`.

## Keeping rules in sync

After editing `**agents/AGENTS.base.md`** or `**agents/cursor.overlay.md**`, regenerate the Cursor rule files:

```bash
~/dotfiles/agents/sync-agents.sh
```

That writes:

- `**~/.cursor/rules/00-global.mdc**` - base + cursor overlay (`alwaysApply: true`)
- `**~/.cursor/rules/01-caveman.mdc**` - Caveman mode rule (`alwaysApply: true`)

Both files are regular (non-symlink) files; edits to the generated files are overwritten on the next sync. Change behavior at the source in `agents/`.

## Files in this folder

- `**settings.json**`, `**keybindings.json**`, `**EXTENSIONS.md**` - editor preferences and extension lists (separate from agent rules).

