#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIRS=(
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures/Screenshots"
)

SET_WP_SCRIPT="$HOME/.config/scripts/set-wallpaper.sh"

if [[ ! -x "$SET_WP_SCRIPT" ]]; then
    echo "Error: Setter script not found or not executable at $SET_WP_SCRIPT" >&2
    exit 1
fi

list_wallpapers() {
    for dir in "${WALLPAPER_DIRS[@]}"; do
        [[ ! -d "$dir" ]] && continue

        local dir_prefix
        dir_prefix=$(basename "$dir")

        find "$dir" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | while read -r img; do
            local filename
            filename=$(basename "$img")
            printf '%s\0icon\x1f%s\n' "${dir_prefix}/${filename}" "$img"
        done
    done
}

selected=$(list_wallpapers | rofi -dmenu -i -p "󰸉 Wallpapers" \
    -theme-str '
        configuration {
            show-icons: true;
        }
        window {
            width: 75%;
            location: center;
            anchor: center;
        }
        listview {
            columns: 3;
            lines: 1;
            spacing: 18px;
            cycle: true;
            fixed-height: true;
        }
        element {
            orientation: vertical;
            padding: 12px;
            border-radius: 6px;
        }
        element-icon {
            size: 280px;
            horizontal-align: 0.5;
        }
        element-text {
            horizontal-align: 0.5;
            vertical-align: 0.5;
            padding: 6px 0px 0px 0px;
        }
    ')

[[ -z "$selected" ]] && exit 0

dir_prefix="${selected%%/*}"
filename="${selected#*/}"

for dir in "${WALLPAPER_DIRS[@]}"; do
    [[ "$(basename "$dir")" != "$dir_prefix" ]] && continue

    candidate=$(find "$dir" -maxdepth 2 -type f -name "$filename" -print -quit 2>/dev/null)

    if [[ -n "$candidate" ]]; then
        "$SET_WP_SCRIPT" "$candidate"
        exit 0
    fi
done

echo "Error: Could not trace target path for file: $filename" >&2
exit 1
