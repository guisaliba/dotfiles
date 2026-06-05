# Dotfiles

Personal dotfiles for my Linux development environment.

This repository is my portable workstation setup. It tracks shell, editor, terminal, prompt, agent harness, and other development configuration that I can replicate across devices.

## Target setup

- OS: Omarchy + WSL2
- Shell: Bash
- Terminal: Ghostty
- Prompt: Starship
- Editors: VSCode, Zed
- Agent harnesses: Pi, OpenCode, Codex, Claude Code

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

## License

MIT License
