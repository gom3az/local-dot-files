#!/usr/bin/env bash
set -euo pipefail

HISTFILE="${CLIPHIST_FILE:-$HOME/.cache/cliphist}"
PINFILE="${CLIPHIST_PINS:-$HOME/.cache/cliphist.pins}"
CURRFILE="$HOME/.cache/cliphist.current"
PLACEHOLDER="<NEWLINE>"

add() {
    local clip
    clip=$(wl-paste 2>/dev/null | tr -d '\000') || true
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
        encoded=$(tr -d '\000' < "$CURRFILE")
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

# === Flexible TUI picker (cut over to `flex clip`, M4) ===
# The bash Flex UI that lived here is retired: `flex clip` renders the
# picker and `flex-clip.sh` resolves hashes + performs copies/pins/deletes
# AFTER the TUI exits. This entry point only delegates so
# `cliphist.sh sel` keeps working; add/pin/unpin/read_current below are
# untouched.
pick() {
    exec "$HOME/dotfiles/flex/flex-rice/wrappers/flex-clip.sh" "$@"
}

case "${1:-}" in
    add) add ;;
    sel) pick ;;
    pin) if [[ -n "${2:-}" ]]; then pin "$2"; else pin; fi ;;
    unpin) if [[ -n "${2:-}" ]]; then unpin "$2"; else unpin; fi ;;
    *)
        echo "Usage: cliphist.sh {add|sel|pin|unpin}"
        echo "  add  — capture current clipboard to history (for wl-paste --watch)"
        echo "  sel  — browse history with the TUI popup and copy selection (m pin/unpin, Delete remove)"
        echo "  pin  — pin current clipboard contents (or provided text)"
        echo "  unpin — unpin current clipboard contents (or provided text)"
        exit 1
        ;;
esac
