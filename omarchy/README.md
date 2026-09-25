# Omarchy

This directory contains user-managed Omarchy customizations. The dotfiles repository reproduces them on new installations.

## Contents

| Path | Type | Purpose |
| --- | --- | --- |
| `mx-mini-recover.sh` | Script | Repairs or re-pairs a Logitech MX Mechanical Mini keyboard over Bluetooth. |
| `display-plugin/` | Plugin | Enhances the built-in Display widget with layout and rotation controls. |
| `install-display.py` | Installer | Installs the local plugin after an upstream compatibility check. |

## Display layout enhancement

This is a **clone enhancement** of `omarchy.monitor`, the packaged Display bar widget in Omarchy 4. The tracked manifest gives it a distinct user id, `guisaliba.monitor`, and declares `omarchy.clonedFrom = "omarchy.monitor"`. Omarchy keeps the built-in plugin installed. The plugin registry routes built-in bar and shortcut calls to the enabled clone; disabling the clone and putting `omarchy.monitor` back in the bar returns to the native widget. This design keeps the familiar Display actions while adding **Edit** for position and orientation. It is also the intended starting point for a later public marketplace plugin, after local use and revision.

With two active screens, choose an output and reference, then choose left, right, above, or below and one of 0°, 90°, 180°, or 270°. For one active screen, Edit can rotate it without a reference. Placement aligns top edges for left/right and left edges for above/below. An overlapping placement is rejected. **Try layout** changes the live display for 20 seconds; **Keep changes** writes a connector rule to the marked section of `~/.config/hypr/monitors.lua`. **Revert**, timeout, or disconnection restores a verified baseline. A new connector uses Omarchy defaults until you choose a layout for it. The helper refuses hand-written conflicting connector rules instead of overwriting them. The existing brightness, text size, scale, enable/disable, pointer, keyboard, and IPC actions remain available.

### Install and verify

On Omarchy 4, from the repository root:

```sh
./install.sh --check --components omarchy-display
./install.sh --components omarchy-display --yes
python3 -B omarchy/test-display.py
omarchy plugin validate omarchy/display-plugin
hyprctl monitors all -j
hyprctl configerrors
```

`--check` performs no writes. Apply backs up the bar configuration and any managed plugin tree it replaces under `~/.local/state/dotfiles/backups/`. It refuses an unmanaged plugin path or local edits in an installed copy. A repeated apply with matching sources makes no material change. The user plugin lives under `~/.config/omarchy/plugins/guisaliba.monitor/`, outside the packaged `/usr/share/omarchy/shell/plugins/` tree. Omarchy's native clone command uses the user plugin directory (`/usr/share/omarchy/bin/omarchy-plugin-clone:82–89,131–159`); the registry scans first-party and user plugins separately (`/usr/share/omarchy/shell/services/PluginRegistry.qml:576–640`). Normal package updates do not write this plugin directory. **Compatibility is not guaranteed:** an upstream update can change the native widget contract. The installer checks pinned packaged file digests from `display-upstream.sha256` and refuses to activate a clone against an unreviewed contract. If an installed contract differs, a repeat apply restores the native bar entry and keeps the local plugin files for review. An automatic Omarchy update does not run this installer, so check compatibility after an update; an incompatible active clone can fail until you restore the native bar entry. Review upstream changes, update the clone and checksums together, and run the checks again. `omarchy refresh shell` explicitly replaces `shell.json` and bar defaults; re-run the component to activate the clone after that reset (`/usr/share/omarchy/bin/omarchy-refresh-shell:8–11`). Other Omarchy plugins and OS files are not installation targets.

To return to the native widget, use `omarchy plugin enable omarchy.monitor` or replace `guisaliba.monitor` with `omarchy.monitor` in the bar layout and let the shell reload. The clone can remain installed. This does not delete your confirmed monitor rules; remove only the marked Display layout block from `~/.config/hypr/monitors.lua` if you want Omarchy's default display layout. Keep the `monitors.lua.bak.display.<id>` backups until you have verified the restored layout. For recovery from a terminal when the panel is unavailable, run `python3 ~/.config/omarchy/plugins/guisaliba.monitor/layout.py revert` during a pending trial, or use `hyprctl eval 'hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1, transform = 0 })'` with your **currently connected** output name. Confirm with `hyprctl monitors all -j` and `hyprctl configerrors` before you save any rule.

The old `omarchy-power` installer component and its logind/udev drop-ins were retired for Omarchy 4. This component does not reapply them.

## MX Mechanical Mini keyboard recovery

`mx-mini-recover.sh` restores the Bluetooth connection to an MX Mechanical Mini keyboard when a normal `bluetoothctl connect` is not enough. Use cases: the keyboard stopped connecting, the pairing keys went stale, or the host changed. Follow the interactive prompts. Do not run this script with `sudo`; it works as your regular user.

Requirements: an installed `bluetoothctl` from BlueZ and a powered controller.

### Run

From the repository root:

```sh
./omarchy/mx-mini-recover.sh                     # automatic address selection
./omarchy/mx-mini-recover.sh AA:BB:CC:DD:EE:FF   # explicit keyboard address
```

### Flow

1. The script powers on the Bluetooth controller and searches the known devices for names `MX MCHNCL M` or `MX Mechanical Mini`.
2. It takes the address from the argument, picks the single match automatically, or asks you to select one when several match.
3. The keyboard is already connected: the script prints the device state and exits.
4. The keyboard is paired but offline: the script scans briefly, connects, sets trust, and exits on success.
5. A new pairing is necessary: the script asks you to hold an Easy-Switch key for about three seconds, continue only when the LED flashes quickly, press Enter, and then it scans for 15 seconds.
6. The pairing runs in the foreground with the `KeyboardDisplay` agent. A passkey appears; type it on the MX keyboard and press Enter on that keyboard. The script waits up to 90 seconds.
7. The script applies trust, connects if necessary, and prints the final state.

The script returns a non-zero status and a stderr message on every failure. Success means all of `Paired`, `Bonded`, `Trusted`, and `Connected` show `yes`.

When the final report shows `WakeAllowed: no`, check the device's wake permission before you rely on wake-from-suspend.

## Reproduce on a new Omarchy installation

1. Clone this repository on the new device.
2. For a stuck MX keyboard, run `./omarchy/mx-mini-recover.sh`.
