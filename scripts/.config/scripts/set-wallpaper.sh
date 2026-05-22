#!/usr/bin/env bash
# =============================================================================
# set-wallpaper.sh - Universal wallpaper setter with theme generation
# =============================================================================
# Usage: set-wallpaper.sh <path_to_image>
#
# This script:
# 1. Updates hyprpaper.conf with the new wallpaper
# 2. Reloads hyprpaper
# 3. Triggers theme generation from the new wallpaper
#
# Can be used as a replacement for direct hyprpaper.conf edits or
# integrated with other wallpaper setters.
# =============================================================================

set -euo pipefail

HYPRLAND_CONF="$HOME/.config/hypr/hyprpaper.conf"
GENERATE_SCRIPT="$HOME/.config/scripts/generate-theme.sh"
WALLPAPER_CACHE="$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper"

info() { echo -e "\033[0;32m[SET-WP]\033[0m $1"; }
error() { echo -e "\033[0;31m[SET-WP]\033[0m $1" >&2; }

if [[ $# -lt 1 ]]; then
    error "Usage: set-wallpaper.sh <path_to_image>"
    exit 1
fi

IMAGE_PATH="$1"

if [[ ! -f "$IMAGE_PATH" ]]; then
    error "Image not found: $IMAGE_PATH"
    exit 1
fi

# Resolve to absolute path
IMAGE_PATH=$(realpath "$IMAGE_PATH")

info "Setting wallpaper: $(basename "$IMAGE_PATH")"

# Inhibit swaync notifications during the entire flow
swaync-client -Ia "wallpaper-setter" 2>/dev/null || true

# Update hyprpaper via socket or restart
HYPRLAND_RUN_DIR="/run/user/$(id -u)/hypr"

# Check if hyprpaper is actually running (not just stale socket)
if pgrep -x hyprpaper > /dev/null 2>&1; then
    HYPREPAPER_SOCKET=$(find "$HYPRLAND_RUN_DIR" -name ".hyprpaper.sock" -type s 2>/dev/null | head -1)
    if [[ -n "$HYPREPAPER_SOCKET" ]]; then
        # Test socket connection
        if echo "" | socat - UNIX-CONNECT:"$HYPREPAPER_SOCKET" >/dev/null 2>&1; then
            # Preload the new wallpaper
            echo "preload $IMAGE_PATH" | socat - UNIX-CONNECT:"$HYPREPAPER_SOCKET" >/dev/null 2>&1
            sleep 0.2
            # Set the wallpaper
            echo "wallpaper ,$IMAGE_PATH" | socat - UNIX-CONNECT:"$HYPREPAPER_SOCKET" >/dev/null 2>&1
            info "Updated hyprpaper via socket"
        fi
    fi
fi

# If socket method failed or hyprpaper wasn't running, restart it
if ! pgrep -x hyprpaper > /dev/null 2>&1; then
    killall hyprpaper 2>/dev/null || true
    sleep 0.3
    nohup hyprpaper > /dev/null 2>&1 &
    disown
    sleep 1
    info "Restarted hyprpaper"
fi

# Update hyprpaper.conf for persistence
cat > "$HYPRLAND_CONF" << EOF
preload = $IMAGE_PATH
wallpaper = , $IMAGE_PATH
EOF

# Update ml4w cache if directory exists
if [[ -d "$(dirname "$WALLPAPER_CACHE")" ]]; then
    mkdir -p "$(dirname "$WALLPAPER_CACHE")"
    echo "$IMAGE_PATH" > "$WALLPAPER_CACHE"
fi

# Generate theme
if [[ -x "$GENERATE_SCRIPT" ]]; then
    "$GENERATE_SCRIPT" "$IMAGE_PATH"
fi

# Release swaync inhibitor
swaync-client -Ir "wallpaper-setter" 2>/dev/null || true

info "Wallpaper set successfully"
