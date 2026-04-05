# Cursor

Cursor picks up **project rules** from `.cursor/rules/` at the workspace root. This repo keeps agent instructions in the root `**AGENTS.md`** and mirrors them into an always-on rule so agents get the same text without relying on the model to open the file first.

## Keeping the rule in sync

After you edit `**AGENTS.md**` at the repository root, regenerate the Cursor rule:

```bash
./cursor/scripts/sync-agents-rule.sh
```

That writes `**.cursor/rules/agents.mdc**` (`alwaysApply: true`). Commit both `AGENTS.md` and `.cursor/rules/agents.mdc` when you change instructions.

## Other workspaces

Rules apply to the folder you open in Cursor. To reuse these instructions in another repo, symlink or copy `**agents.mdc**` (or the whole `**.cursor/rules/**` directory) into that project, or symlink `**AGENTS.md**` and run the sync script from a checkout that contains this `cursor/scripts/` layout.

## Files in this folder

- `**settings.json**`, `**keybindings.json**`, `**EXTENSIONS.md**` - editor preferences and extension lists (separate from agent rules).

