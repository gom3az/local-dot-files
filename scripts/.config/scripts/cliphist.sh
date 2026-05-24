#!/usr/bin/env bash
set -euo pipefail

HISTFILE="$HOME/.cache/cliphist"
PINFILE="$HOME/.cache/cliphist.pins"
CURRFILE="$HOME/.cache/cliphist.current"
PLACEHOLDER="<NEWLINE>"

add() {
    local clip
    clip=$(wl-paste 2>/dev/null) || true
    [[ -z "$clip" ]] && exit 0

    mkdir -p "$(dirname "$HISTFILE")"
    [[ ! -f "$HISTFILE" ]] && touch "$HISTFILE"

    local multiline
    multiline=$(echo "$clip" | sed ':a;N;$!ba;s/\n/'"$PLACEHOLDER"'/g')
    echo "$multiline" > "$CURRFILE"
    grep -Fxq "$multiline" "$HISTFILE" || echo "$multiline" >> "$HISTFILE"
}

read_current() {
    if [[ -f "$CURRFILE" ]]; then
        local encoded
        encoded=$(<"$CURRFILE")
        if [[ -n "$encoded" ]]; then
            echo "$encoded" | sed "s/$PLACEHOLDER/\n/g"
        fi
    fi
}

pin() {
    local clip
    if [[ $# -gt 0 ]]; then
        clip="$1"
    else
        clip=$(read_current)
    fi

    if [[ -z "$clip" ]]; then
        notify-send -a "Cliphist" "Nothing to pin" "Clipboard is empty — copy something first"
        exit 0
    fi

    mkdir -p "$(dirname "$PINFILE")"
    [[ ! -f "$PINFILE" ]] && touch "$PINFILE"

    local multiline
    multiline=$(echo "$clip" | sed ':a;N;$!ba;s/\n/'"$PLACEHOLDER"'/g')
    if grep -Fxq "$multiline" "$PINFILE"; then
        notify-send -a "Cliphist" "Already pinned" "$(echo "$clip" | head -c 50)"
    else
        echo "$multiline" >> "$PINFILE"
        notify-send -a "Cliphist" "Pinned to history" "$(echo "$clip" | head -c 50)"
    fi
}

unpin() {
    local clip
    if [[ $# -gt 0 ]]; then
        clip="$1"
    else
        clip=$(read_current)
    fi

    if [[ -z "$clip" ]]; then
        notify-send -a "Cliphist" "Nothing to unpin" "Clipboard is empty"
        exit 0
    fi

    if [[ ! -f "$PINFILE" ]]; then
        notify-send -a "Cliphist" "Nothing unpinned" "No pinned items exist"
        exit 0
    fi

    local multiline
    multiline=$(echo "$clip" | sed ':a;N;$!ba;s/\n/'"$PLACEHOLDER"'/g')

    if grep -Fxq "$multiline" "$PINFILE"; then
        grep -Fxv "$multiline" "$PINFILE" > "${PINFILE}.tmp" || true
        mv "${PINFILE}.tmp" "$PINFILE"
        notify-send -a "Cliphist" "Unpinned" "$(echo "$clip" | head -c 50)"
    else
        notify-send -a "Cliphist" "Not pinned" "$(echo "$clip" | head -c 50)"
    fi
}

pick() {
    [[ ! -f "$HISTFILE" ]] && notify-send -a "Cliphist" "No history yet" && exit 0
    [[ ! -f "$PINFILE" ]] && touch "$PINFILE"

    while true; do
        local display_list=""

        # Build a set of pinned entries to filter them from history
        local pinned_set=""
        if [[ -s "$PINFILE" ]]; then
            pinned_set=$(cat "$PINFILE")
        fi

        # Add pinned entries first with 📌 prefix
        if [[ -s "$PINFILE" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    display_list+="📌 $line"$'\n'
                fi
            done < "$PINFILE"
        fi

        # Add history entries, skipping duplicates of pinned ones
        if [[ -s "$HISTFILE" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    if ! grep -Fqx "$line" <<< "$pinned_set" 2>/dev/null; then
                        display_list+="$line"$'\n'
                    fi
                fi
            done < <(tac "$HISTFILE")
        fi

        display_list="${display_list%$'\n'}"

        if [[ -z "$display_list" ]]; then
            notify-send -a "Cliphist" "No history yet" && exit 0
        fi

        local selection
        local exit_code
        selection=$(echo -e "$display_list" | rofi -dmenu -l 12 -i -p "Cliphist:" \
            -kb-custom-1 "Alt+p" \
            -kb-custom-2 "Alt+Delete" \
            -theme-str 'window {width: 40%;} listview {lines: 12;}') || exit_code=$?

        if [[ $exit_code -eq 1 ]]; then
            exit 0
        elif [[ $exit_code -eq 10 ]]; then
            local actual_entry
            if [[ "$selection" == 📌* ]]; then
                actual_entry="${selection#📌 }"
                unpin "$actual_entry"
            else
                pin "$selection"
            fi
            continue
        elif [[ $exit_code -eq 11 ]]; then
            local actual_entry
            if [[ "$selection" == 📌* ]]; then
                actual_entry="${selection#📌 }"
            else
                actual_entry="$selection"
            fi
            local multiline
            multiline=$(echo "$actual_entry" | sed ':a;N;$!ba;s/\n/'"$PLACEHOLDER"'/g')
            if [[ -f "$HISTFILE" ]]; then
                grep -Fxv "$multiline" "$HISTFILE" > "${HISTFILE}.tmp" || true
                mv "${HISTFILE}.tmp" "$HISTFILE"
            fi
            if [[ -f "$PINFILE" ]]; then
                grep -Fxv "$multiline" "$PINFILE" > "${PINFILE}.tmp" || true
                mv "${PINFILE}.tmp" "$PINFILE"
            fi
            notify-send -a "Cliphist" "Deleted" "$(echo "$actual_entry" | head -c 50)"
            continue
        elif [[ $exit_code -eq 0 ]]; then
            local actual_entry
            if [[ "$selection" == 📌* ]]; then
                actual_entry="${selection#📌 }"
                echo "$actual_entry" | sed "s/$PLACEHOLDER/\n/g" | wl-copy
                notify-send -a "Cliphist" "Copied to clipboard" "$(echo "$actual_entry" | head -c 50)"
            else
                echo "$selection" | sed "s/$PLACEHOLDER/\n/g" | wl-copy
                notify-send -a "Cliphist" "Copied to clipboard" "$(echo "$selection" | head -c 50)"
            fi
            exit 0
        else
            exit $exit_code
        fi
    done
}

case "${1:-}" in
    add) add ;;
    sel) pick ;;
    pin) if [[ -n "${2:-}" ]]; then pin "$2"; else pin; fi ;;
    unpin) if [[ -n "${2:-}" ]]; then unpin "$2"; else unpin; fi ;;
    *)
        echo "Usage: cliphist.sh {add|sel|pin|unpin}"
        echo "  add  — capture current clipboard to history (for wl-paste --watch)"
        echo "  sel  — browse history with rofi and paste selection (with pin/unpin/delete)"
        echo "  pin  — pin current clipboard contents (or provided text)"
        echo "  unpin — unpin current clipboard contents (or provided text)"
        exit 1
        ;;
esac