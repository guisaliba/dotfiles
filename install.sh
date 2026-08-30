#!/usr/bin/env bash
set -Eeuo pipefail

# install.sh
#
# Workstation dotfiles installer. This script is the UI and orchestrator.
# It drives the components manifest through the safe file operations in
# lib/dotfiles_installer.py. Repository-only tests use a temporary HOME;
# the helper never runs external commands.
#
# Usage:
#   ./install.sh [--check] [--components NAMES] [--host HOST]
#                [--yes] [--vscode-extensions VALUE] [--help]

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
HELPER="$REPO_DIR/lib/dotfiles_installer.py"
COMPONENTS_MANIFEST="$REPO_DIR/components.tsv"
VSCODE_EXTENSIONS_FILE="$REPO_DIR/vscode/extensions.tsv"

BASH_ALIASES_BLOCK_START="# >>> dotfiles aliases >>>"
BASH_ALIASES_BLOCK_END="# <<< dotfiles aliases <<<"
WALLPAPERS_EXCLUDE="README.md"
ZED_FILES=("settings.json" "keymap.json")

TEST_MODE="${DOTFILES_TEST_MODE:-0}"
case "$TEST_MODE" in
  0|1) ;;
  *)
    printf 'ERROR: DOTFILES_TEST_MODE must be 0 or 1\n' >&2
    exit 2
    ;;
esac

if [[ "$TEST_MODE" == 1 ]]; then
  PROC_DIR="${DOTFILES_PROC_DIR:-/proc}"
  ETC_DIR="${DOTFILES_ETC_DIR:-/etc}"
  STATE_DIR="${DOTFILES_STATE_DIR:-$HOME/.local/state/dotfiles}"
  AGENTS_REPOSITORY_URL="${DOTFILES_AGENTS_URL:-https://github.com/guisaliba/agents}"
  AGENTS_REMOTE_IDENTITY="${DOTFILES_AGENTS_REMOTE:-github.com/guisaliba/agents}"
  AGENTS_CHECKOUT_DIR="${DOTFILES_AGENTS_CHECKOUT:-$HOME/.local/share/dotfiles/agents}"
  OMARCHY_APPLY_SCRIPT="${DOTFILES_OMARCHY_APPLY:-$REPO_DIR/omarchy/apply-power-management.sh}"
else
  PROC_DIR="/proc"
  ETC_DIR="/etc"
  STATE_DIR="$HOME/.local/state/dotfiles"
  AGENTS_REPOSITORY_URL="https://github.com/guisaliba/agents"
  AGENTS_REMOTE_IDENTITY="github.com/guisaliba/agents"
  AGENTS_CHECKOUT_DIR="$HOME/.local/share/dotfiles/agents"
  OMARCHY_APPLY_SCRIPT="$REPO_DIR/omarchy/apply-power-management.sh"
fi

BACKUP_ROOT="$STATE_DIR/backups"
AGENTS_BRANCH="main"

CHECK_MODE=0
YES_MODE=0
CHECK_SET=0
YES_SET=0
COMPONENTS_SET=0
HOST_SET=0
VSCODE_EXT_SET=0
COMPONENTS_ARG=""
HOST_ARG=""
VSCODE_EXT_ARG=""
HOST=""
SELECTED=()
SELECTED_EXTENSIONS=()
APPLY_ORDER=()
EXTENSIONS=()

declare -A COMP_ACTION COMP_SOURCE COMP_TARGET COMP_HOSTS COMP_DEFAULT COMP_RISK
COMPONENTS=()
SELECTABLE_COMPONENTS=()

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --check                       Report what would change without writing
  --components NAMES            Comma-separated component names
  --host HOST                   linux, wsl2, or omarchy (override detection)
  --yes                         Skip the apply confirmation; valid only with --components
  --vscode-extensions VALUE     all, none, or comma-separated tracked extension IDs
  --help                        Show this help
EOF
}

usage_error() {
  printf 'ERROR: %s\n' "$*" >&2
  usage >&2
  exit 2
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

remove_from() {
  local -n array_ref="$1"
  local needle="$2"
  local -a out=()
  local item
  for item in "${array_ref[@]}"; do
    if [[ "$item" != "$needle" ]]; then
      out+=("$item")
    fi
  done
  array_ref=("${out[@]}")
}

parse_args() {
  local seen_help=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        if [[ "$CHECK_SET" -eq 1 ]]; then
          usage_error "duplicate option: --check"
        fi
        CHECK_SET=1
        CHECK_MODE=1
        shift
        ;;
      --yes)
        if [[ "$YES_SET" -eq 1 ]]; then
          usage_error "duplicate option: --yes"
        fi
        YES_SET=1
        YES_MODE=1
        shift
        ;;
      --components)
        if [[ "$COMPONENTS_SET" -eq 1 ]]; then
          usage_error "duplicate option: --components"
        fi
        COMPONENTS_SET=1
        if [[ $# -lt 2 ]]; then
          usage_error "--components requires a comma-separated list"
        fi
        COMPONENTS_ARG="$2"
        [[ -n "$COMPONENTS_ARG" ]] || usage_error "--components requires a comma-separated list"
        shift 2
        ;;
      --host)
        if [[ "$HOST_SET" -eq 1 ]]; then
          usage_error "duplicate option: --host"
        fi
        HOST_SET=1
        if [[ $# -lt 2 ]]; then
          usage_error "--host requires a value"
        fi
        HOST_ARG="$2"
        [[ -n "$HOST_ARG" ]] || usage_error "--host requires a value"
        shift 2
        ;;
      --vscode-extensions)
        if [[ "$VSCODE_EXT_SET" -eq 1 ]]; then
          usage_error "duplicate option: --vscode-extensions"
        fi
        VSCODE_EXT_SET=1
        if [[ $# -lt 2 ]]; then
          usage_error "--vscode-extensions requires a value"
        fi
        VSCODE_EXT_ARG="$2"
        [[ -n "$VSCODE_EXT_ARG" ]] || usage_error "--vscode-extensions requires a value"
        shift 2
        ;;
      --help)
        if [[ "$seen_help" -eq 1 ]]; then
          usage_error "duplicate option: --help"
        fi
        seen_help=1
        usage
        exit 0
        ;;
      -?*)
        usage_error "unknown option: $1"
        ;;
      *)
        usage_error "unexpected argument: $1"
        ;;
    esac
  done

  if [[ "$HOST_SET" -eq 1 ]] && [[ "$HOST_ARG" != linux && "$HOST_ARG" != wsl2 && "$HOST_ARG" != omarchy ]]; then
    usage_error "invalid host: $HOST_ARG (use linux, wsl2, or omarchy)"
  fi
  if [[ "$YES_SET" -eq 1 && "$COMPONENTS_SET" -eq 0 ]]; then
    usage_error "--yes is valid only with --components"
  fi
  if [[ "$VSCODE_EXT_SET" -eq 1 && "$COMPONENTS_SET" -eq 0 ]]; then
    usage_error "--vscode-extensions is valid only with --components"
  fi
}

parse_manifest() {
  local manifest_output
  if ! manifest_output="$(python3 "$HELPER" manifest "$COMPONENTS_MANIFEST")"; then
    die "invalid components manifest: $COMPONENTS_MANIFEST"
  fi
  local row comp action source target hosts default risk
  while IFS= read -r row || [[ -n "$row" ]]; do
    comp="$(cut -f1 <<<"$row")"
    action="$(cut -f2 <<<"$row")"
    source="$(cut -f3 <<<"$row")"
    target="$(cut -f4 <<<"$row")"
    hosts="$(cut -f5 <<<"$row")"
    default="$(cut -f6 <<<"$row")"
    risk="$(cut -f7 <<<"$row")"
    COMPONENTS+=("$comp")
    COMP_ACTION["$comp"]="$action"
    COMP_SOURCE["$comp"]="$source"
    COMP_TARGET["$comp"]="$target"
    COMP_HOSTS["$comp"]="$hosts"
    COMP_DEFAULT["$comp"]="$default"
    COMP_RISK["$comp"]="$risk"
  done <<<"$manifest_output"
  local item
  for item in "${COMPONENTS[@]}"; do
    if [[ "$item" != "bashrc" ]]; then
      SELECTABLE_COMPONENTS+=("$item")
    fi
  done
}

load_extensions() {
  local id extension_pattern='^[[:alnum:]_][[:alnum:]_-]*\.[[:alnum:]_][[:alnum:]_.-]*$'
  EXTENSIONS=()
  while IFS= read -r id || [[ -n "$id" ]]; do
    if [[ -z "$id" || "$id" == \#* ]]; then
      continue
    fi
    if [[ ! "$id" =~ $extension_pattern ]]; then
      die "invalid tracked VS Code extension ID: $id"
    fi
    if contains "$id" "${EXTENSIONS[@]}"; then
      die "duplicate tracked VS Code extension ID: $id"
    fi
    EXTENSIONS+=("$id")
  done <"$VSCODE_EXTENSIONS_FILE"
  if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
    die "no tracked extensions in $VSCODE_EXTENSIONS_FILE"
  fi
}

detect_host() {
  if { cat "$PROC_DIR/sys/kernel/osrelease" "$PROC_DIR/version" 2>/dev/null; } \
    | grep -qiE '(^|[^[:alpha:]])(microsoft|wsl[[:digit:]]*)([^[:alpha:]]|$)'; then
    printf 'wsl2\n'
    return
  fi
  if [[ -r "$ETC_DIR/os-release" ]] \
    && awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' "$ETC_DIR/os-release" \
    | grep -qx omarchy; then
    printf 'omarchy\n'
    return
  fi
  printf 'linux\n'
}

host_applies() {
  local comp="$1" host="$2"
  local -a fields=()
  local field
  IFS=',' read -r -a fields <<<"${COMP_HOSTS["$comp"]}"
  for field in "${fields[@]}"; do
    if [[ "$field" == "all" || "$field" == "$host" ]]; then
      return 0
    fi
  done
  return 1
}

confirm_yesno() {
  local prompt_text="$1" answer
  printf '%s [y/N] ' "$prompt_text" >&2
  if ! read -r answer; then
    printf 'no\n' >&2
    return 1
  fi
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

show_checklist() {
  local selection_name="$1"
  shift
  local -n selection_ref="$selection_name"
  local index item marker
  index=1
  for item in "$@"; do
    marker=' '
    if contains "$item" "${selection_ref[@]}"; then
      marker='*'
    fi
    printf '  %d) [%s] %s\n' "$index" "$marker" "$item"
    index=$((index + 1))
  done
}

checklist_prompt() {
  local array_name="$1"
  shift
  local -n selection_ref="$array_name"
  local -a items=("$@")
  local item answer token valid number index
  while true; do
    show_checklist "$array_name" "${items[@]}"
    printf 'Toggle numbers (comma-separated), a=all, n=none, Enter=continue, q=quit: ' >&2
    if ! read -r answer; then
      return 0
    fi
    case "$answer" in
      '') return 0 ;;
      q|Q)
        printf 'Aborted. No changes made.\n'
        exit 0
        ;;
      a|A)
        selection_ref=("${items[@]}")
        ;;
      n|N)
        selection_ref=()
        ;;
      *)
        valid=1
        IFS=',' read -r -a tokens <<<"$answer"
        for token in "${tokens[@]}"; do
          if [[ "$token" =~ ^[0-9]+$ ]] && ((token >= 1 && token <= ${#items[@]})); then
            number=$((token - 1))
            item="${items[$number]}"
            if contains "$item" "${selection_ref[@]}"; then
              remove_from "$array_name" "$item"
            else
              selection_ref+=("$item")
            fi
          else
            printf 'Invalid toggle: %s\n' "$token" >&2
            valid=0
          fi
        done
        if [[ "$valid" -eq 0 ]]; then
          continue
        fi
        ;;
    esac
  done
}

guided_select_components() {
  local host="$1"
  local -a applicable=()
  local comp
  SELECTED=()
  for comp in "${SELECTABLE_COMPONENTS[@]}"; do
    if host_applies "$comp" "$host"; then
      applicable+=("$comp")
      if [[ "${COMP_DEFAULT["$comp"]}" == "yes" ]]; then
        SELECTED+=("$comp")
      fi
    fi
  done
  printf '\nSelect components to apply:\n'
  checklist_prompt SELECTED "${applicable[@]}"
}

guided_select_extensions() {
  SELECTED_EXTENSIONS=("${EXTENSIONS[@]}")
  printf '\nSelect VS Code extensions to install:\n'
  checklist_prompt SELECTED_EXTENSIONS "${EXTENSIONS[@]}"
}

resolve_selection() {
  if [[ "$COMPONENTS_SET" -eq 1 ]]; then
    local -a name_list=() checked=()
    local name comp
    IFS=',' read -r -a name_list <<<"$COMPONENTS_ARG"
    if [[ ${#name_list[@]} -eq 0 ]]; then
      usage_error "--components requires at least one component"
    fi
    for name in "${name_list[@]}"; do
      if [[ -z "$name" ]]; then
        usage_error "--components contains an empty component name"
      fi
      if contains "$name" "${checked[@]}"; then
        usage_error "duplicate component: $name"
      fi
      checked+=("$name")
      contains "$name" "${SELECTABLE_COMPONENTS[@]}" || usage_error "unknown component: $name"
      host_applies "$name" "$HOST" || usage_error "component not applicable to host $HOST: $name"
    done
    SELECTED=()
    for comp in "${SELECTABLE_COMPONENTS[@]}"; do
      if contains "$comp" "${name_list[@]}"; then
        SELECTED+=("$comp")
      fi
    done
    if [[ "$VSCODE_EXT_SET" -eq 1 ]]; then
      contains vscode "${SELECTED[@]}" || usage_error "--vscode-extensions requires vscode to be a selected component"
      case "$VSCODE_EXT_ARG" in
        all)
          SELECTED_EXTENSIONS=("${EXTENSIONS[@]}")
          ;;
        none)
          SELECTED_EXTENSIONS=()
          ;;
        *)
          SELECTED_EXTENSIONS=()
          local -a ext_list=() checked_ext=()
          IFS=',' read -r -a ext_list <<<"$VSCODE_EXT_ARG"
          if [[ ${#ext_list[@]} -eq 0 ]]; then
            usage_error "--vscode-extensions requires at least one extension ID"
          fi
          for name in "${ext_list[@]}"; do
            if [[ -z "$name" ]]; then
              usage_error "--vscode-extensions contains an empty extension ID"
            fi
            if contains "$name" "${checked_ext[@]}"; then
              usage_error "duplicate VS Code extension: $name"
            fi
            checked_ext+=("$name")
            contains "$name" "${EXTENSIONS[@]}" || usage_error "unknown VS Code extension: $name"
            SELECTED_EXTENSIONS+=("$name")
          done
          ;;
      esac
    else
      if contains vscode "${SELECTED[@]}"; then
        SELECTED_EXTENSIONS=("${EXTENSIONS[@]}")
      else
        SELECTED_EXTENSIONS=()
      fi
    fi
    if [[ "$YES_MODE" -eq 1 ]] && contains vscode "${SELECTED[@]}" && [[ "$VSCODE_EXT_SET" -eq 0 ]]; then
      usage_error "--vscode-extensions is required with --yes when vscode is selected"
    fi
  else
    guided_select_components "$HOST"
    if contains vscode "${SELECTED[@]}"; then
      guided_select_extensions
    else
      SELECTED_EXTENSIONS=()
    fi
  fi

  APPLY_ORDER=()
  for comp in "${COMPONENTS[@]}"; do
    if contains "$comp" "${SELECTED[@]}"; then
      APPLY_ORDER+=("$comp")
    fi
    if [[ "$comp" == "bashrc" ]] \
      && contains bash "${SELECTED[@]}" \
      && host_applies bashrc "$HOST"; then
      APPLY_ORDER+=("bashrc")
    fi
  done
}

component_status() {
  local comp="$1"
  local source_rel target
  source_rel="${COMP_SOURCE["$comp"]}"
  target="${COMP_TARGET["$comp"]}"
  case "${COMP_ACTION["$comp"]}" in
    merge-block)
      python3 "$HELPER" check-merge \
        "$REPO_DIR/$source_rel" \
        "$target" \
        "$BASH_ALIASES_BLOCK_START" \
        "$BASH_ALIASES_BLOCK_END"
      ;;
    copy-file)
      python3 "$HELPER" check-file "$REPO_DIR/$source_rel" "$target"
      ;;
    replace-tree)
      python3 "$HELPER" check-tree \
        "$REPO_DIR/$source_rel" \
        "$target" \
        --exclude "$WALLPAPERS_EXCLUDE"
      ;;
    vscode)
      python3 "$HELPER" check-file "$REPO_DIR/$source_rel" "$target" 2>/dev/null
      ;;
    zed)
      local a b
      if ! a="$(python3 "$HELPER" check-file "$REPO_DIR/$source_rel/settings.json" "$target/settings.json")"; then
        return 1
      fi
      if ! b="$(python3 "$HELPER" check-file "$REPO_DIR/$source_rel/keymap.json" "$target/keymap.json")"; then
        return 1
      fi
      if [[ "$a" == changed || "$b" == changed ]]; then
        printf 'changed\n'
      else
        printf 'equal\n'
      fi
      ;;
    agents|omarchy-power)
      printf 'n/a\n'
      ;;
  esac
}

agents_checkout_inspect() {
  local checkout="$AGENTS_CHECKOUT_DIR"
  if [[ -L "$checkout" ]]; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout must not be a symlink: %s\n' "$checkout" >&2
    return 1
  fi
  if [[ ! -e "$checkout" ]]; then
    printf 'absent\n'
    return 0
  fi
  if [[ ! -d "$checkout" ]]; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout path is not a directory: %s\n' "$checkout" >&2
    return 1
  fi
  if ! git -C "$checkout" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout is not a Git repository: %s\n' "$checkout" >&2
    return 1
  fi
  local root
  root="$(git -C "$checkout" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'invalid\n'
    printf 'ERROR: could not resolve the agents checkout root\n' >&2
    return 1
  }
  if [[ "$(cd -- "$root" && pwd -P)" != "$(cd -- "$checkout" && pwd -P)" ]]; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout must be the Git worktree root: %s\n' "$checkout" >&2
    return 1
  fi
  local remote identity approved branch dirty
  remote="$(git -C "$checkout" remote get-url origin 2>/dev/null)" || {
    printf 'invalid\n'
    printf 'ERROR: agents checkout has no origin remote\n' >&2
    return 1
  }
  identity="$(python3 "$HELPER" remote-identity "$remote" 2>/dev/null || true)"
  approved="$(python3 "$HELPER" remote-identity "$AGENTS_REMOTE_IDENTITY" 2>/dev/null || true)"
  if [[ "$identity" != "$approved" ]]; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout origin does not match %s: %s\n' \
      "$AGENTS_REMOTE_IDENTITY" "$remote" >&2
    return 1
  fi
  branch="$(git -C "$checkout" branch --show-current 2>/dev/null || true)"
  if [[ "$branch" != "$AGENTS_BRANCH" ]]; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout must use branch %s (found %s)\n' \
      "$AGENTS_BRANCH" "${branch:-detached}" >&2
    return 1
  fi
  dirty="$(git -C "$checkout" status --porcelain --untracked-files=all 2>/dev/null || true)"
  if [[ -n "$dirty" ]]; then
    printf 'invalid\n'
    printf 'ERROR: agents checkout has uncommitted changes; refusing to update\n' >&2
    return 1
  fi
  printf 'clean\n'
}

agents_checkout_update() {
  printf 'Fetching origin/%s\n  git -C %s fetch --prune origin %s\n' \
    "$AGENTS_BRANCH" "$AGENTS_CHECKOUT_DIR" "$AGENTS_BRANCH"
  git -C "$AGENTS_CHECKOUT_DIR" fetch --prune origin "$AGENTS_BRANCH" || {
    printf 'ERROR: git fetch failed for the agents checkout\n' >&2
    return 1
  }
  local local_head origin_head merge_base
  local_head="$(git -C "$AGENTS_CHECKOUT_DIR" rev-parse HEAD)"
  origin_head="$(git -C "$AGENTS_CHECKOUT_DIR" rev-parse "origin/$AGENTS_BRANCH")"
  if [[ "$local_head" == "$origin_head" ]]; then
    printf 'Managed checkout is up to date.\n'
    return 0
  fi
  merge_base="$(git -C "$AGENTS_CHECKOUT_DIR" merge-base HEAD "origin/$AGENTS_BRANCH")"
  if [[ "$merge_base" != "$local_head" ]]; then
    printf 'ERROR: agents checkout has diverged from origin/%s; refusing to reset or merge\n' \
      "$AGENTS_BRANCH" >&2
    return 1
  fi
  git -C "$AGENTS_CHECKOUT_DIR" merge --ff-only "origin/$AGENTS_BRANCH" || {
    printf 'ERROR: agents checkout cannot fast-forward to origin/%s\n' "$AGENTS_BRANCH" >&2
    return 1
  }
}

run_agents_component() {
  local status
  printf '\nAgent stack component:\n'
  printf '  Managed checkout: %s\n' "$AGENTS_CHECKOUT_DIR"
  printf '  This component clones or updates %s and then runs apply.sh and test.sh in the checkout.\n' \
    "$AGENTS_REPOSITORY_URL"
  printf '  apply.sh will:\n'
  printf '    - install or update packages (OpenCode, ai-memory, RTK, Plannotator)\n'
  printf '    - run network install scripts\n'
  printf '    - change global OpenCode configuration\n'
  printf '    - start or restart the ai-memory user service\n'
  printf '    - update the managed OpenCode Learn checkout\n'
  printf '    - install or update agent skills\n'
  printf '    - merge a marked block into ~/.bash_aliases\n'
  if ! confirm_yesno 'Run the agent stack apply now?'; then
    printf 'Skipped the agent stack apply.\n'
    return 2
  fi
  status="$(agents_checkout_inspect)" || return 1
  if [[ "$status" == absent ]]; then
    mkdir -p -- "$(dirname -- "$AGENTS_CHECKOUT_DIR")"
    printf 'Cloning %s\n  git clone --branch %s --single-branch %s %s\n' \
      "$AGENTS_REPOSITORY_URL" \
      "$AGENTS_BRANCH" \
      "$AGENTS_REPOSITORY_URL" \
      "$AGENTS_CHECKOUT_DIR"
    git clone --branch "$AGENTS_BRANCH" --single-branch \
      "$AGENTS_REPOSITORY_URL" "$AGENTS_CHECKOUT_DIR" || {
      printf 'ERROR: git clone failed for %s\n' "$AGENTS_REPOSITORY_URL" >&2
      return 1
    }
    git -C "$AGENTS_CHECKOUT_DIR" checkout "$AGENTS_BRANCH" || {
      printf 'ERROR: could not check out %s in the agents checkout\n' "$AGENTS_BRANCH" >&2
      return 1
    }
  else
    agents_checkout_update || return 1
  fi
  printf 'Running %s/apply.sh\n' "$AGENTS_CHECKOUT_DIR"
  (cd -- "$AGENTS_CHECKOUT_DIR" && bash ./apply.sh) || {
    printf 'ERROR: agents apply.sh failed\n' >&2
    return 1
  }
  printf 'Running %s/test.sh\n' "$AGENTS_CHECKOUT_DIR"
  (cd -- "$AGENTS_CHECKOUT_DIR" && bash ./test.sh) || {
    printf 'ERROR: agents test.sh failed\n' >&2
    return 1
  }
}

run_omarchy_power_component() {
  printf '\nOmarchy power management component:\n'
  printf '  Runs %s with sudo.\n' "$OMARCHY_APPLY_SCRIPT"
  printf '  It will:\n'
  printf '    - write /etc/systemd/logind.conf.d/90-dotfiles-clamshell.conf\n'
  printf '    - write /etc/udev/rules.d/91-dotfiles-bluetooth-wakeup.rules\n'
  printf '    - use sudo\n'
  printf '    - reload systemd-logind\n'
  printf '    - reload udev rules\n'
  printf '    - enable Bluetooth wake for clamshell use\n'
  if ! confirm_yesno 'Run the Omarchy power management apply now?'; then
    printf 'Skipped the Omarchy power management apply.\n'
    return 2
  fi
  bash "$OMARCHY_APPLY_SCRIPT" || {
    printf 'ERROR: Omarchy power management apply failed\n' >&2
    return 1
  }
}

run_vscode_component() {
  local backup_root="$1" target="$2"
  local -a backup_args=()
  local id
  if [[ -n "$backup_root" ]]; then
    backup_args=(--backup-root "$backup_root" --component vscode)
  fi
  python3 "$HELPER" copy-file \
    "$REPO_DIR/vscode/settings.json" \
    "$target" \
    "${backup_args[@]}"
  if [[ ${#SELECTED_EXTENSIONS[@]} -gt 0 ]]; then
    if ! command -v code >/dev/null 2>&1; then
      die "code command not found; cannot install the selected VS Code extensions"
    fi
    for id in "${SELECTED_EXTENSIONS[@]}"; do
      printf 'code --install-extension %s\n' "$id"
      code --install-extension "$id" || die "VS Code extension installation failed: $id"
    done
  fi
}

run_zed_component() {
  local backup_root="$1" target="$2"
  local -a backup_args=()
  local file
  if [[ -n "$backup_root" ]]; then
    backup_args=(--backup-root "$backup_root" --component zed)
  fi
  for file in "${ZED_FILES[@]}"; do
    python3 "$HELPER" copy-file \
      "$REPO_DIR/zed/.config/$file" \
      "$target/$file" \
      "${backup_args[@]}"
  done
}

apply_component() {
  local comp="$1" backup_root="$2"
  local -a backup_args=()
  if [[ -n "$backup_root" ]]; then
    backup_args=(--backup-root "$backup_root" --component "$comp")
  fi
  case "${COMP_ACTION["$comp"]}" in
    merge-block)
      python3 "$HELPER" merge-block \
        "$REPO_DIR/${COMP_SOURCE["$comp"]}" \
        "${COMP_TARGET["$comp"]}" \
        "$BASH_ALIASES_BLOCK_START" \
        "$BASH_ALIASES_BLOCK_END" \
        "${backup_args[@]}"
      ;;
    copy-file)
      python3 "$HELPER" copy-file \
        "$REPO_DIR/${COMP_SOURCE["$comp"]}" \
        "${COMP_TARGET["$comp"]}" \
        "${backup_args[@]}"
      if [[ "$comp" == starship ]] && ! command -v starship >/dev/null 2>&1; then
        printf 'WARNING: starship command is missing; the config is copied anyway\n' >&2
      fi
      ;;
    replace-tree)
      python3 "$HELPER" tree-replace \
        "$REPO_DIR/${COMP_SOURCE["$comp"]}" \
        "${COMP_TARGET["$comp"]}" \
        --exclude "$WALLPAPERS_EXCLUDE" \
        "${backup_args[@]}"
      ;;
    vscode)
      run_vscode_component "$backup_root" "${COMP_TARGET["$comp"]}"
      ;;
    zed)
      run_zed_component "$backup_root" "${COMP_TARGET["$comp"]}"
      ;;
    agents)
      run_agents_component
      ;;
    omarchy-power)
      run_omarchy_power_component
      ;;
  esac
}

run_check() {
  local errors=0 comp status source_rel target
  printf 'Detected host: %s\n' "$HOST"
  printf 'Selected components: %s\n' "$(IFS=,; printf '%s' "${APPLY_ORDER[*]}")"
  if [[ ${#SELECTED_EXTENSIONS[@]} -gt 0 ]]; then
    printf 'Selected VS Code extensions (%s): %s\n' \
      "${#SELECTED_EXTENSIONS[@]}" "$(IFS=,; printf '%s' "${SELECTED_EXTENSIONS[*]}")"
  fi
  for comp in "${APPLY_ORDER[@]}"; do
    source_rel="${COMP_SOURCE["$comp"]}"
    target="${COMP_TARGET["$comp"]}"
    printf '\nComponent: %s\n' "$comp"
    case "${COMP_ACTION["$comp"]}" in
      merge-block)
        printf '  action: merge-block\n  source: %s\n  target: %s\n' "$source_rel" "$target"
        if status="$(component_status "$comp")"; then
          if [[ "$status" == changed ]]; then
            printf '  required backup: yes\n'
          else
            printf '  required backup: no\n'
          fi
        else
          printf '  required backup: error\n'
          errors=$((errors + 1))
        fi
        printf '  missing prerequisite: none\n  network action: none\n  service action: none\n  root action: none\n'
        ;;
      copy-file)
        printf '  action: copy-file\n  source: %s\n  target: %s\n' "$source_rel" "$target"
        if status="$(component_status "$comp")"; then
          if [[ "$status" == changed ]]; then
            printf '  required backup: yes\n'
          else
            printf '  required backup: no\n'
          fi
        else
          printf '  required backup: error\n'
          errors=$((errors + 1))
        fi
        printf '  missing prerequisite: none\n  network action: none\n  service action: none\n  root action: none\n'
        if [[ "$comp" == starship ]] && ! command -v starship >/dev/null 2>&1; then
          printf '  note: starship command is missing; the config is copied anyway\n'
        fi
        ;;
      replace-tree)
        printf '  action: replace-tree\n  source: %s\n  target: %s\n' "$source_rel" "$target"
        if status="$(component_status "$comp")"; then
          if [[ "$status" == changed ]]; then
            printf '  required backup: yes\n'
          else
            printf '  required backup: no\n'
          fi
        else
          printf '  required backup: error\n'
          errors=$((errors + 1))
        fi
        printf '  missing prerequisite: none\n  network action: none\n  service action: none\n  root action: none\n'
        ;;
      vscode)
        printf '  action: vscode\n  source: %s\n  target: %s\n' "$source_rel" "$target"
        if status="$(component_status "$comp")"; then
          if [[ "$status" == changed ]]; then
            printf '  required backup: yes\n'
          else
            printf '  required backup: no\n'
          fi
        else
          printf '  required backup: error\n'
          errors=$((errors + 1))
        fi
        if [[ ${#SELECTED_EXTENSIONS[@]} -gt 0 ]]; then
          if command -v code >/dev/null 2>&1; then
            printf '  missing prerequisite: none\n'
          else
            printf '  missing prerequisite: code command is missing\n'
          fi
          printf '  network action: installs %s VS Code extension(s)\n' "${#SELECTED_EXTENSIONS[@]}"
        else
          printf '  missing prerequisite: none\n  network action: none\n'
        fi
        printf '  service action: none\n  root action: none\n'
        ;;
      zed)
        printf '  action: zed\n  source: %s\n  target: %s\n' "$source_rel" "$target"
        if status="$(component_status "$comp")"; then
          if [[ "$status" == changed ]]; then
            printf '  required backup: yes\n'
          else
            printf '  required backup: no\n'
          fi
        else
          printf '  required backup: error\n'
          errors=$((errors + 1))
        fi
        printf '  missing prerequisite: none\n  network action: none\n  service action: none\n  root action: none\n'
        ;;
      agents)
        printf '  action: agents\n  source: %s\n  target: %s\n' "$source_rel" "$AGENTS_CHECKOUT_DIR"
        if status="$(agents_checkout_inspect)"; then
          if [[ "$status" == absent ]]; then
            printf '  required backup: no\n  missing prerequisite: none\n'
            printf '  network action: clone would occur: git clone --branch %s --single-branch %s %s\n' \
              "$AGENTS_BRANCH" "$AGENTS_REPOSITORY_URL" "$AGENTS_CHECKOUT_DIR"
          else
            printf '  required backup: no\n  missing prerequisite: none\n'
            printf '  network action: fetch origin/%s then fast-forward; run apply.sh and test.sh\n' "$AGENTS_BRANCH"
          fi
          printf '  service action: apply.sh starts or restarts the ai-memory user service\n  root action: none\n'
        else
          printf '  required backup: no\n  missing prerequisite: none\n  network action: none\n'
          printf '  service action: none\n  root action: none\n'
          errors=$((errors + 1))
        fi
        ;;
      omarchy-power)
        printf '  action: omarchy-power\n  source: %s\n  target: (system paths)\n' "$source_rel"
        printf '  required backup: no\n'
        if command -v sudo >/dev/null 2>&1; then
          printf '  missing prerequisite: none\n'
        else
          printf '  missing prerequisite: sudo command is missing\n'
        fi
        printf '  network action: none\n  service action: none\n'
        printf '  root action: sudo writes /etc/systemd/logind.conf.d/90-dotfiles-clamshell.conf and /etc/udev/rules.d/91-dotfiles-bluetooth-wakeup.rules, reloads logind and udev\n'
        ;;
    esac
  done
  printf '\nCheck completed. No changes were made.\n'
  if [[ "$errors" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

run_apply() {
  local -a completed=() skipped=() failed=()
  local comp status rc backup_root="" need_backup=false
  local run_id backup_dir

  for comp in "${APPLY_ORDER[@]}"; do
    case "${COMP_ACTION["$comp"]}" in
      merge-block|copy-file|replace-tree|vscode|zed)
        if ! status="$(component_status "$comp")"; then
          failed+=("$comp")
          printf 'ERROR: component %s failed preflight; no changes were made.\n' \
            "$comp" >&2
          break
        fi
        if [[ "$status" == changed ]]; then
          need_backup=true
        fi
        ;;
    esac
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    printf '\nCompleted: %s\nSkipped: %s\nFailed: %s\n' \
      "$(IFS=,; printf '%s' "${completed[*]}")" \
      "$(IFS=,; printf '%s' "${skipped[*]}")" \
      "$(IFS=,; printf '%s' "${failed[*]}")"
    exit 1
  fi

  if [[ "$need_backup" == true ]]; then
    backup_dir="$(python3 "$HELPER" begin-backup "$BACKUP_ROOT" | cut -f2)"
    printf '\nBackup directory: %s\n' "$backup_dir"
    backup_root="$backup_dir"
  fi

  printf '\nApplying components\n'
  for comp in "${APPLY_ORDER[@]}"; do
    printf '\n==> Applying %s\n' "$comp"
    if (apply_component "$comp" "$backup_root"); then
      completed+=("$comp")
    else
      rc=$?
      if [[ "$rc" -eq 2 ]]; then
        skipped+=("$comp")
      else
        failed+=("$comp")
        printf 'ERROR: component %s failed.\n' "$comp" >&2
        break
      fi
    fi
  done

  printf '\n'
  if [[ ${#failed[@]} -gt 0 ]]; then
    printf 'Completed: %s\nSkipped: %s\nFailed: %s\n' \
      "$(IFS=,; printf '%s' "${completed[*]}")" \
      "$(IFS=,; printf '%s' "${skipped[*]}")" \
      "$(IFS=,; printf '%s' "${failed[*]}")"
    exit 1
  fi
  printf 'Completed: %s\n' "$(IFS=,; printf '%s' "${completed[*]}")"
  if [[ ${#skipped[@]} -gt 0 ]]; then
    printf 'Skipped: %s\n' "$(IFS=,; printf '%s' "${skipped[*]}")"
  fi
  exit 0
}

main() {
  parse_args "$@"
  parse_manifest
  load_extensions
  HOST="$(detect_host)"
  if [[ -n "$HOST_ARG" ]]; then
    HOST="$HOST_ARG"
  fi

  resolve_selection

  if [[ "$CHECK_MODE" -eq 0 && -n "$COMPONENTS_ARG" && "$YES_MODE" -ne 1 ]]; then
    printf '\nComponents to apply: %s\n' "$(IFS=,; printf '%s' "${APPLY_ORDER[*]}")"
    printf 'This writes files into %s.\n' "$HOME"
    if ! confirm_yesno 'Apply these components now?'; then
      printf 'Aborted. No changes made.\n'
      exit 0
    fi
  fi

  if [[ "$CHECK_MODE" -eq 1 ]]; then
    run_check
  fi
  run_apply
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
