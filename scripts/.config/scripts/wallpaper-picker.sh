#!/usr/bin/env bash
# =============================================================================
# wallpaper-picker.sh - Yazi-based wallpaper selector
# =============================================================================

set -euo pipefail

WALLPAPER_DIRS=(
    "$HOME/.config/backgrounds"
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures"
)
SET_WP_SCRIPT="$HOME/.config/scripts/set-wallpaper.sh"
TEMP_DIR="$HOME/.cache/wallpaper-picker/yazi-temp"

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

count=0
for dir in "${WALLPAPER_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' img; do
        name=$(basename "$img")
        dir_prefix=$(basename "$(dirname "$img")")
        ln -sf "$img" "$TEMP_DIR/${dir_prefix}_${name}"
        count=$((count + 1))
    done < <(find "$dir" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 2>/dev/null)
done

if [[ $count -eq 0 ]]; then
    notify-send -a "Wallpaper Picker" "No Images" "Add wallpapers to ~/.config/backgrounds/"
    exit 0
fi

# Inhibit swaync notifications during the entire flow
swaync-client -Ia "wallpaper-picker" 2>/dev/null || true
trap 'swaync-client -Ir "wallpaper-picker" 2>/dev/null || true' EXIT

CHOOSER=$(mktemp)
yazi --chooser-file="$CHOOSER" "$TEMP_DIR"
selected=$(cat "$CHOOSER" 2>/dev/null)
rm -f "$CHOOSER"

if [[ -z "$selected" || ! -e "$selected" ]]; then
    exit 0
fi

real_path=$(realpath "$selected" 2>/dev/null)

if [[ -n "$real_path" && -f "$real_path" && -x "$SET_WP_SCRIPT" ]]; then
    "$SET_WP_SCRIPT" "$real_path"
fi
