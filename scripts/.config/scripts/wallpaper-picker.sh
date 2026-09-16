#!/usr/bin/env bash
# wallpaper-picker.sh — delegating stub: the picker is `flex wallpaper` now
# (see flex/flex-rice/src/exec/wallpaper.rs), which draws the list and the image
# preview pane in the TUI instead of shelling out to fzf + `kitty +kitten
# icat`. The fzf selection list lives on in `src/providers/wallpaper.rs`
# (same roots, same `-maxdepth 2 -iname` filter, same basename labels) and
# the picked path still goes through `set-wallpaper.sh`.
#
# Kept so external callers keep working; `picker-chrome.sh`, which only this
# script sourced, was deleted with the cutover.
set -euo pipefail

exec "$HOME/.local/bin/flex-wallpaper" "$@"
