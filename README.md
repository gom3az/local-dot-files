# gom3az/dotfiles

Hyprland rice with a wallpaper-driven dynamic theme system.

Colors are extracted from your wallpaper (via pywal16) and propagated across every app — Hyprland, Waybar, Kitty, Rofi, Neovim, tmux, Yazi — as a single `themes` package.

## Features

- **Dynamic theming** — pick a wallpaper, get a full color scheme. `SUPER+W` to pick, `SUPER+T` to switch saved themes.
- **Multi-app coverage** — 7 apps consume the same palette and design tokens (fonts, radii, spacing, opacity).
- **3 pre-built themes** — catppuccin-mocha, tokyo-night, gruvbox. Works with or without pywal16.
- **Lua-driven Hyprland config** — reads colors as a Lua table, loads with fallback chain (theme.lua → colors.lua → defaults → no crash).

## Stack

| Component | Config |
|-----------|--------|
| WM | Hyprland (Lua, v0.55+) |
| Bar | Waybar |
| Terminal | Kitty |
| Launcher | Rofi |
| Editor | Neovim |
| Multiplexer | tmux |
| Shell | Zsh (Starship) |
| File mgr | Yazi |
| Notifications | SwayNC |

## Design

Central `tokens.json` holds all design constants. Colors are extracted from wallpaper, merged with `overrides/global.json`, and templated into per-app configs by `generate-theme.sh`. Named themes are saved to `themes/available/` and switchable via rofi.

See `themes/.config/themes/WORKFLOW.md` for the full architecture.
