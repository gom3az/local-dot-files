# Theme & Wallpaper Workflow

## Architecture

Themes are pre-built, static sets under `~/.config/themes/available/`;
`flex-theme` copies the chosen one into `current/` and repoints the app
configs. The wallpaper is independent:

```
SUPER+W → kitty popup → flex-wallpaper (pick an image)
                              ↓
                     native setter (exec/wallpaper.rs)
                        ├─ updates hyprpaper.conf (persistence)
                        └─ updates wallpaper via hyprpaper socket
```

Changing the wallpaper does **not** change the theme, and there is no
wallpaper→colors generator any more: `generate-theme.sh`,
`generate-static-theme.sh` and `extract-colors.py` were removed as unused.
Edit a theme's files under `available/<name>/` by hand and activate it with
`flex-theme activate <name>`.

To switch between the saved themes, use `flex theme` (`SUPER+T`).

## Multiple Named Themes

The system switches between multiple named themes.

### Directory Layout

```
~/.config/themes/
├── current/                    # Active theme (app configs symlink here)
└── available/                  # Saved named themes
    ├── catppuccin-mocha/       # Pre-built static themes
    ├── tokyo-night/
    └── gruvbox/
```

### Theme Management

```bash
# List available themes
flex-theme list

# Switch to a saved theme
flex-theme activate catppuccin-mocha

# TUI theme picker (flex)
flex-theme

# See current theme
flex-theme current
```

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
| `~/.local/bin/flex-theme` | Theme picker (`flex theme`) plus `list`/`current`/`activate`/`delete` verbs | Yes (kitty popup) |
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

### Switch to a static theme
```bash
flex-theme activate tokyo-night
```

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

- **Waybar colors stale** → SIGUSR2 is sent by `flex-theme activate`, or `pkill -SIGUSR2 waybar`
- **Kitty colors stale** → SIGUSR1 is sent automatically, or `killall -SIGUSR1 kitty`
- **Hyprland borders wrong** → `hyprctl reload` is called automatically
- **Tmux colors not updating** → `tmux source-file ~/.config/tmux/tmux-colors.conf` or restart tmux server
- **Neovim colors not updating** → restart nvim (colors load at startup via `require("theme")` + `require("nvim-hl")`)
- **Socket errors (flex-wallpaper)** → stale hyprpaper socket detected; falls back to restarting hyprpaper
- **yazi "No such device or address"** → run from a real terminal (kitty via keybinding); not from inside the Claude shell
