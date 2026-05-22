#!/bin/bash

theme_dir="$HOME/.config/rofi"

bars() {
    local s=$1
    if (( s >= 75 )); then echo "▂▄▆█"
    elif (( s >= 50 )); then echo "▂▄▆_"
    elif (( s >= 25 )); then echo "▂▄__"
    else echo "▂___"
    fi
}

if ! nmcli radio wifi | grep -q enabled; then
    choice=$(printf "直 Turn Wi-Fi On" | rofi -dmenu -theme "${theme_dir}/wifi.rasi" -p "WiFi")
    if [ "$choice" = "直 Turn Wi-Fi On" ]; then nmcli radio wifi on; fi
    exit 0
fi

current=$(nmcli -t -f ssid connection show --active 2>/dev/null | head -1)

nmcli -t -f ssid,signal,security device wifi list > /tmp/networks.txt 2>/dev/null &
scan_pid=$!

printf "󰇫  Scanning..." | rofi -dmenu -theme "${theme_dir}/wifi.rasi" -p "WiFi" &
rofi_pid=$!

wait $scan_pid 2>/dev/null
networks=$(cat /tmp/networks.txt)

if kill -0 $rofi_pid 2>/dev/null; then
    kill $rofi_pid 2>/dev/null
    wait $rofi_pid 2>/dev/null
    sleep 0.1

    entries=()
    ssids=()

    entries+=("睊 Turn Wi-Fi Off")
    ssids+=("__action_turn_off__")

    if [ -n "$current" ]; then
        entries+=("睊 Disconnect from ${current}")
        ssids+=("__action_disconnect__")
    fi

    entries+=("─────────────")
    ssids+=("__separator__")

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        ssid=$(echo "$line" | cut -d: -f1)
        signal=$(echo "$line" | cut -d: -f2)
        security=$(echo "$line" | cut -d: -f3-)
        [ -z "$ssid" ] && continue

        found=0
        for existing in "${ssids[@]}"; do
            if [ "$existing" = "$ssid" ]; then
                found=1
                break
            fi
        done
        [ $found -eq 1 ] && continue

        b=$(bars "$signal")
        icon=""
        [[ -n "$security" && "$security" != " " ]] && icon=""

        if [ "$ssid" = "$current" ]; then
            entry="*  ${ssid}  ${b}  ${icon}"
        else
            entry="  ${ssid}  ${b}  ${icon}"
        fi

        entries+=("$entry")
        ssids+=("$ssid")
    done <<< "$networks"

    selected=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -theme "${theme_dir}/wifi.rasi" -p "WiFi")
    [ -z "$selected" ] && exit 0

    target=""
    for i in "${!entries[@]}"; do
        if [ "${entries[$i]}" = "$selected" ]; then
            target="${ssids[$i]}"
            break
        fi
    done

    [ "$target" = "__separator__" ] && exit 0

    if [ "$target" = "__action_turn_off__" ]; then
        nmcli radio wifi off
        exit 0
    fi

    if [ "$target" = "__action_disconnect__" ]; then
        nmcli connection down "$current"
        notify-send "Disconnected from ${current}"
        exit 0
    fi

    if [ "$target" = "$current" ]; then
        nmcli connection down "$current"
        notify-send "Disconnected from ${current}"
        exit 0
    fi

    sec=$(nmcli -t -f ssid,security device wifi list | grep "^${target}:" | head -1 | cut -d: -f2-)

    if [ -n "$sec" ] && [ "$sec" != " " ]; then
        password=$(rofi -dmenu -password -theme "${theme_dir}/wifi-prompt.rasi" -p "Password for ${target}")
        [ -z "$password" ] && exit 0
        nmcli device wifi connect "$target" password "$password"
    else
        nmcli device wifi connect "$target"
    fi

    notify-send "Connected to ${target}"
fi
