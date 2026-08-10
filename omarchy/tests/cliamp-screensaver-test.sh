#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
controller=${CONTROLLER:-"$script_dir/../bin/omarchy-cliamp-screensaver"}
hypridle_config=${HYPRIDLE_CONFIG:-"$script_dir/../config/hypr/hypridle.conf"}
test_root=$(mktemp -d)

cleanup() {
  rm -rf "$test_root"
}

trap cleanup EXIT

select_monitor() {
  local focused=$1
  local monitors=$2

  printf '%s' "$monitors" | "$controller" select-monitor "$focused"
}

physically_largest='[
  {"name":"internal","width":2560,"height":1600,"physicalWidth":300,"physicalHeight":190},
  {"name":"external","width":1920,"height":1080,"physicalWidth":530,"physicalHeight":300}
]'
[[ $(select_monitor internal "$physically_largest") == "external" ]]

higher_resolution='[
  {"name":"low-dpi","width":1920,"height":1080,"physicalWidth":530,"physicalHeight":300},
  {"name":"high-dpi","width":3840,"height":2160,"physicalWidth":530,"physicalHeight":300}
]'
[[ $(select_monitor low-dpi "$higher_resolution") == "high-dpi" ]]

equal_monitors='[
  {"name":"left","width":1920,"height":1080,"physicalWidth":530,"physicalHeight":300},
  {"name":"right","width":1920,"height":1080,"physicalWidth":530,"physicalHeight":300}
]'
[[ $(select_monitor right "$equal_monitors") == "right" ]]

missing_physical_size='[
  {"name":"small","width":1920,"height":1080,"physicalWidth":0,"physicalHeight":0},
  {"name":"large","width":2560,"height":1440,"physicalWidth":0,"physicalHeight":0}
]'
[[ $(select_monitor small "$missing_physical_size") == "large" ]]

mixed_physical_size='[
  {"name":"measured-laptop","width":2560,"height":1600,"physicalWidth":300,"physicalHeight":190},
  {"name":"unmeasured-4k","width":3840,"height":2160,"physicalWidth":0,"physicalHeight":0}
]'
[[ $(select_monitor measured-laptop "$mixed_physical_size") == "unmeasured-4k" ]]

fake_bin="$test_root/bin"
fake_home="$test_root/home"
fake_runtime="$test_root/runtime"
command_log="$test_root/commands.log"
clients_file="$test_root/clients.json"
mkdir -p "$fake_bin" "$fake_home/.config/cliamp" "$fake_runtime"
printf '[]\n' >"$clients_file"

cat >"$fake_bin/hyprctl" <<'EOF'
#!/bin/bash
printf 'hyprctl %s\n' "$*" >>"$COMMAND_LOG"
case "$*" in
"-j clients") cat "$FAKE_CLIENTS_FILE" ;;
"-j monitors"|"-j workspaces") printf '[]\n' ;;
"-j activewindow") printf '{}\n' ;;
"getoption cursor:invisible -j") printf '{"int":0}\n' ;;
*) printf 'ok\n' ;;
esac
EOF

cat >"$fake_bin/pkill" <<'EOF'
#!/bin/bash
printf 'pkill %s\n' "$*" >>"$COMMAND_LOG"
EOF

chmod +x "$fake_bin/hyprctl" "$fake_bin/pkill"

run_isolated() {
  env \
    HOME="$fake_home" \
    XDG_RUNTIME_DIR="$fake_runtime" \
    COMMAND_LOG="$command_log" \
    FAKE_CLIENTS_FILE="$clients_file" \
    PATH="$fake_bin:$PATH" \
    "$controller" "$@"
}

# A resume event without an active run must not mutate global cursor or window state.
: >"$command_log"
run_isolated stop
[[ ! -s $command_log ]]

# A delayed stop from an old shield must not restore or remove a newer run.
state_dir="$fake_runtime/omarchy-cliamp-screensaver-$UID"
mkdir -p "$state_dir"
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "new-run",
  "mode": "fallback",
  "owned_windows": [],
  "cursor_invisible": 0,
  "monitor_names": []
}
EOF
: >"$command_log"
run_isolated stop old-run
[[ -s $state_dir/state.json ]]
[[ ! -s $command_log ]]

# Cleanup must close only a recorded window whose live PID and class still match.
cat >"$clients_file" <<'EOF'
[
  {
    "address": "0xabc",
    "pid": 400,
    "class": "org.omarchy.screensaver",
    "title": "Omarchy Screensaver:new-run:eDP-1"
  },
  {
    "address": "0xprotected",
    "pid": 1750898,
    "class": "Alacritty",
    "title": "Protected Session"
  }
]
EOF
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "new-run",
  "mode": "fallback",
  "owned_windows": [
    {
      "address": "0xabc",
      "pid": 400,
      "class": "org.omarchy.screensaver",
      "title": "Omarchy Screensaver:new-run:eDP-1"
    }
  ],
  "cursor_invisible": 0,
  "monitor_names": []
}
EOF
: >"$command_log"
run_isolated stop new-run
grep -Fq 'hyprctl dispatch closewindow address:0xabc' "$command_log"
! grep -Fq 'pkill ' "$command_log"
! grep -Fq '0xprotected' "$command_log"
[[ ! -e $state_dir/state.json ]]

# A reused address with a different PID and class must not be closed.
cat >"$clients_file" <<'EOF'
[
  {
    "address": "0xabc",
    "pid": 1750898,
    "class": "Alacritty",
    "title": "Protected Session"
  }
]
EOF
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "reused-address",
  "mode": "fallback",
  "owned_windows": [
    {
      "address": "0xabc",
      "pid": 400,
      "class": "org.omarchy.screensaver",
      "title": "Omarchy Screensaver:reused-address:eDP-1"
    }
  ],
  "cursor_invisible": 0,
  "monitor_names": []
}
EOF
: >"$command_log"
run_isolated stop reused-address
! grep -Fq 'closewindow' "$command_log"
! grep -Fq '1750898' "$command_log"

# Invalid state is quarantined without an unsafe compositor operation.
printf '{invalid\n' >"$state_dir/state.json"
: >"$command_log"
run_isolated stop
[[ ! -e $state_dir/state.json ]]
compgen -G "$state_dir/state.invalid.*" >/dev/null
[[ ! -s $command_log ]]

# Runtime state is private.
[[ $(stat -c '%a' "$state_dir") == "700" ]]

# A changed monitor set ends the old run without using stale monitor IDs.
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "hotplug-run",
  "mode": "fallback",
  "owned_windows": [],
  "cursor_invisible": 0,
  "monitor_names": ["HDMI-A-1", "eDP-1"]
}
EOF
: >"$command_log"
run_isolated monitor-watch hotplug-run '["HDMI-A-1","eDP-1"]'
[[ ! -e $state_dir/state.json ]]
! grep -Fq '1750898' "$command_log"

# A symbolic-link runtime path is rejected before commands or state are used.
link_runtime="$test_root/link-runtime"
link_target="$test_root/link-target"
mkdir -p "$link_runtime" "$link_target"
ln -s "$link_target" "$link_runtime/omarchy-cliamp-screensaver-$UID"
: >"$command_log"
if env \
  HOME="$fake_home" \
  XDG_RUNTIME_DIR="$link_runtime" \
  COMMAND_LOG="$command_log" \
  FAKE_CLIENTS_FILE="$clients_file" \
  PATH="$fake_bin:$PATH" \
  "$controller" stop 2>/dev/null; then
  exit 1
fi
[[ ! -s $command_log ]]

# Terminal resize signals and a temporary read failure must not end the input shield.
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "shield-run",
  "mode": "fallback",
  "owned_windows": [],
  "cursor_invisible": 0,
  "monitor_names": []
}
EOF
shield_output="$test_root/shield.out"
touch "$state_dir/armed"
env \
  HOME="$fake_home" \
  XDG_RUNTIME_DIR="$fake_runtime" \
  COMMAND_LOG="$command_log" \
  FAKE_CLIENTS_FILE="$clients_file" \
  PATH="$fake_bin:$PATH" \
  "$controller" shield shield-run </dev/null >"$shield_output" 2>/dev/null &
shield_pid=$!
sleep 0.1
kill -0 "$shield_pid"
grep -Fq $'\033[?1003h' "$shield_output"
grep -Fq $'\033[?1006h' "$shield_output"
kill -WINCH "$shield_pid"
sleep 0.1
kill -0 "$shield_pid"
kill -TERM "$shield_pid"
wait "$shield_pid" || true
[[ ! -e $state_dir/state.json ]]

# A blackout surface stays alive, tracks pointer input, and cleans up its run on exit.
rm -f "$state_dir"/state.invalid.*
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "blackout-run",
  "mode": "fallback",
  "owned_windows": [],
  "cursor_invisible": 0,
  "monitor_names": []
}
EOF
blackout_output="$test_root/blackout.out"
touch "$state_dir/armed"
set +e
timeout 0.2 env \
  HOME="$fake_home" \
  XDG_RUNTIME_DIR="$fake_runtime" \
  COMMAND_LOG="$command_log" \
  FAKE_CLIENTS_FILE="$clients_file" \
  PATH="$fake_bin:$PATH" \
  "$controller" blackout blackout-run >"$blackout_output" 2>/dev/null
blackout_status=$?
set -e
[[ $blackout_status -eq 124 ]]
grep -Fq $'\033[?1003h' "$blackout_output"
grep -Fq $'\033[?1006h' "$blackout_output"
[[ ! -e $state_dir/state.json ]]

# Resume events generated before arming must not stop a run; later input must stop it.
cat >"$state_dir/state.json" <<'EOF'
{
  "version": 2,
  "run_id": "resume-run",
  "mode": "fallback",
  "owned_windows": [],
  "cursor_invisible": 0,
  "monitor_names": []
}
EOF
printf '200\n' >"$state_dir/armed"
run_isolated resume 100
[[ -s $state_dir/state.json ]]
run_isolated resume 300
[[ ! -e $state_dir/state.json ]]

# Lock must not depend on successful restoration.
grep -Fq 'on-timeout = ~/.local/bin/omarchy-cliamp-screensaver stop; omarchy-system-lock' "$hypridle_config"

# Startup-generated resume events must use the arming gate instead of unconditional cleanup.
! grep -Fq 'on-resume = sleep 0.2 && ~/.local/bin/omarchy-cliamp-screensaver stop' "$hypridle_config"
grep -Fq 'on-resume = ~/.local/bin/omarchy-cliamp-screensaver resume "$(date +%s%N)"' "$hypridle_config"

printf 'cliamp screensaver tests passed\n'
