#!/usr/bin/env bash
# =============================================================================
# patch-ml4w-wallpaper.sh - Adds theme generation hook to ml4w-wallpaper
# =============================================================================
# Run this once after installing ml4w-wallpaper to add automatic theme
# generation after wallpaper changes.
# =============================================================================

set -euo pipefail

ML4W_WALLPAPER="$HOME/.config/ml4w/scripts/ml4w-wallpaper"
GENERATE_SCRIPT="$HOME/.config/scripts/generate-theme.sh"

if [[ ! -f "$ML4W_WALLPAPER" ]]; then
    echo "ml4w-wallpaper not found at: $ML4W_WALLPAPER"
    echo "Install ML4W dotfiles first, then run this script."
    exit 1
fi

# Check if already patched
if grep -q "generate-theme.sh" "$ML4W_WALLPAPER" 2>/dev/null; then
    echo "ml4w-wallpaper already patched with theme generation hook."
    exit 0
fi

# Add theme generation hook before the final exit 0
cat >> "$ML4W_WALLPAPER" << 'EOF'

# === Dynamic Theme Generation Hook ===
# Generate colors for waybar, rofi, hyprland from current wallpaper
if [[ -x "$HOME/.config/scripts/generate-theme.sh" ]]; then
    echo "[THEME] Generating dynamic theme..."
    "$HOME/.config/scripts/generate-theme.sh" "$IMAGE_PATH" 2>/dev/null || true
fi
EOF

echo "ml4w-wallpaper patched successfully!"
echo "Theme generation will now run after each wallpaper change."
