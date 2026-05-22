#!/usr/bin/env bash
# =============================================================================
# theme-switcher.sh - Browse and activate named themes
# =============================================================================
# Usage:
#   theme-switcher.sh list              # List available themes
#   theme-switcher.sh current           # Show active theme name
#   theme-switcher.sh activate <name>   # Activate a saved theme
#   theme-switcher.sh rofi              # Rofi-based theme picker GUI
#   theme-switcher.sh delete <name>     # Delete a saved theme
# =============================================================================

set -euo pipefail

THEME_DIR="$HOME/.config/themes/current"
AVAILABLE_DIR="$HOME/.config/themes/available"

info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

notify() {
    notify-send -a "Theme Switcher" -i "preferences-desktop-color" "$1" "$2" 2>/dev/null || true
}

# === List available themes ===
list_themes() {
    local themes=()
    if [[ -d "$AVAILABLE_DIR" ]]; then
        for dir in "$AVAILABLE_DIR"/*/; do
            local name
            name=$(basename "$dir")
            if [[ -f "$dir/metadata.json" ]]; then
                local wallpaper
                wallpaper=$(python3 -c "import json; d=json.load(open('$dir/metadata.json')); print(d.get('wallpaper', 'unknown'))" 2>/dev/null || echo "unknown")
                local generated
                generated=$(python3 -c "import json; d=json.load(open('$dir/metadata.json')); print(d.get('generated', 'unknown'))" 2>/dev/null || echo "unknown")
                printf "  %-30s %-50s %s\n" "$name" "$(basename "$wallpaper")" "$generated"
            else
                printf "  %-30s %-50s %s\n" "$name" "(no metadata)" ""
            fi
        done
    else
        warn "No available themes directory found at $AVAILABLE_DIR"
    fi
}

# === Show active theme ===
show_current() {
    if [[ -f "$THEME_DIR/metadata.json" ]]; then
        local name
        name=$(python3 -c "import json; d=json.load(open('$THEME_DIR/metadata.json')); print(d.get('theme_name', 'unknown'))" 2>/dev/null || echo "unknown")
        local wallpaper
        wallpaper=$(python3 -c "import json; d=json.load(open('$THEME_DIR/metadata.json')); print(d.get('wallpaper', 'unknown'))" 2>/dev/null || echo "unknown")
        echo "Active theme: $name"
        echo "  Wallpaper: $(basename "$wallpaper")"
    else
        warn "No active theme metadata found"
    fi
}

# === Activate a theme ===
activate_theme() {
    local name="$1"
    local src="$AVAILABLE_DIR/$name"

    if [[ ! -d "$src" ]]; then
        error "Theme '$name' not found in $AVAILABLE_DIR"
        echo "Available themes:"
        list_themes
        exit 1
    fi

    if [[ ! -f "$src/theme.css" && ! -f "$src/colors.css" && ! -f "$src/colors.rasi" ]]; then
        error "Theme '$name' has no theme files"
        exit 1
    fi

    info "Activating theme: $name"

    mkdir -p "$THEME_DIR"

    # Copy all files from the theme dir to current
    for f in "$src"/*; do
        if [[ -f "$f" ]]; then
            cp "$f" "$THEME_DIR/"
        fi
    done

    # Create backward-compat symlinks for old file names
    ln -sf "theme.css" "$THEME_DIR/colors.css" 2>/dev/null || true
    ln -sf "theme.lua" "$THEME_DIR/colors.lua" 2>/dev/null || true

    # Update metadata
    local meta="$THEME_DIR/metadata.json"
    if [[ -f "$meta" ]]; then
        python3 -c "
import json
d = json.load(open('$meta'))
d['theme_name'] = '$name'
json.dump(d, open('$meta', 'w'), indent=4)
" 2>/dev/null || true
    fi

    # Run the symlink and reload logic
    info "Updating symlinks..."
    local config_targets=(
        "$HOME/.config/waybar/theme.css"
        "$HOME/.config/rofi/colors.rasi"
        "$HOME/.config/hypr/theme.lua"
        "$HOME/.config/kitty/current-theme.conf"
        "$HOME/.config/yazi/theme.toml"
        "$HOME/.config/tmux/tmux-colors.conf"
        "$HOME/.config/nvim/lua/theme.lua"
    )
    local theme_files=(
        "$THEME_DIR/theme.css"
        "$THEME_DIR/colors.rasi"
        "$THEME_DIR/theme.lua"
        "$THEME_DIR/kitty.conf"
        "$THEME_DIR/yazi.toml"
        "$THEME_DIR/tmux-colors.conf"
        "$THEME_DIR/nvim-colors.lua"
    )

    for i in "${!config_targets[@]}"; do
        local target="${config_targets[$i]}"
        local source="${theme_files[$i]}"

        if [[ -f "$source" ]]; then
            local dir
            dir=$(dirname "$target")
            mkdir -p "$dir"
            rm -f "$target"
            ln -s "$source" "$target"
            info "  Linked: $(basename "$target")"
        fi
    done

    # Reload
    info "Reloading configurations..."
    if pgrep -x "waybar" > /dev/null 2>&1; then
        pkill -SIGUSR2 waybar
        info "  Waybar reloaded (SIGUSR2)"
    fi
    if command -v hyprctl > /dev/null 2>&1; then
        hyprctl reload 2>/dev/null && info "  Hyprland reloaded" || warn "  Hyprland reload failed"
    fi
    if pgrep -x "kitty" > /dev/null 2>&1; then
        killall -SIGUSR1 kitty 2>/dev/null && info "  Kitty reloaded (SIGUSR1)" || warn "  Kitty reload failed"
    fi

    notify "Theme Activated" "Switched to: $name"
    info "Theme '$name' activated successfully"
}

# === Delete a theme ===
delete_theme() {
    local name="$1"
    local src="$AVAILABLE_DIR/$name"

    if [[ ! -d "$src" ]]; then
        error "Theme '$name' not found"
        exit 1
    fi

    if [[ "$name" == "auto" || "$name" == auto-* ]]; then
        warn "Deleting auto-generated theme: $name"
    fi

    rm -rf "$src"
    info "Deleted theme: $name"
}

# === Rofi GUI picker ===
rofi_picker() {
    if ! command -v rofi &>/dev/null; then
        error "rofi is not installed"
        exit 1
    fi

    local themes=()
    while IFS= read -r dir; do
        themes+=("$(basename "$dir")")
    done < <(find "$AVAILABLE_DIR" -maxdepth 1 -type d ! -name "." | sort)

    if [[ ${#themes[@]} -eq 0 ]]; then
        notify "Theme Switcher" "No available themes found"
        exit 0
    fi

    local selected
    selected=$(printf "%s\n" "${themes[@]}" | rofi -dmenu -p "Select Theme" -i)

    if [[ -n "$selected" ]]; then
        activate_theme "$selected"
    fi
}

# === Main ===
main() {
    local cmd="${1:-help}"

    case "$cmd" in
        list)
            list_themes
            ;;
        current)
            show_current
            ;;
        activate)
            if [[ -z "${2:-}" ]]; then
                error "Usage: theme-switcher.sh activate <theme-name>"
                exit 1
            fi
            activate_theme "$2"
            ;;
        delete)
            if [[ -z "${2:-}" ]]; then
                error "Usage: theme-switcher.sh delete <theme-name>"
                exit 1
            fi
            delete_theme "$2"
            ;;
        rofi)
            rofi_picker
            ;;
        help|--help|-h)
            echo "Usage: theme-switcher.sh <command>"
            echo ""
            echo "Commands:"
            echo "  list                    List available themes"
            echo "  current                 Show active theme name"
            echo "  activate <name>         Activate a saved theme"
            echo "  delete <name>           Delete a saved theme"
            echo "  rofi                    Rofi-based theme picker"
            echo "  help                    Show this help"
            ;;
        *)
            error "Unknown command: $cmd"
            echo "Usage: theme-switcher.sh <command>"
            exit 1
            ;;
    esac
}

main "$@"
