# ~/.bashrc: executed by bash(1) for non-login interactive shells.

case $- in
  *i*) ;;
  *) return ;;
esac

# Omarchy defaults
if [ -f "$HOME/.local/share/omarchy/default/bash/rc" ]; then
  source "$HOME/.local/share/omarchy/default/bash/rc"
fi

# History
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000

# Keep terminal dimensions current after resize
shopt -s checkwinsize

# Bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
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

# Starship
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# Personal aliases
alias py='python3'
alias lg='lazygit'

# Open Obsidian vault
notes() {
  cd "$HOME/projects/brain" && obsidian .
}

# Claude Code helpers
__cc_session_name() {
  local folder project_root status purpose
  folder="$(basename "$PWD")"
  project_root="$(dirname "$PWD")"
  status="active"

  case "$project_root" in
    "$HOME/projects/inactive"*) status="inactive" ;;
  esac

  read -r -p "Session purpose for '$folder' (default: $folder [$status])? " purpose
  [ -z "$purpose" ] && purpose="$folder"

  printf '%s | %s [%s]\n' "$purpose" "$folder" "$status"
}

cc-cloud() {
  if [ "$#" -eq 0 ]; then
    echo 'usage: cc-cloud "Task description"'
    return 1
  fi

  local session_name
  session_name="$(__cc_session_name)"
  echo "Starting cloud session: $session_name"
  claude --remote --name "$session_name" "$@"
}

cc-rc() {
  local session_name
  session_name="$(__cc_session_name)"
  echo "Starting/attaching Remote Control: $session_name"
  claude remote-control --name "$session_name"
}

cc-tp() {
  if [ "$#" -eq 0 ]; then
    echo "usage: cc-tp <session-id-or-name>"
    return 1
  fi

  echo "Teleporting session '$1' to local..."
  claude --teleport "$1"
}

cc-ls() {
  echo "Local sessions in $PWD:"
  claude --resume
}
