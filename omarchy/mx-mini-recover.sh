#!/usr/bin/env bash

set -Eeuo pipefail

readonly DEVICE_NAME_PATTERN='MX MCHNCL M|MX Mechanical Mini'
readonly SCAN_SECONDS=15
readonly PAIR_SECONDS=90

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

valid_address() {
  [[ $1 =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
}

device_info() {
  bluetoothctl info "$1" 2>/dev/null || true
}

device_has_state() {
  local address=$1
  local state=$2
  device_info "$address" | grep -Eq "^[[:space:]]*${state}:[[:space:]]+yes$"
}

find_addresses() {
  bluetoothctl devices 2>/dev/null | awk -v pattern="$DEVICE_NAME_PATTERN" '
    BEGIN { IGNORECASE = 1 }
    $1 == "Device" {
      address = $2
      $1 = ""
      $2 = ""
      sub(/^[[:space:]]+/, "")
      if ($0 ~ pattern) print address
    }
  ' | sort -u
}

select_address() {
  local supplied_address=${1:-}
  local -a addresses=()
  local selection

  if [[ -n $supplied_address ]]; then
    valid_address "$supplied_address" || fail "Invalid Bluetooth address: $supplied_address"
    printf '%s\n' "${supplied_address^^}"
    return
  fi

  mapfile -t addresses < <(find_addresses)

  case ${#addresses[@]} in
    0)
      return 1
      ;;
    1)
      printf '%s\n' "${addresses[0]}"
      ;;
    *)
      printf 'More than one MX keyboard was found:\n' >&2
      local index
      for index in "${!addresses[@]}"; do
        printf '  %d) %s\n' "$((index + 1))" "${addresses[index]}" >&2
      done
      read -r -p 'Select a device number: ' selection
      [[ $selection =~ ^[0-9]+$ ]] || fail 'The selection is not a number.'
      ((selection >= 1 && selection <= ${#addresses[@]})) || fail 'The selection is outside the list.'
      printf '%s\n' "${addresses[selection - 1]}"
      ;;
  esac
}

show_result() {
  local address=$1
  local info
  info=$(device_info "$address")

  printf '\nFinal device state:\n'
  grep -E '^[[:space:]]*(Name|Alias|Paired|Bonded|Trusted|Connected|WakeAllowed):' <<<"$info" || true

  local state
  for state in Paired Bonded Trusted Connected; do
    grep -Eq "^[[:space:]]*${state}:[[:space:]]+yes$" <<<"$info" || return 1
  done
}

require_command bluetoothctl

bluetoothctl power on >/dev/null || fail 'Could not power on the Bluetooth controller.'

address=$(select_address "${1:-}" || true)

if [[ -n $address ]] && device_has_state "$address" Connected; then
  printf 'The MX keyboard is already connected: %s\n' "$address"
  show_result "$address"
  exit 0
fi

if [[ -n $address ]] && device_has_state "$address" Paired; then
  printf 'Found the paired MX keyboard: %s\n' "$address"
  printf 'Trying a normal connection before a new pairing...\n'
  bluetoothctl --timeout 5 scan on >/dev/null 2>&1 || true
  bluetoothctl --timeout 20 connect "$address" || true
  bluetoothctl scan off >/dev/null 2>&1 || true

  if device_has_state "$address" Connected; then
    bluetoothctl trust "$address" >/dev/null || true
    show_result "$address"
    exit 0
  fi
fi

printf '\nA new pairing is necessary.\n'
printf 'Hold the selected Easy-Switch key for about three seconds.\n'
printf 'Continue only when its LED flashes quickly.\n'
read -r -p 'Press Enter on the laptop keyboard to start the scan... '

printf 'Scanning for the MX keyboard for %d seconds...\n' "$SCAN_SECONDS"
bluetoothctl --timeout "$SCAN_SECONDS" scan on || true
bluetoothctl scan off >/dev/null 2>&1 || true

address=$(select_address "${1:-}" || true)
[[ -n $address ]] || fail 'The MX keyboard was not found. Put it in pairing mode and run the script again.'

printf '\nPairing with %s.\n' "$address"
printf 'When a passkey appears, type it on the MX keyboard and press Enter on that keyboard.\n\n'

# Keep bluetoothctl in the foreground. Its KeyboardDisplay agent must show the
# passkey that the keyboard user must type.
bluetoothctl --agent KeyboardDisplay --timeout "$PAIR_SECONDS" pair "$address" || \
  fail 'Pairing failed. Put the keyboard in pairing mode and run the script again.'

# Current bluetoothctl versions trust and connect as part of `pair`. Keep these
# commands as idempotent checks for older versions and partial results.
bluetoothctl trust "$address" >/dev/null || fail 'Pairing worked, but the trust operation failed.'

if ! device_has_state "$address" Connected; then
  bluetoothctl --timeout "$SCAN_SECONDS" scan on >/dev/null 2>&1 || true
  bluetoothctl --timeout 20 connect "$address" || fail 'Pairing worked, but the connection failed.'
  bluetoothctl scan off >/dev/null 2>&1 || true
fi

show_result "$address" || fail 'The keyboard does not have all required states.'

if ! device_has_state "$address" WakeAllowed; then
  printf '\nWarning: WakeAllowed is not yes. Run your wake-permission setup script.\n' >&2
fi

printf '\nThe MX keyboard is paired, bonded, trusted, and connected.\n'
