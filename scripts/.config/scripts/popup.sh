#!/usr/bin/env bash
# popup.sh — launch a floating kitty popup running any TUI command.
# Usage: popup.sh {menu|menu-wide} <command...>
#   menu       compact 640x420 popup (power, screenshot, theme, wifi)
#   menu-wide  wide 1000x600 popup (launcher, wallpaper, clipboard, htop)
set -euo pipefail

variant="${1:-menu}"
shift || true

case "$variant" in
    menu|menu-wide) ;;
    *)
        echo "Usage: popup.sh {menu|menu-wide} <command...>" >&2
        exit 1
        ;;
esac

[[ $# -eq 0 ]] && exit 1

# Toggle: if a popup of this variant is already open, close it instead of
# stacking another one (same UX as the audio mixer toggle). The trailing
# space keeps menu/menu-wide patterns from colliding with each other, and
# this script's own cmdline ("popup.sh <variant> ...") never contains the
# "kitty --class ..." substring, so pgrep can't match us.
if pgrep -f "kitty --class kitty-${variant} " >/dev/null 2>&1; then
    pkill -f "kitty --class kitty-${variant} "
    exit 0
fi

# All popups run at the mixer font size (10pt, same as the wiremix
# volume control): smaller cells = denser rows, consistent with the
# reference surface. Main terminal config is untouched.
font_size=10

kitty --class "kitty-$variant" -o font_size=$font_size -e env POPUP_KITTY=1 "$@" </dev/null >/dev/null 2>&1 &
disown || true
