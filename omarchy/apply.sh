#!/bin/bash

set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
backup_root="$HOME/.local/state/dotfiles-backups/omarchy-cliamp-screensaver"
backup_dir="$backup_root/$(date +%Y%m%d%H%M%S)"
hyprland_config="$HOME/.config/hypr/hyprland.conf"
hypridle_config="$HOME/.config/hypr/hypridle.conf"
rules_config="$HOME/.config/hypr/cliamp-screensaver.conf"
controller="$HOME/.local/bin/omarchy-cliamp-screensaver"
source_line='source = ~/.config/hypr/cliamp-screensaver.conf'

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

backup_file() {
  local target=$1
  local relative
  local destination

  [[ -e $target ]] || return 0
  relative=${target#"$HOME"/}
  destination="$backup_dir/$relative"
  mkdir -p "$(dirname "$destination")"
  cp -a "$target" "$destination"
}

check_compatibility() {
  local version
  local major

  require_command omarchy
  version=$(omarchy version)
  major=${version%%.*}
  [[ $major == "3" ]] || die "This profile supports Omarchy 3 only. Detected version: $version"
  [[ ! -f $HOME/.config/hypr/hyprland.lua ]] || die "Quattro Lua configuration detected. This Omarchy 3 profile was not applied."
  [[ -f $hyprland_config ]] || die "Missing legacy Hyprland configuration: $hyprland_config"
  [[ -f $HOME/.local/share/omarchy/default/alacritty/screensaver.toml ]] || die "Missing Omarchy 3 Alacritty screensaver configuration."

  for command_name in alacritty cliamp flock hyprctl hypridle hyprlock jq setsid stat tte uwsm-app; do
    require_command "$command_name"
  done
}

install_profile() {
  log "Installing Omarchy 3 cliamp screensaver profile"

  mkdir -p "$HOME/.local/bin" "$HOME/.config/hypr"

  if [[ ! -f $controller ]] || ! cmp -s "$script_dir/bin/omarchy-cliamp-screensaver" "$controller"; then
    backup_file "$controller"
    install -m 0755 "$script_dir/bin/omarchy-cliamp-screensaver" "$controller"
  fi

  if [[ ! -f $rules_config ]] || ! cmp -s "$script_dir/config/hypr/cliamp-screensaver.conf" "$rules_config"; then
    backup_file "$rules_config"
    install -m 0644 "$script_dir/config/hypr/cliamp-screensaver.conf" "$rules_config"
  fi

  if [[ ! -f $hypridle_config ]] || ! cmp -s "$script_dir/config/hypr/hypridle.conf" "$hypridle_config"; then
    backup_file "$hypridle_config"
    install -m 0644 "$script_dir/config/hypr/hypridle.conf" "$hypridle_config"
  fi

  if ! grep -Fqx "$source_line" "$hyprland_config"; then
    backup_file "$hyprland_config"
    printf '\n# Cliamp screensaver profile\n%s\n' "$source_line" >>"$hyprland_config"
  fi
}

apply_runtime() {
  local config_errors

  log "Reloading Hyprland and Hypridle"
  hyprctl reload >/dev/null
  config_errors=$(hyprctl configerrors)
  if [[ -n $config_errors ]]; then
    printf '\nERROR: Hyprland configuration errors:\n%s\n' "$config_errors" >&2
    exit 1
  fi
  omarchy restart hypridle
}

main() {
  check_compatibility
  if [[ ${OMARCHY_PROFILE_SKIP_TESTS:-0} != "1" ]]; then
    "$script_dir/test.sh"
  fi
  install_profile
  apply_runtime
  log "Omarchy 3 cliamp screensaver profile applied"
  [[ -d $backup_dir ]] && printf 'Backups: %s\n' "$backup_dir"
}

main "$@"
