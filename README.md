# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
git clone https://github.com/gom3az/local-dot-files.git ~/dotfiles
cd ~/dotfiles
stow hypr kitty nvim rofi scripts themes tmux waybar zsh
```

## Packages

| Package   | Targets                           |
|-----------|-----------------------------------|
| `hypr`    | `~/.config/hypr`                  |
| `kitty`   | `~/.config/kitty`                 |
| `nvim`    | `~/.config/nvim`                  |
| `rofi`    | `~/.config/rofi`                  |
| `themes`  | `~/.config/themes`                |
| `tmux`    | `~/.tmux.conf`, `~/.tmux/`        |
| `scripts` | `~/.config/scripts`               |
| `waybar`  | `~/.config/waybar`                |
| `zsh`     | `~/.zshrc`                        |

## Dynamic Theme System

Wallpaper-driven colors with pywal16, persisted as named themes.

- `SUPER+W` — pick wallpaper → auto-generate theme
- `SUPER+T` — rofi theme switcher
- Pre-built: catppuccin-mocha, tokyo-night, gruvbox

Design tokens (fonts, radii, spacing, opacity) centralized in `tokens.json`.

For full workflow details, see `themes/.config/themes/WORKFLOW.md`.
