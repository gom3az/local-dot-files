#!/usr/bin/env bash
set -euo pipefail

# Live TUI process manager (replaces the rofi kill picker).
# Re-launch inside a floating popup when invoked from bind.
if [[ "${POPUP_KITTY:-}" != 1 ]]; then
    exec "$HOME/.config/scripts/popup.sh" menu-wide "$0" "$@"
fi

exec htop
