#!/usr/bin/env bash

BAT_PATH="/sys/class/power_supply/BAT0"
[ ! -d "$BAT_PATH" ] && echo "No battery" && exit

capacity=$(cat "$BAT_PATH/capacity")
status=$(cat "$BAT_PATH/status")

label="  ${capacity}%"

# Color logic
if [ "$capacity" -lt 20 ]; then
    color="#ff5555"
elif [ "$capacity" -lt 50 ]; then
    color="#f1fa8c"
else
    color="#ffffff"
fi

# Output for i3bar (3 lines: full_text, short_text, color)
echo "$label"
echo "$label"
echo "$color"


