#!/bin/bash

entries="⏻ Shutdown\n⭮ Reboot\n Suspend\n Lock\n󰍃 Logout"
selected=$(echo -e "$entries" | rofi -dmenu -p "Power Menu" -theme power-menu.rasi)

case "$selected" in
    *Shutdown) systemctl poweroff ;;
    *Reboot)   systemctl reboot ;;
    *Suspend)  systemctl suspend ;;
    *Lock)     hyprlock ;;
    *Logout)   pkill -SIGTERM Hyprland ;;
esac
