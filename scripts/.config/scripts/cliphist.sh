#!/usr/bin/env bash
set -euo pipefail

HISTFILE="$HOME/.cache/cliphist"
PLACEHOLDER="<NEWLINE>"

add() {
    local clip
    clip=$(wl-paste 2>/dev/null) || true
    [[ -z "$clip" ]] && exit 0

    mkdir -p "$(dirname "$HISTFILE")"
    [[ ! -f "$HISTFILE" ]] && touch "$HISTFILE"

    local multiline
    multiline=$(echo "$clip" | sed ':a;N;$!ba;s/\n/'"$PLACEHOLDER"'/g')
    grep -Fxq "$multiline" "$HISTFILE" || echo "$multiline" >> "$HISTFILE"
}

pick() {
    [[ ! -f "$HISTFILE" ]] && notify-send -a "Clipboard" "No history yet" && exit 0

    local selection
    selection=$(tac "$HISTFILE" | rofi -dmenu -l 12 -i -p "Clipboard:" -theme-str 'window {width: 40%;} listview {lines: 12;}') || exit 0
    [[ -z "$selection" ]] && exit 0

    echo "$selection" | sed "s/$PLACEHOLDER/\n/g" | wl-copy
}

case "${1:-}" in
    add) add ;;
    sel) pick ;;
    *)
        echo "Usage: cliphist.sh {add|sel}"
        echo "  add  — capture current clipboard to history (for wl-paste --watch)"
        echo "  sel  — browse history with rofi and paste selection"
        exit 1
        ;;
esac
