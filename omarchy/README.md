# Omarchy Power Management

This module configures a laptop used as a clamshell workstation with an external display.

It installs two administrator-owned drop-ins:

- `systemd/logind.conf.d/90-dotfiles-clamshell.conf` prevents a closed lid or logind idle policy from suspending the workstation. Explicit `systemctl suspend` remains available.
- `udev/rules.d/91-dotfiles-bluetooth-wakeup.rules` enables wake on USB Bluetooth controllers. This supports Bluetooth keyboards and mice when the hardware and firmware provide USB wake support.

The files are outside Omarchy's managed source tree, so `omarchy update` does not replace them.

## Apply

From the repository root, run:

```sh
./omarchy/apply-power-management.sh
```

The script reloads systemd and udev configuration and applies the Bluetooth wake setting to adapters already connected. A reboot is not normally required.

## Verify

```sh
systemd-analyze cat-config systemd/logind.conf
cat /sys/bus/usb/devices/*/power/wakeup
```

The Bluetooth adapter should show `enabled`. On this laptop it is the Realtek `0bda:c829` device at `/sys/bus/usb/devices/1-10`.

This does not make Bluetooth wake possible when the laptop firmware does not support it. The clamshell logind policy is the reliable part: locking with Hyprlock turns off the display but leaves the session running, so Bluetooth input can wake the external display without a suspend-resume cycle.
