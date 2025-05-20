#!/bin/bash

INTERFACE="wlan0"
WIFI_INFO="$(iwctl station "$INTERFACE" show)"
SSID=$(echo "$WIFI_INFO" | grep 'Connected network' | awk '{print $3}')
RAW_RSSI=$(echo "$WIFI_INFO" | grep 'RSSI' | grep -v 'Average' | awk '{print $2}')

# Log debug info
{
  echo "------ $(date) -----"
  echo "Interface: $INTERFACE"
  echo "SSID: $SSID"
  echo "Raw RSSI: $RAW_RSSI"
} >> ~/.wifi_debug.log

# Validate RSSI
if [[ "$RAW_RSSI" =~ ^-?[0-9]+$ ]]; then
  RSSI=$RAW_RSSI
else
  echo "磌 No Signal"
  echo "RSSI is not valid: $RAW_RSSI" >> ~/.wifi_debug.log
  exit 0
fi

# Determine icon based on RSSI
if (( RSSI >= -50 )); then
  ICON="󰤨"  # Full bars
elif (( RSSI >= -60 )); then
  ICON="󰤥"  # 3 bars
elif (( RSSI >= -70 )); then
  ICON="󰤢"  # 2 bars
elif (( RSSI >= -80 )); then
  ICON="󰤟"   # 1 bar
else
  ICON="󰤯"  # No signal
fi

echo "$ICON $SSID"