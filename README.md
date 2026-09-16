# gom3az/dotfiles

Hyprland rice with a wallpaper-driven dynamic theme system.

Colors are extracted from a wallpaper image (via pywal16) and propagated across every app — Hyprland, Waybar, Kitty, Neovim, tmux, Yazi — as a single `themes` package.

## Features

- **Dynamic theming** — regenerate a full color scheme from any image with `generate-theme.sh --save-as <name>`, then switch between saved schemes with `SUPER+T`. Picking a wallpaper (`SUPER+W`) changes the image only and leaves the theme alone.
- **Multi-app coverage** — 7 apps consume the same palette and design tokens (fonts, radii, spacing, opacity).
- **3 pre-built themes** — catppuccin-mocha, tokyo-night, gruvbox. Works with or without pywal16.
- **Lua-driven Hyprland config** — reads colors as a Lua table, loads with fallback chain (theme.lua → colors.lua → defaults → no crash).

## Stack

| Component | Config |
|-----------|--------|
| WM | Hyprland (Lua, v0.55+) |
| Bar | Waybar |
| Terminal | Kitty |
| Launcher | flex (Lua→Rust TUI launcher) |
| Editor | Neovim |
| Multiplexer | tmux |
| Shell | Zsh (Starship) |
| File mgr | Yazi |
| Notifications | SwayNC |

## Design

Central `tokens.json` holds all design constants. Colors are extracted from a wallpaper image, merged with `overrides/global.json`, and templated into per-app configs by `generate-theme.sh`. Named themes are saved to `themes/available/` and switchable via `flex theme`; the wallpaper picker itself never rewrites them.

See `themes/.config/themes/WORKFLOW.md` for the full architecture.

## flex

The launcher and the wallpaper/theme/clip/wifi pickers are not in this repo.
They live in [`gom3az/flex`](https://github.com/gom3az/flex) — a Cargo
workspace holding the engine (`flex-core`) and the rice glue, the `flex`
binary and the eight provider wrappers (`flex-rice`).

Nothing here hardcodes the checkout path. Every bind and script reaches flex
through two stable symlinks:

| Path | Resolves to |
|------|-------------|
| `~/.local/bin/flex` | `<checkout>/target/release/flex` |
| `~/.local/bin/flex-<provider>.sh` | `<checkout>/flex-rice/wrappers/flex-<provider>.sh` |

Moving or re-cloning the checkout therefore means re-pointing those nine
symlinks — the Hyprland binds, the Waybar on-clicks and the `scripts/*`
delegating stubs stay as they are.

## Installing Hyprland on Fedora

Hyprland is built from source (Fedora official repos don't ship it). See
[`docs/HYPRLAND-FEDORA-BUILD.md`](docs/HYPRLAND-FEDORA-BUILD.md) for the full build guide.

## Known issues

- Kotlin LSP `intellij-server has expired` (Neovim + Mason) — see
  [`docs/KOTLIN-LSP-EXPIRY.md`](docs/KOTLIN-LSP-EXPIRY.md) for diagnosis and the
  `faketime` workaround.
