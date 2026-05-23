# Wallpaper-Driven Color Scheme — Workflow

## Architecture

```
SUPER+W → kitty → yazi (pick wallpaper)
                          ↓
                 set-wallpaper.sh
                    ├─ updates hyprpaper.conf (persistence)
                    ├─ updates wallpaper via hyprpaper socket
                    └─ calls generate-theme.sh
                              ├─ extract-colors.py (Pillow k-means via pywal16)
                              ├─ loads design tokens from tokens.json
                              ├─ applies overrides from overrides/global.json
                              ├─ generates theme.css   → symlinked to ~/.config/waybar/
                              ├─ generates theme.rasi  → symlinked to ~/.config/rofi/
                              ├─ generates theme.lua   → symlinked to ~/.config/hypr/
                              ├─ generates kitty.conf  → symlinked to ~/.config/kitty/
                              ├─ generates yazi.toml   → symlinked to ~/.config/yazi/
                              ├─ generates tmux-colors.conf → symlinked to ~/.config/tmux/
                              ├─ generates nvim-colors.lua  → symlinked to ~/.config/nvim/lua/theme.lua
                              ├─ saves to available/<name>/ for reuse
                              └─ reloads waybar + hyprland + kitty
```

## Multiple Named Themes

The system supports saving and switching between multiple named themes.

### Directory Layout

```
~/.config/themes/
├── current/                    # Active theme (app configs symlink here)
├── available/                  # Saved named themes
│   ├── auto/                   # Latest wallpaper-generated theme
│   ├── catppuccin-mocha/       # Pre-built static themes
│   ├── tokyo-night/
│   └── gruvbox/
├── overrides/
│   ├── global.json             # Color overrides applied after extraction
│   └── example.json
└── tokens.json                 # Design tokens (fonts, radii, spacing, opacity)
```

### Theme Management

```bash
# Save auto-generated theme with a custom name
generate-theme.sh --save-as my-wallpaper

# List available themes
theme-switcher.sh list

# Switch to a saved theme
theme-switcher.sh activate catppuccin-mocha

# Rofi-based theme picker
theme-switcher.sh rofi

# See current theme
theme-switcher.sh current
```

### Generating static themes

```bash
# From a JSON color definition
generate-static-theme.sh path/to/definition.json ~/.config/themes/available/my-theme

# Then activate it
theme-switcher.sh activate my-theme
```

## Design Tokens

Non-color design properties are centralized in `~/.config/themes/tokens.json`.

| Token | Default | Used By |
|-------|---------|---------|
| `fonts.sans` | JetBrainsMono Nerd Font | Waybar, Kitty, Rofi |
| `fonts.mono` | JetBrainsMono Nerd Font | Kitty |
| `fonts.size` | 14px | Waybar, Kitty, Rofi |
| `radii.window` | 0 | Waybar, Rofi |
| `spacing.tight` | 4px | Waybar, Rofi |
| `spacing.normal` | 8px | Waybar |
| `spacing.wide` | 16px | Waybar |
| `opacity.background` | 0.8 | Kitty |
| `gaps.inner` | 5 | Hyprland |
| `gaps.outer` | 5 | Hyprland |

## File Map

| Component | Config File | Theme Source |
|---|---|---|
| Waybar | `~/.config/waybar/style.css` → `@import` → `theme.css` → symlink → | `~/.config/themes/current/theme.css` |
| Rofi | `~/.config/rofi/config.rasi` → imports → `theme.rasi` → imports → `theme.rasi` → symlink → | `~/.config/themes/current/theme.rasi` |
| Hyprland | `~/.config/hypr/hyprland.lua` → `dofile()` → `theme.lua` → symlink → | `~/.config/themes/current/theme.lua` |
| Kitty | `~/.config/kitty/kitty.conf` → `include` → `current-theme.conf` → symlink → | `~/.config/themes/current/kitty.conf` |
| Yazi | `~/.config/yazi/theme.toml` → symlink → | `~/.config/themes/current/yazi.toml` |
| Tmux | `~/.config/tmux/tmux-colors.conf` → `source-file` by tmux.conf → symlink → | `~/.config/themes/current/tmux-colors.conf` |
| Neovim | `~/.config/nvim/lua/theme.lua` → `require("theme")` → symlink → | `~/.config/themes/current/nvim-colors.lua` |

## Scripts

| Script | Purpose | Interactive? |
|---|---|---|
| `~/.config/scripts/wallpaper-rofi.sh` | Rofi grid wallpaper picker with image previews | Yes (rofi) |
| `~/.config/scripts/set-wallpaper.sh` | Sets wallpaper via hyprpaper socket | No |
| `~/.config/scripts/generate-theme.sh` | Extracts colors, generates all format files, manages symlinks, reloads configs | No |
| `~/.config/scripts/extract-colors.py` | pywal16-based color extraction + Catppuccin hierarchy | No |
| `~/.config/scripts/theme-switcher.sh` | CLI + rofi GUI for switching named themes | Yes (rofi) |
| `~/.config/scripts/generate-static-theme.sh` | Builds a named theme from a JSON color definition | No |
| `~/.config/scripts/cliphist.sh` | Clipboard history via wl-paste --watch, rofi browse | Yes (rofi) |
| `~/.config/scripts/kill-menu.sh` | Rofi-based process killer | Yes (rofi) |
| `~/.config/scripts/patch-ml4w-wallpaper.sh` | Hooks theme generation into ml4w-wallpaper | No |

## Usage

### Change wallpaper (auto theme)
```
SUPER+W  →  yazi opens in kitty  →  navigate & select image
                                    →  wallpaper changes
                                    →  colors auto-extracted
                                    →  waybar/hyprland/kitty reloaded
                                    →  theme saved to available/auto-<timestamp>/
```

Or directly:
```bash
~/.config/scripts/set-wallpaper.sh ~/path/to/wallpaper.jpg
```

### Save generated theme for reuse
```bash
generate-theme.sh --save-as my-favorite
```

### Switch to a static theme
```bash
theme-switcher.sh activate tokyo-night
```

### Override specific colors
Edit `~/.config/themes/overrides/global.json`:
```json
{
    "mauve": "#cba6f7",
    "blue": "#89b4fa"
}
```
Then regenerate: `~/.config/scripts/generate-theme.sh`

### Customize design tokens
Edit `~/.config/themes/tokens.json`:
```json
{
    "fonts": { "sans": "FiraCode Nerd Font", "size": "13px" },
    "radii": { "window": 6, "button": 4 }
}
```
Then regenerate: `~/.config/scripts/generate-theme.sh`

## Color Extraction

`extract-colors.py` uses pywal16's median-cut quantization to find the 8 most dominant colors, then:

1. **Darkest** → background (`color0`)
2. **Lightest** → foreground (`color7`)
3. **Remaining 6** → assigned to red/green/yellow/blue/mauve/teal by nearest hue
4. **Bright variants** (`color8`–`color15`) → each base color lightened by 30%
5. **Catppuccin-style hierarchy** → crust, mantle, base, surface0-2, overlay0-2, subtext0-1 built from background with contrast enforcement
6. Overrides from `global.json` applied after extraction
7. Design tokens from `tokens.json` embedded into all generated files

## Keybindings

| Binding | Action |
|---|---|
| `SUPER+W` | Open wallpaper picker (yazi in kitty) |
| `SUPER+T` | Open theme switcher (rofi) |
| `SUPER+N` | Toggle swaync notification panel |
| `SUPER+SHIFT+V` | Browse clipboard history (rofi) |
| `SUPER+SHIFT+Esc` | Kill a process (rofi) |
| `SUPER+R` / `SUPER+Space` | Launch rofi app launcher |

## Troubleshooting

- **Rofi colors not updating** → Rofi reads theme on launch; just close and re-open it
- **Waybar colors stale** → SIGUSR2 is sent automatically by generate-theme.sh, or `pkill -SIGUSR2 waybar`
- **Kitty colors stale** → SIGUSR1 is sent automatically, or `killall -SIGUSR1 kitty`
- **Hyprland borders wrong** → `hyprctl reload` is called automatically
- **Tmux colors not updating** → `tmux source-file ~/.config/tmux/tmux-colors.conf` or restart tmux server
- **Neovim colors not updating** → restart nvim (colors load at startup via `require("theme")`)
- **Socket errors (set-wallpaper.sh)** → stale hyprpaper socket detected; falls back to restarting hyprpaper
- **yazi "No such device or address"** → run from a real terminal (kitty via keybinding); not from inside the Claude shell
