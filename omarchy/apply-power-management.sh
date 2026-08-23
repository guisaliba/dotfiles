#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOGIND_DROPIN="$SCRIPT_DIR/etc/systemd/logind.conf.d/90-dotfiles-clamshell.conf"
BLUETOOTH_RULE="$SCRIPT_DIR/etc/udev/rules.d/91-dotfiles-bluetooth-wakeup.rules"

if (( EUID != 0 )); then
    if ! command -v sudo >/dev/null 2>&1; then
        printf '%s\n' 'ERROR: sudo is required to install system power-management files.' >&2
        exit 1
    fi
    exec sudo -- "$0" "$@"
fi

install -Dm0644 "$LOGIND_DROPIN" /etc/systemd/logind.conf.d/90-dotfiles-clamshell.conf
install -Dm0644 "$BLUETOOTH_RULE" /etc/udev/rules.d/91-dotfiles-bluetooth-wakeup.rules

udevadm control --reload-rules

enabled_count=0
shopt -s nullglob
for device in /sys/bus/usb/devices/*; do
    [[ -r "$device/bDeviceClass" ]] || continue
    [[ -r "$device/bDeviceSubClass" ]] || continue
    [[ -r "$device/bDeviceProtocol" ]] || continue
    [[ -w "$device/power/wakeup" ]] || continue

    [[ $(<"$device/bDeviceClass") == e0 ]] || continue
    [[ $(<"$device/bDeviceSubClass") == 01 ]] || continue
    [[ $(<"$device/bDeviceProtocol") == 01 ]] || continue

    printf '%s\n' enabled >"$device/power/wakeup"
    printf 'Enabled Bluetooth wake: %s\n' "$device"
    ((enabled_count += 1))
done

systemctl reload systemd-logind.service

if (( enabled_count == 0 )); then
    printf '%s\n' 'WARNING: no USB Bluetooth controller was found; the udev rule is installed.' >&2
fi

printf '%s\n' 'Installed clamshell power-management drop-ins.'
