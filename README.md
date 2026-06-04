# Dotfiles

Personal dotfiles for my Linux development environment.

This repository is my portable workstation setup. It tracks shell, editor, terminal, prompt, agent harness, and other development configuration that I can replicate across devices.

## Target setup

- OS: Omarchy / Arch Linux, plus WSL2 when needed
- Shell: Bash
- Terminal: Ghostty
- Prompt: Starship
- Editors: VSCode, Zed
- Agent harnesses: Pi, OpenCode, Codex

## Philosophy

This is a living setup, not an archive of old desktop environments or one-off experiments.

Prefer small, explicit configuration over opaque installers. Scripts should be idempotent, easy to inspect, and safe to rerun.

## Usage

Clone the repository:

```sh
git clone https://github.com/guisaliba/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Apply files selectively. Do not blindly overwrite configuration unless the target is documented as managed.

## Agent stack

The coding-agent setup is managed from `agents/` and materialized through `chezmoi/`.

Current architecture:

- canonical global instructions: `agents/AGENTS.md`
- shared skills source: `chezmoi/dot_agents/skills/`
- chezmoi source tree: `chezmoi/`
- managed targets:
  - `~/.codex/AGENTS.md`
  - `~/.codex/config.toml`
  - `~/.codex/config.json`
  - `~/.codex/hooks.json`
  - `~/.codex/skills/`
  - `~/.config/opencode/AGENTS.md`
  - `~/.config/opencode/opencode.json`
  - `~/.config/opencode/commands/`
  - `~/.pi/agent/AGENTS.md`
  - `~/.pi/agent/settings.json`
  - `~/.pi/agent/extensions/`
  - `~/.agents/skills/`

Apply the agent stack:

```sh
./agents/apply-agent-stack.sh
```

The applier backs up known managed targets, removes deprecated agent symlinks/files, applies chezmoi, and installs supported integrations for caveman, cavemem, rtk, and plannotator.

Plannotator binary is installed automatically only when missing. Pin a version with `PLANNOTATOR_VERSION=vX.Y.Z`.

Defaults are local-only: no nested Pi review, no commit, no push. Use `COMMIT=1` or `COMMIT=1 PUSH=1` explicitly when needed.

## License

MIT License
