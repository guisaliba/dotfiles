alias py='python3'
# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# >>> dotfiles OpenCode ai-memory wrapper >>>
# Keep this function local to the interactive Bash process. ai-memory then
# resolves the native OpenCode executable without recursing into this wrapper.
unalias opencode opencode-raw 2>/dev/null || true
unset -f opencode opencode-raw 2>/dev/null || true
opencode() {
  local argument
  for argument in "$@"; do
    if [[ "$argument" == "--yolo" || "$argument" == "--auto" ]]; then
      printf '%s\n' \
        'Refusing an unjailed OpenCode dangerous-mode start. Use the documented ai-jail ai-memory run opencode --yolo command.' \
        >&2
      return 2
    fi
  done
  command ai-memory run opencode "$@"
}
opencode-raw() {
  command opencode "$@"
}
# <<< dotfiles OpenCode ai-memory wrapper <<<
