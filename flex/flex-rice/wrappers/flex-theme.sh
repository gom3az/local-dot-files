#!/usr/bin/env bash
# flex-theme.sh — wrapper for `flex theme` (M3 theme cutover).
# Reads the single ACTION: line AFTER flex exits (zsh-safe `IFS= read -r`),
# then calls back into `theme-switcher.sh activate` — the list/current/
# activate/delete entry points stay in bash; only the pick() Flex UI was
# cut over. Test override: THEME_SWITCHER.
set -euo pipefail

# `flex` lives in ~/.local/bin (symlink to the release build), which
# Hyprland bind execs don't have on PATH. Only prepend when unresolved so
# deliberately-stubbed PATHs (tests) keep priority.
command -v flex >/dev/null 2>&1 || export PATH="$HOME/.local/bin:$PATH"

# Re-launch inside a floating popup when invoked from a bind (same pattern
# as kill-menu.sh): the TUI needs a real tty, which plain exec doesn't give.
if [[ "${POPUP_KITTY:-}" != 1 ]]; then
    exec "$HOME/.config/scripts/popup.sh" menu "$0" "$@"
fi

out="$(flex theme "$@")" # cancel (130) passes through via set -e

IFS= read -r line <<< "$out"
case "$line" in
    "ACTION: theme "* | "ACTION:DELETE theme "*) ;;
    *) echo "flex-theme: unexpected output: $line" >&2; exit 1 ;;
esac
rest="${line#* theme }"
name="${rest%% *}"
[[ "$name" != */* && "$name" != *$'\n'* && -n "$name" ]] || { echo "flex-theme: bad name: $name" >&2; exit 1; }

theme_switcher="${THEME_SWITCHER:-$HOME/.config/scripts/theme-switcher.sh}"
exec "$theme_switcher" activate "$name"
