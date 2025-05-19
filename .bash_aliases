# Custom aliases

alias py='python3'
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias encode="$HOME/.config/i3/scripts/encode.sh"

# Open Obsidian vault
alias notes='cd ~/projects/brain && obsidian'
# Alternative if CLI doesn't work: alias notes='obsidian ~/projects/brain'

# Remove all Docker containers
alias drma='docker rm -fv $(docker ps -qa)'

# Basic ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'


# Alert for long-running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
