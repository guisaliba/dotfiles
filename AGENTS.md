# AGENTS.md

## Boundaries

- This repository stores selectively applied dotfiles. `install.sh` is the workstation entry point and applies components from `components.tsv`. It expands every target inside `$HOME`, preserves unrelated shell content, and never overwrites a file that is not a documented managed target. The agent-stack apply script owns only its marked Claude Code block in `~/.bash_aliases`, removes the retired OpenCode block, and owns its marked block in `~/.bash_profile`.
- Root `AGENTS.md` guides work in this repository. The public [`guisaliba/agents`](https://github.com/guisaliba/agents) repository owns the canonical global instruction payload: its `CLAUDE.md` is copied to `~/.claude/CLAUDE.md`.
- `omarchy-display` installs `omarchy/display-plugin/` only when the packaged Display contract matches `omarchy/display-upstream.sha256`. The built-in `omarchy.monitor` stays installed; its bar and shortcut calls route to the enabled `guisaliba.monitor` clone. Keep native brightness, scale, text size, toggle, keyboard, pointer, and IPC behavior. The layout helper owns only its marked block in `~/.config/hypr/monitors.lua`.
- Keep managed repository sources distinct from materialized files under `$HOME`; do not edit or overwrite home-directory targets unless explicitly asked.

## Root Installer

- `install.sh` is the executable workstation installer. It is a Bash UI and orchestrator. It supports `--check`, `--components`, `--host`, `--yes`, `--vscode-extensions`, `--agents-branch`, and `--help`. It rejects unknown options, duplicate scalar options, invalid hosts, unknown components, and unknown extension identifiers with status 2.
- `components.tsv` is the data manifest: `component<TAB>action<TAB>source<TAB>target<TAB>hosts<TAB>default<TAB>risk`. `install.sh` validates it strictly.
- `lib/dotfiles_installer.py` provides the safe file operations: manifest validation, absolute target expansion inside HOME, atomic copy with source mode, tree compare and managed-tree replacement, backup root and run-id creation, path mirroring, MANIFEST.tsv append, and exact managed-block replacement. It uses the standard library only and never runs external commands.
- `bash/aliases.bash` is the ordinary-dotfiles marked block merged into `~/.bash_aliases`. The Claude Code wrapper block is separate and owned by the agent stack.
- `vscode/extensions.tsv` is the source of truth for tracked VS Code extensions. `vscode/EXTENSIONS.md` is human documentation.
- `--check` performs no writes, clone, fetch, extension install, command, service, or sudo action. A component failure stops later components, and the final message lists completed and failed components.
- Backups use one UTC run id under `~/.local/state/dotfiles/backups/<id>/`, mirroring the absolute target path without the leading slash. There is no backup when the target is equal, and no run directory in `--check`.
- Risk gates: the agents component is a network and service action and shows a separate confirmation before running. `--yes` never bypasses this separate confirmation.

## Agent Stack

- Read the public [`guisaliba/agents`](https://github.com/guisaliba/agents) repository for the detailed agent setup, runtime wiring, and integration commands.
- The managed checkout at `~/.local/share/dotfiles/agents/apply.sh` is the executable source of truth for the Claude Code + pstack setup. It requires Bash, `curl`, `git`, `npm`, `npx`, Python 3.11 or newer, and a systemd user manager on Linux. It uses `yay` when the native `ai-memory` command is absent. It performs network installs and changes files under `~/.claude`, `~/.claude-go`, `~/.config/ai-memory`, `~/.local/share/ai-memory`, `~/.local/bin`, and the marked blocks in `~/.bash_aliases` and `~/.bash_profile`. Do not run it as a read-only verification step.
- The managed checkout uses branch `main` by default. `--agents-branch BRANCH` (valid only when `agents` is selected) clones that branch, or switches a clean managed checkout to it. Without the option, a checkout on another branch is refused, never moved. The switch never resets, cleans, stashes, or deletes.
- ai-memory runs as the native per-user service. The agents apply owns its service, environment policy, and Claude Code wiring. The installed ai-memory binary owns the generated Claude Code hooks, MCP entry, `~/.claude/rules/ai-memory.md`, and five `~/.claude/skills/ai-memory-*` skill directories.
- Dotfiles owns the ai-memory LLM profile, provider, model, approval, and scheduler assignments in `~/.config/ai-memory/env`. The default profile uses DeepSeek V4 Flash through the OpenCode Go API. Apply keeps zero-LLM mode until `OPENCODE_API_KEY` is present in that environment file. The pstack OpenCode Go workers read the same key through the agents repository's `bin/go-key`.
- Keep `~/.config/ai-memory/config.toml`, `~/.config/ai-memory/env`, ai-memory data, Claude Code credentials, and native sessions out of Git. The config contains a generated token pepper. The environment file can contain provider keys.
- Normal interactive Bash `claude` commands are an unexported function that runs `ai-memory run claude`. `claude-raw` is the explicit diagnostic and recovery bypass; it must not become the routine path. The function rejects `--dangerously-skip-permissions` and `--permission-mode bypassPermissions`.
- Do not vendor upstream plugin or skill payloads. Update their source/version declarations in the public `guisaliba/agents` repository instead.

## Verification

- After agent-stack changes, run `~/.local/share/dotfiles/agents/test.sh`.
- The managed `test.sh` is not a hermetic unit test: it checks repository files and the current machine's installed commands, Claude Code configuration, and global skills. Run the managed `apply.sh` first only when setup/update side effects were requested.
- Use `~/.local/share/dotfiles/agents/test.sh --repo-only` for deterministic merge, idempotence, safe-failure, and private-file fixtures without current-machine assertions.
- `./test.sh --repo-only` is the deterministic root-installer fixture suite. It uses temporary HOME and repository fixtures only, never modifies a real home directory, and never contacts GitHub.
- The agent apply is a network and service action. Do not run it as a read-only verification step. Run the managed `~/.local/share/dotfiles/agents/test.sh --repo-only` and `./test.sh --repo-only` instead.
- For syntax-only checks that avoid machine-state assertions, use `bash -n install.sh test.sh omarchy/mx-mini-recover.sh` and `python3 -m py_compile lib/dotfiles_installer.py omarchy/install-display.py omarchy/display-plugin/layout.py omarchy/test-display.py`.
- After Display changes, run `python3 -B omarchy/test-display.py` and `./test.sh --repo-only`. On Omarchy, also run `qmllint omarchy/display-plugin/Panel.qml` and `omarchy plugin validate omarchy/display-plugin`.
