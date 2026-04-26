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