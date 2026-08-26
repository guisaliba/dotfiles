# Omarchy

This directory is the customization layer of the user's Omarchy setup: administrator scripts and the system configuration files that they deploy. These files sit outside Omarchy's managed source tree, so `omarchy update` does not replace them. The dotfiles repository exists to reproduce this layer. Clone it on any new Omarchy installation on any device and run the apply scripts to get the same setup.

## Contents

| Path | Type | Purpose |
| --- | --- | --- |
| `apply-power-management.sh` | Script | Installs the clamshell power-management drop-ins from `etc/` into `/etc`. |
| `mx-mini-recover.sh` | Script | Repairs or re-pairs a Logitech MX Mechanical Mini keyboard over Bluetooth. |
| `etc/` | Configuration | System configuration files, mirrored in the target `/etc` layout. |

At the moment, `etc/` serves the power-management script only.

## Clamshell power management

This module configures a laptop used as a clamshell workstation with an external display.

It installs two administrator-owned drop-ins:

- `systemd/logind.conf.d/90-dotfiles-clamshell.conf` prevents a closed lid or logind idle policy from suspending the workstation. Explicit `systemctl suspend` remains available.
- `udev/rules.d/91-dotfiles-bluetooth-wakeup.rules` enables wake on USB Bluetooth controllers. This supports Bluetooth keyboards and mice when the hardware and firmware provide USB wake support.

The `etc/` tree mirrors the target layout under `/etc`. The script copies each file with `install -Dm0644`.

### Apply

From the repository root, run:

```sh
./omarchy/apply-power-management.sh
```

The script elevates itself with `sudo`, reloads systemd and udev configuration, and applies the Bluetooth wake setting to adapters already connected. A reboot is not normally required. Each run reinstalls the same files, so re-runs are safe.

### Verify

```sh
systemd-analyze cat-config systemd/logind.conf
cat /sys/bus/usb/devices/*/power/wakeup
```

The Bluetooth adapter shows `enabled`. On this laptop it is the Realtek `0bda:c829` device at `/sys/bus/usb/devices/1-10`. Other devices have different addresses and bus paths.

This does not make Bluetooth wake possible when the laptop firmware does not support it. The clamshell logind policy is the reliable part: locking with Hyprlock turns off the display but leaves the session running, so Bluetooth input can wake the external display without a suspend-resume cycle.

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

When the final report shows `WakeAllowed: no`, enable wake permission for the device before you rely on wake-from-suspend. The USB-side rule belongs to the power-management module above.

## Reproduce on a new Omarchy installation

1. Clone this repository on the new device.
2. For a laptop clamshell workstation, run `./omarchy/apply-power-management.sh`.
3. For a stuck MX keyboard, run `./omarchy/mx-mini-recover.sh`.
4. Add future system-level tweaks as scripts in this directory. Mirror each target path under `etc/` and let the apply script install it.

Example values such as the Realtek vendor id and bus path describe this laptop. Read the output on a new device and adjust where necessary.
