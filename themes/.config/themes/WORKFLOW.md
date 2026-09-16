# Wallpaper-Driven Color Scheme — Workflow

## Architecture

```
SUPER+W → kitty popup → flex-wallpaper (pick an image)
                              ↓
                     native setter (exec/wallpaper.rs)
                        ├─ updates hyprpaper.conf (persistence)
                        └─ updates wallpaper via hyprpaper socket
```

Changing the wallpaper does **not** change the theme: `flex-wallpaper` only
swaps the image, so your current colors survive a wallpaper change. Colors are
re-extracted from an image only when `generate-theme.sh` is run by hand:

```
generate-theme.sh [wallpaper] [--save-as <name>]
   ├─ extract-colors.py (Pillow k-means via pywal16)
   ├─ loads design tokens from tokens.json
   ├─ applies overrides from overrides/global.json
   ├─ generates theme.css   → symlinked to ~/.config/waybar/
   ├─ generates theme.lua   → symlinked to ~/.config/hypr/
   ├─ generates kitty.conf  → symlinked to ~/.config/kitty/
   ├─ generates yazi.toml   → symlinked to ~/.config/yazi/
   ├─ generates tmux-colors.conf → symlinked to ~/.config/tmux/
   ├─ generates nvim-colors.lua  → symlinked to ~/.config/nvim/lua/theme.lua
   ├─ saves to available/<name>/ only when --save-as is given
   └─ reloads waybar + hyprland + kitty
```

To switch between the saved themes, use `flex theme` (`SUPER+T`).

## Multiple Named Themes

The system supports saving and switching between multiple named themes.

### Directory Layout

```
~/.config/themes/
├── current/                    # Active theme (app configs symlink here)
├── available/                  # Saved named themes
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
# Extract colors from a wallpaper (current one by default) into current/,
# and keep it under a name you can switch back to later
generate-theme.sh --save-as my-wallpaper

# List available themes
flex-theme list

# Switch to a saved theme
flex-theme activate catppuccin-mocha

# TUI theme picker (flex)
flex-theme

# See current theme
flex-theme current
```

### Generating static themes

```bash
# From a JSON color definition
generate-static-theme.sh path/to/definition.json ~/.config/themes/available/my-theme

# Then activate it
flex-theme activate my-theme
```

## Design Tokens

Non-color design properties are centralized in `~/.config/themes/tokens.json`.

| Token | Default | Used By |
|-------|---------|---------|
| `fonts.sans` | NotoSans Nerd Font | Waybar, Kitty |
| `fonts.mono` | NotoSans Nerd Font | Kitty |
| `fonts.size` | 12px | Waybar, Kitty |
| `radii.window` | 0 | Waybar |
| `spacing.tight` | 4px | Waybar |
| `spacing.normal` | 8px | Waybar |
| `spacing.wide` | 16px | Waybar |
| `opacity.background` | 0.8 | Kitty |
| `gaps.inner` | 5 | Hyprland |
| `gaps.outer` | 5 | Hyprland |

## File Map

| Component | Config File | Theme Source |
|---|---|---|
| Waybar | `~/.config/waybar/style.css` → `@import` → `theme.css` → symlink → | `~/.config/themes/current/theme.css` |
| Hyprland | `~/.config/hypr/hyprland.lua` → `dofile()` → `theme.lua` → symlink → | `~/.config/themes/current/theme.lua` |
| Kitty | `~/.config/kitty/kitty.conf` → `include` → `current-theme.conf` → symlink → | `~/.config/themes/current/kitty.conf` |
| Yazi | `~/.config/yazi/theme.toml` → symlink → | `~/.config/themes/current/yazi.toml` |
| Tmux | `~/.config/tmux/tmux-colors.conf` → `source-file` by tmux.conf → symlink → | `~/.config/themes/current/tmux-colors.conf` |
| Neovim (palette) | `~/.config/nvim/lua/theme.lua` → `require("theme")` → symlink → | `~/.config/themes/current/nvim-colors.lua` |
| Neovim (highlights) | `~/.config/nvim/lua/nvim-hl.lua` → `require("nvim-hl")` → symlink → | `~/.config/themes/current/nvim-hl.lua` |

## Scripts

| Script | Purpose | Interactive? |
|---|---|---|
| `~/.local/bin/flex-wallpaper` | Wallpaper picker (`flex wallpaper`): file list + kitty-graphics image preview pane; `flex-wallpaper set <path>` sets one directly | Yes (kitty popup) |
| `~/.config/scripts/generate-theme.sh` | Extracts colors from a wallpaper, generates all format files, manages symlinks, reloads configs. Persists to `available/` only with `--save-as` | No |
| `~/.config/scripts/extract-colors.py` | pywal16-based color extraction + Catppuccin hierarchy | No |
| `~/.local/bin/flex-theme` | Theme picker (`flex theme`) plus `list`/`current`/`activate`/`delete` verbs | Yes (kitty popup) |
| `~/.config/scripts/generate-static-theme.sh` | Builds a named theme from a JSON color definition | No |
| `~/.local/bin/flex-clip` | Clipboard history: TUI browse (`flex clip`) plus `add`/`pin`/`unpin`/`current` verbs (`wl-paste --watch flex-clip add`) | Yes (kitty popup) |
| `~/.local/bin/flex-proc` | Native process manager: filter `/proc`, Enter = SIGTERM, Delete = SIGKILL, `m` = stop/continue | Yes (kitty popup) |

## Usage

### Change wallpaper
```
SUPER+W  →  flex wallpaper opens in kitty  →  navigate & select image
                                           →  wallpaper changes
                                           →  theme stays as it is
```

Or directly:
```bash
flex-wallpaper set ~/path/to/wallpaper.jpg
```

### Save generated theme for reuse
```bash
generate-theme.sh --save-as my-favorite
```

Without `--save-as`, `generate-theme.sh` refreshes `current/` in place and
leaves `available/` untouched.

### Switch to a static theme
```bash
flex-theme activate tokyo-night
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
    "fonts": { "sans": "FiraCode Nerd Font", "size": "12px" },
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
| `SUPER+W` | Open wallpaper picker (`flex wallpaper` in kitty) — sets the image only, theme unchanged |
| `SUPER+T` | Open theme switcher (flex) |
| `SUPER+N` | Toggle swaync notification panel |
| `SUPER+SHIFT+V` | Browse clipboard history (flex) |
| `SUPER+SHIFT+Esc` | Kill a process (`flex proc` process manager) |
| `SUPER+R` / `SUPER+Space` | Launch app launcher (flex) |

## Troubleshooting

- **Waybar colors stale** → SIGUSR2 is sent automatically by generate-theme.sh, or `pkill -SIGUSR2 waybar`
- **Kitty colors stale** → SIGUSR1 is sent automatically, or `killall -SIGUSR1 kitty`
- **Hyprland borders wrong** → `hyprctl reload` is called automatically
- **Tmux colors not updating** → `tmux source-file ~/.config/tmux/tmux-colors.conf` or restart tmux server
- **Neovim colors not updating** → restart nvim (colors load at startup via `require("theme")` + `require("nvim-hl")`)
- **Socket errors (flex-wallpaper)** → stale hyprpaper socket detected; falls back to restarting hyprpaper
- **yazi "No such device or address"** → run from a real terminal (kitty via keybinding); not from inside the Claude shell
