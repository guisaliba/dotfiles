# ~/.bashrc: executed by bash(1) for non-login interactive shells.

case $- in
  *i*) ;;
  *) return ;;
esac

# Avoid duplicate loading if .bashrc is sourced more than once.
if [[ -n "${GUI_BASHRC_LOADED:-}" ]]; then
  return
fi
export GUI_BASHRC_LOADED=1

# Omarchy defaults: aliases, functions, shell setup, prompt defaults.
if [ -f "$HOME/.local/share/omarchy/default/bash/rc" ]; then
  source "$HOME/.local/share/omarchy/default/bash/rc"
fi

# History
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000

# Keep terminal dimensions current after resize.
shopt -s checkwinsize

# Bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
  fi
fi

# Personal PATH
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# pnpm, only if present
if [ -d "$HOME/.local/share/pnpm" ]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
fi

# Bun, only if present
[ -d "$HOME/.bun/bin" ] && export PATH="$HOME/.bun/bin:$PATH"

# Personal aliases and functions
[ -f "$HOME/.bash_aliases" ] && source "$HOME/.bash_aliases"
[ -f "$HOME/.bash_functions" ] && source "$HOME/.bash_functions"

# Starship
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi