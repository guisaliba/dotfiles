#!/bin/bash

set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
controller="$script_dir/bin/omarchy-cliamp-screensaver"
hypridle_config="$script_dir/config/hypr/hypridle.conf"
rules_config="$script_dir/config/hypr/cliamp-screensaver.conf"
test_root=$(mktemp -d)

cleanup() {
  rm -rf "$test_root"
}

trap cleanup EXIT

test_apply() {
  local fixture_home="$test_root/home"
  local fake_bin="$test_root/bin"
  local command_log="$test_root/commands.log"
  local apply_log="$test_root/apply.log"
  local source_line='source = ~/.config/hypr/cliamp-screensaver.conf'
  local command_name

  mkdir -p \
    "$fake_bin" \
    "$fixture_home/.config/hypr" \
    "$fixture_home/.local/share/omarchy/default/alacritty"
  printf '%s\n' '# fixture Hyprland configuration' >"$fixture_home/.config/hypr/hyprland.conf"
  printf '%s\n' '# previous idle configuration' >"$fixture_home/.config/hypr/hypridle.conf"
  : >"$fixture_home/.local/share/omarchy/default/alacritty/screensaver.toml"

  cat >"$fake_bin/omarchy" <<'EOF'
#!/bin/bash
if [[ ${1:-} == "version" ]]; then
  printf '%s\n' "${FAKE_OMARCHY_VERSION:-3.8.4}"
else
  printf 'omarchy %s\n' "$*" >>"$COMMAND_LOG"
fi
EOF

  cat >"$fake_bin/hyprctl" <<'EOF'
#!/bin/bash
printf 'hyprctl %s\n' "$*" >>"$COMMAND_LOG"
EOF

  chmod +x "$fake_bin/omarchy" "$fake_bin/hyprctl"
  for command_name in alacritty cliamp hypridle hyprlock tte uwsm-app; do
    cat >"$fake_bin/$command_name" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$fake_bin/$command_name"
    [[ $(PATH="$fake_bin" command -v "$command_name") == "$fake_bin/$command_name" ]]
  done

  HOME="$fixture_home" \
    PATH="$fake_bin:$PATH" \
    COMMAND_LOG="$command_log" \
    OMARCHY_PROFILE_SKIP_TESTS=1 \
    "$script_dir/apply.sh" >"$apply_log"

  cmp -s "$controller" "$fixture_home/.local/bin/omarchy-cliamp-screensaver"
  cmp -s "$hypridle_config" "$fixture_home/.config/hypr/hypridle.conf"
  cmp -s "$rules_config" "$fixture_home/.config/hypr/cliamp-screensaver.conf"
  [[ $(grep -Fxc "$source_line" "$fixture_home/.config/hypr/hyprland.conf") == "1" ]]
  grep -Fqx 'omarchy restart hypridle' "$command_log"

  HOME="$fixture_home" \
    PATH="$fake_bin:$PATH" \
    COMMAND_LOG="$command_log" \
    OMARCHY_PROFILE_SKIP_TESTS=1 \
    "$script_dir/apply.sh" >"$apply_log"
  [[ $(grep -Fxc "$source_line" "$fixture_home/.config/hypr/hyprland.conf") == "1" ]]

  if HOME="$fixture_home" \
    PATH="$fake_bin:$PATH" \
    COMMAND_LOG="$command_log" \
    FAKE_OMARCHY_VERSION=4.0.0 \
    OMARCHY_PROFILE_SKIP_TESTS=1 \
    "$script_dir/apply.sh" >"$apply_log" 2>&1; then
    return 1
  fi
  grep -Fq 'This profile supports Omarchy 3 only' "$apply_log"
}

bash -n "$script_dir/apply.sh" "$controller" "$script_dir/tests/cliamp-screensaver-test.sh"

CONTROLLER="$controller" \
  HYPRIDLE_CONFIG="$hypridle_config" \
  "$script_dir/tests/cliamp-screensaver-test.sh"

grep -Fqx '    timeout = 300' "$hypridle_config"
grep -Fqx '    timeout = 302' "$hypridle_config"
grep -Fqx 'windowrule = opacity 0 0, match:class org.omarchy.screensaver, match:title ^Cliamp Input Shield:.*$' "$rules_config"
grep -Fqx 'windowrule = fullscreen on, match:class org.omarchy.cliamp-blackout' "$rules_config"

test_apply

printf 'omarchy profile tests passed\n'
