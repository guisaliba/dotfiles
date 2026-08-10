# Omarchy 3 Cliamp Screensaver

This profile reproduces the Cliamp idle screensaver setup on Omarchy 3.

It is tested with Omarchy 3.8.3 and is compatible with the stable 3.8.4 release. The installer rejects Omarchy Quattro because Quattro replaces Hypridle, Hyprlock, and legacy Hyprland configuration with Omarchy Shell and Lua configuration.

## Behavior

- After 300 seconds of inactivity, a running Cliamp TUI moves to the physically largest monitor and becomes fullscreen.
- Other monitors show fullscreen Alacritty surfaces with pure-black pixels.
- If no valid Cliamp TUI exists, the stock Omarchy screensaver starts on every monitor.
- Keyboard or pointer activity restores the previous monitor, workspace, fullscreen, cursor, and focus state.
- The automatic lock starts approximately 10 minutes after the original activity. The second listener uses 302 seconds because screensaver startup resets Hypridle.
- Explicit and automatic locks continue to use Hyprlock and require authentication.

## Compatibility

Required commands:

```text
alacritty
cliamp
flock
hyprctl
hypridle
hyprlock
jq
setsid
stat
tte
uwsm-app
```

The setup does not use fixed monitor names. It selects a monitor from live Hyprland data. Physical dimensions have priority, pixel dimensions resolve missing data, and the focused monitor resolves a tie.

Do not apply this profile to Quattro. A separate Quattro adapter must use `~/.config/omarchy/shell.json`, Lua window rules, `ttfx`, and Omarchy Shell lock detection.

## Files

- `bin/omarchy-cliamp-screensaver`: stateful screensaver controller.
- `config/hypr/hypridle.conf`: managed idle and lock configuration.
- `config/hypr/cliamp-screensaver.conf`: window rules sourced by the main Hyprland configuration.
- `tests/cliamp-screensaver-test.sh`: controller regression tests.
- `tests/hypridle-cliamp-diagnostic.conf`: short natural-idle diagnostic configuration.

The apply script manages the complete `~/.config/hypr/hypridle.conf` file. It adds one source line to `~/.config/hypr/hyprland.conf`. Changed files are backed up under `~/.local/state/dotfiles-backups/omarchy-cliamp-screensaver/`.

## Apply

```sh
cd ~/dotfiles
./omarchy/apply.sh
```

The script checks compatibility and prerequisites, runs tests, installs the files, reloads Hyprland, validates its configuration, and restarts Hypridle.

## Test

```sh
cd ~/dotfiles
./omarchy/test.sh
```

The test does not start the live screensaver or lock the device.
