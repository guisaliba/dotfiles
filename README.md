# Dotfiles

Personal dotfiles for my Linux development environment.

This repository is my portable workstation setup. It tracks shell, editor,
prompt, and other development configuration that I can replicate across
devices. The OpenCode agentic setup is provided by the public
[`guisaliba/agents`](https://github.com/guisaliba/agents) repository.

## Target setup

- OS: Omarchy + WSL2
- Shell: Bash
- Terminal: Alacritty
- Prompt: Starship
- Editors: VSCode, Zed
- Agent harness: OpenCode with [ai-memory](https://github.com/akitaonrails/ai-memory) continuity, provided by [`guisaliba/agents`](https://github.com/guisaliba/agents)

The Omarchy clamshell power-management setup is in [`omarchy/`](omarchy/README.md). Apply it only on a workstation that is used with its lid closed and an external display.

## Installer

`install.sh` is the workstation entry point. It reads the component manifest in `components.tsv`, expands each target inside your home directory, copies files atomically, replaces the wallpaper tree, merges the marked alias block, installs selected VS Code extensions, clones or updates the public `guisaliba/agents` repository into a managed checkout, and runs the Omarchy power-management script when the host is Omarchy.

Run the script from the repository root:

```sh
./install.sh              # guided component selection
./install.sh --check      # report what would change without writing
./install.sh --components bash,git,wallpapers --yes
```

Supported options:

- `--check`: report the detected host, selected components, sources, targets, required backups, missing prerequisites, and network, service, or root actions. It performs no writes, clone, fetch, extension install, command, service, or sudo action.
- `--components NAMES`: select only the named components and skip the guided checklist.
- `--host HOST`: `linux`, `wsl2`, or `omarchy`. It overrides host detection only.
- `--yes`: skip the apply confirmation. It is valid only with `--components`. It never adds components and never bypasses the separate agents or Omarchy risk confirmation.
- `--vscode-extensions VALUE`: `all`, `none`, or a comma-separated list of tracked extension identifiers.
- `--help`: show the usage.

The script is a UI and orchestrator only. Safe file operations live in `lib/dotfiles_installer.py`, which uses the standard library and never runs external commands.

## Components

The order and metadata come from `components.tsv`. Component names: `bash`, `git`, `wallpapers`, `starship`, `vscode`, `zed`, `agents`, and `omarchy-power`. `bashrc` is not selectable alone; on WSL2 it is applied as part of `bash`.

| Component | What it does | Risk gate |
| --- | --- | --- |
| `bash` | Merges the marked block from `bash/aliases.bash` into `~/.bash_aliases`, preserving unrelated content and the OpenCode wrapper block. | None |
| `bashrc` | Copies `bash/wsl/.bashrc` to `~/.bashrc` on WSL2. | None |
| `git` | Copies `git/.gitconfig` to `~/.gitconfig`. It never asks for an identity. | None |
| `wallpapers` | Replaces `~/Pictures/wallpapers` with the tracked tree, excluding `README.md`, preserving categories and modes. | None |
| `starship` | Copies `starship/starship.toml` to `~/.config/starship.toml`. It copies even when the binary is absent and warns only. | None |
| `vscode` | Copies `vscode/settings.json` and installs the selected extensions from `vscode/extensions.tsv` with `code --install-extension`. It stops at the first extension failure. | None |
| `zed` | Copies `zed/.config/settings.json` and `keymap.json` to `~/.config/zed/`. The source settings contain no `wsl_connections`. | None |
| `agents` | Clones or fast-forwards the public `guisaliba/agents` repository into `~/.local/share/dotfiles/agents`, then runs its `apply.sh` and `test.sh`. | Network and service confirmation |
| `omarchy-power` | Runs `omarchy/apply-power-management.sh` with sudo. It is applicable only on Omarchy. | Root-power confirmation |

## Backups

Before a file or tree changes, the installer writes a backup under `~/.local/state/dotfiles/backups/<run-id>/`. The run id is one UTC value in the form `YYYYMMDDTHHMMSSZ`. The backup mirrors the absolute target path without the leading slash. `MANIFEST.tsv` records the target path, backup path, component, and operation. No backup is made when the target is equal, and `--check` creates no backup directory.

## Agents

The public [guisaliba/agents](https://github.com/guisaliba/agents) repository is the standalone source of the OpenCode agent stack. `install.sh` manages its clone at `~/.local/share/dotfiles/agents`. The agents component is a network and service action: its `apply.sh` installs packages, runs network install scripts, changes global OpenCode configuration, starts or restarts the ai-memory user service, updates the managed OpenCode Learn checkout, updates agent skills, and merges a marked block into `~/.bash_aliases`.

The managed checkout must be a clean Git worktree on the `main` branch with an approved `guisaliba/agents` remote. The installer refuses a dirty, detached, wrong-branch, wrong-remote, or diverged checkout. It never resets, cleans, stashes, or deletes.

## Risk gates

`--yes` answers the component selection confirmation only. The agents and Omarchy components still show a separate confirmation before they run, because they change the system. The agents confirmation lists the package installs, network scripts, global OpenCode changes, ai-memory service changes, Learn update, skill update, and Bash merge. The Omarchy confirmation lists the two `/etc` targets, sudo, the logind reload, the udev reload, and the clamshell change. Omarchy-power never runs `mx-mini-recover.sh`.

## Verification

Deterministic, machine-independent checks:

```sh
./test.sh --repo-only                 # root installer fixtures
~/.local/share/dotfiles/agents/test.sh --repo-only  # standalone agent fixtures
```

`./test.sh` uses temporary HOME and repository fixtures only. It never modifies a real home directory and never contacts GitHub. Use local bare Git repositories for agent checks.

## License

MIT License
