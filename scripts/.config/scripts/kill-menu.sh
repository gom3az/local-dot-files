#!/usr/bin/env bash
set -euo pipefail

selection=$(ps -u "$USER" -o pid,comm,%cpu,%mem --no-headers |
    rofi -dmenu -i -l 15 -p "Kill:" -theme-str 'window {width: 50%;} listview {lines: 15;}' |
    awk '{print $1}')

[[ -z "$selection" ]] && exit 0

kill "$selection" 2>/dev/null && notify-send -a "Kill" "Killed" "$(ps -p "$selection" -o comm= 2>/dev/null || echo "process $selection")" || notify-send -a "Kill" "Failed" "Could not kill process $selection"
