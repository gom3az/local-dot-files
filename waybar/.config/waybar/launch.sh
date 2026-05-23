#!/usr/bin/env bash

killall waybar || true
sleep 0.3

LANG=en_US.UTF-8 waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &
