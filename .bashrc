# ~/.bashrc: executed by bash(1) for non-login shells.

# Exit if not running interactively
case $- in
    *i*) ;;
      *) return;;
esac

# History behavior
HISTCONTROL=ignoreboth  # ignore duplicates and lines starting with space
shopt -s histappend     # append to history file instead of overwriting
HISTSIZE=1000
HISTFILESIZE=2000

# Adjust LINES and COLUMNS after resizing terminal window
shopt -s checkwinsize

# Lesspipe for friendlier viewing of non-text files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Enable color prompt if terminal supports it
if [ -x /usr/bin/tput ] && tput setaf 1 &>/dev/null; then
    PS1='\[\033[01;34m\]\u@\h\[\033[00m\]:\[\033[01;35m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi

# Enable ls and grep color support + load dircolors
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Load custom aliases if present
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Starship prompt
export STARSHIP_CONFIG=~/.config/starship.toml
eval "$(starship init bash)"
