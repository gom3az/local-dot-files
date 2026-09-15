#!/usr/bin/env bash
# flex-launch.sh — wrapper for `flex launch` (M2 launcher cutover).
# Reads the single ACTION: line AFTER flex exits (zsh-safe `IFS= read -r`),
# resolves Exec from the desktop id, and launches like app-cache.sh's
# launch_app_row (setsid detach, %X strip, kitty for terminal apps).
set -euo pipefail

# `flex` lives in ~/.local/bin (symlink to the release build), which
# Hyprland bind execs don't have on PATH. Only prepend when unresolved so
# deliberately-stubbed PATHs (tests) keep priority.
command -v flex >/dev/null 2>&1 || export PATH="$HOME/.local/bin:$PATH"

# Re-launch inside a floating popup when invoked from a bind (same pattern
# as kill-menu.sh): the TUI needs a real tty, which plain exec doesn't give.
if [[ "${POPUP_KITTY:-}" != 1 ]]; then
    exec "$HOME/.config/scripts/popup.sh" menu-wide "$0" "$@"
fi

out="$(flex launch "$@")" # cancel (130) passes through via set -e

IFS= read -r line <<< "$out"
case "$line" in
    "ACTION: launch "* | "ACTION:DELETE launch "*) ;;
    *) echo "flex-launch: unexpected output: $line" >&2; exit 1 ;;
esac
rest="${line#* launch }"
id="${rest%% *}"
[[ "$id" != */* && "$id" != *$'\n'* && -n "$id" ]] || { echo "flex-launch: bad id: $id" >&2; exit 1; }

desk=""
for dir in "$HOME/.local/share/applications" "/usr/share/applications"; do
    if [[ -f "$dir/$id" ]]; then desk="$dir/$id"; break; fi
done
[[ -n "$desk" ]] || { echo "flex-launch: $id not found" >&2; exit 1; }

exec=""; term="false"
while IFS='=' read -r key value; do
    case "$key" in
        Exec) [[ -z "$exec" ]] && exec="$value" ;;
        Terminal) term="$value" ;;
    esac
done < <(grep -E '^(Exec|Terminal)=' "$desk")
exec="$(printf '%s' "$exec" | sed -E 's/ %[A-Za-z]//g; s/^ *//; s/ *$//')"
[[ -n "$exec" ]] || { echo "flex-launch: empty Exec in $id" >&2; exit 1; }

if [[ "$term" == "true" ]]; then
    # shellcheck disable=SC2086
    eval 'setsid -f kitty -e '"$exec"' </dev/null >/dev/null 2>&1'
else
    # shellcheck disable=SC2086
    eval 'setsid -f '"$exec"' </dev/null >/dev/null 2>&1'
fi
