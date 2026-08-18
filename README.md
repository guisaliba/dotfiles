# Dotfiles

Personal dotfiles for my Linux development environment.

This repository is my portable workstation setup. It tracks shell, editor, prompt, agent harness, and other development configuration that I can replicate across devices.

## Target setup

- OS: Omarchy + WSL2
- Shell: Bash
- Terminal: Alacritty
- Prompt: Starship
- Editors: VSCode, Zed
- Agent harness: OpenCode with ai-memory continuity and optional ai-jail containment

## Usage

Clone the repository:

```sh
git clone https://github.com/guisaliba/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Apply files selectively. Do not blindly overwrite configuration unless the target is documented as managed.

The complete agent-stack setup is in [`agents/README.md`](agents/README.md). Run its apply script only on the intended workstation because it installs native tools, starts a user service, changes global OpenCode configuration, and merges one marked block into `~/.bash_aliases`. After apply, every normal interactive Bash `opencode` command uses an ai-memory managed workstream; `opencode-raw` is the explicit recovery bypass. The default ai-memory profile uses DeepSeek V4 Flash through OpenCode Go and stays in zero-LLM mode until its separate `OPENCODE_API_KEY` is configured.

## License

MIT License
