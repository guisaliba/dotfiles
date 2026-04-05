# Claude Code

Claude Code loads user config from **`~/.claude`**. This repo stores the versioned tree under **`claude/`** and links it into your home directory with **`scripts/setup.sh`**.

## Setup

From a shell (the script assumes your dotfiles checkout is at **`$HOME/dotfiles`**; edit **`DOTFILES_CLAUDE`** in the script if yours is elsewhere):

```bash
./claude/scripts/setup.sh
```

The script:

1. Ensures **`~/.claude`** exists.
2. Symlinks these items from **`$HOME/dotfiles/claude/`** into **`~/.claude/`**: **`settings.json`**, **`agents`**, **`commands`**, **`hooks`**, **`rules`**, **`skills`**, **`plugins`**, **`scripts`** (directories are linked as a whole). Existing real files or directories are renamed to **`*.bak.<timestamp>`**; existing symlinks are removed and recreated.
3. Symlinks **`$HOME/dotfiles/AGENTS.md`** to **`~/.claude/CLAUDE.md`** so Claude Code’s primary instruction file is the same document you use elsewhere (single source of truth under the name **`CLAUDE.md`** in the app).

After linking, refresh plugins in the app if needed:

```text
/plugin marketplace add <author>/<plugin-name>
/plugin install <plugin-name>
/<plugin>:setup
```

## Editing instructions

Update behavior in the repo-root **`AGENTS.md`**. That file is what **`~/.claude/CLAUDE.md`** points at; no extra sync step. Re-run **`setup.sh`** only if you need to repair symlinks (new machine, moved repo, etc.).

## Layout (what gets linked)

| Path under `claude/` | Role |
|----------------------|------|
| **`settings.json`** | Claude Code settings |
| **`agents/`** | Custom agents |
| **`commands/`** | Slash commands |
| **`hooks/`** | Hook scripts and config |
| **`rules/`** | Extra rule snippets |
| **`skills/`** | Agent skills |
| **`plugins/`** | Local / vendored plugins and marketplace metadata |
| **`scripts/`** | Helper scripts (also used by hooks or workflows) |

Other files in **`claude/`** (for example under **`plugins/`** subtrees) are part of the same tree and go to **`~/.claude/`** when those top-level entries exist.
