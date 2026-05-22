#!/bin/bash

interface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5}')
[ -z "$interface" ] && { echo '{"text":"⬇ ?  ⬆ ?","class":"idle"}'; exit 1; }

rx_file="/sys/class/net/${interface}/statistics/rx_bytes"
tx_file="/sys/class/net/${interface}/statistics/tx_bytes"

read_bytes() {
    cat "$rx_file" "$tx_file" 2>/dev/null
}

r0=($(read_bytes))
sleep 1
r1=($(read_bytes))

rx_diff=$(( r1[0] - r0[0] ))
tx_diff=$(( r1[1] - r0[1] ))

[ $rx_diff -lt 0 ] && rx_diff=0
[ $tx_diff -lt 0 ] && tx_diff=0

format_speed() {
    local bytes=$1
    if [ $bytes -ge 1048576 ]; then
        echo "$(awk "BEGIN { printf \"%.1f MB/s\", $bytes / 1048576 }")"
    elif [ $bytes -ge 1024 ]; then
        echo "$(awk "BEGIN { printf \"%.0f KB/s\", $bytes / 1024 }")"
    else
        echo "${bytes} B/s"
    fi
}

down=$(format_speed $rx_diff)
up=$(format_speed $tx_diff)

if [ $rx_diff -gt 0 ] || [ $tx_diff -gt 0 ]; then
    class="up"
else
    class="idle"
fi

printf '{"text":" %s   %s","class":"%s"}\n' "$down" "$up" "$class"
