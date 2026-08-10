# Dotfiles

Personal dotfiles for my Linux development environment.

This repository is my portable workstation setup. It tracks shell, editor, prompt, agent harness, and other development configuration that I can replicate across devices.

## Target setup

- OS: Omarchy + WSL2
- Shell: Bash
- Terminal: Alacritty
- Prompt: Starship
- Editors: VSCode, Zed
- Agent harness: OpenCode

## Usage

Clone the repository:

```sh
git clone https://github.com/guisaliba/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Apply files selectively. Do not blindly overwrite configuration unless the target is documented as managed.

Available profiles:

- `omarchy/`: tested Omarchy 3 Cliamp screensaver setup. See `omarchy/README.md` before applying it. It intentionally rejects Omarchy Quattro.

## License

MIT License
