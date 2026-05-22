#!/bin/bash

theme_dir="$HOME/.config/rofi"
save_dir="$HOME/Pictures/Screenshots"
mkdir -p "$save_dir"

entries=(
    "󰆞  Area Screenshot"
    "🖥  Full Screenshot"
    "  Window Screenshot"
    "󰕧  Area Recording"
    "󰕧  Area Recording + Audio"
    "🖥  Full Recording"
    "🖥  Full Recording + Audio"
)

choice=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -theme "${theme_dir}/screenshot.rasi" -p "Capture")
[ -z "$choice" ] && exit 0

timestamp=$(date +%Y-%m-%d_%H-%M-%S)

case "$choice" in
    "󰆞  Area Screenshot")
        filepath="${save_dir}/Screenshot-${timestamp}.png"
        geometry=$(slurp) || exit 0
        grim -g "$geometry" "$filepath"
        wl-copy < "$filepath"
        notify-send "Screenshot saved" "${filepath}"
        ;;
    "🖥  Full Screenshot")
        filepath="${save_dir}/Screenshot-${timestamp}.png"
        grim "$filepath"
        wl-copy < "$filepath"
        notify-send "Screenshot saved" "${filepath}"
        ;;
    "  Window Screenshot")
        filepath="${save_dir}/Screenshot-${timestamp}.png"
        grim -g "$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$filepath"
        wl-copy < "$filepath"
        notify-send "Screenshot saved" "${filepath}"
        ;;
    "󰕧  Area Recording")
        filepath="${save_dir}/Recording-${timestamp}.mp4"
        geometry=$(slurp) || exit 0
        wf-recorder -g "$geometry" -f "$filepath" &
        notify-send "Recording started" "${filepath}"
        ;;
    "󰕧  Area Recording + Audio")
        filepath="${save_dir}/Recording-${timestamp}.mp4"
        geometry=$(slurp) || exit 0
        wf-recorder -g "$geometry" --audio-backend=pipewire -a -f "$filepath" &
        notify-send "Recording started" "${filepath}"
        ;;
    "🖥  Full Recording")
        filepath="${save_dir}/Recording-${timestamp}.mp4"
        wf-recorder -f "$filepath" &
        notify-send "Recording started" "${filepath}"
        ;;
    "🖥  Full Recording + Audio")
        filepath="${save_dir}/Recording-${timestamp}.mp4"
        wf-recorder --audio-backend=pipewire -a -f "$filepath" &
        notify-send "Recording started" "${filepath}"
        ;;
esac
