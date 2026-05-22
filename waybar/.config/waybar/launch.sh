#!/usr/bin/env bash

killall waybar || true
sleep 0.3

waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &
