#!/usr/bin/env bash
# Toggle wiremix (PipeWire TUI mixer) in a floating kitty window.
# Used by the Waybar volume module (on-click) and Hyprland SUPER+A.
# Lands on the "output" tab: one volume slider per sink/device.
set -u

if ! command -v wiremix >/dev/null 2>&1; then
    notify-send "wiremix not installed" "Run: sudo dnf install -y wiremix" 2>/dev/null || true
    exit 1
fi

if pgrep -f '[k]itty-wiremix' >/dev/null 2>&1; then
    pkill -f '[k]itty-wiremix'
else
    # Detach all fds so the caller (Waybar, keybind, shell) never blocks.
    # Mixer-only 10pt font: smaller cells = smaller rows (wiremix has no
    # density setting; main terminal config is untouched).
    kitty --class kitty-wiremix -o font_size=10 -e wiremix --tab output </dev/null >/dev/null 2>&1 &
    disown
fi
