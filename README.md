# gom3az/dotfiles

Hyprland rice with a named theme system.

Pre-built color schemes under `themes/available/` are propagated across every app — Hyprland, Waybar, Kitty, Neovim, tmux, Yazi — as a single `themes` package, and switched with `flex-theme`.

## Features

- **Named themes** — `flex-theme list` / `flex-theme activate <name>` (or `SUPER+T`) switch between the saved schemes. Picking a wallpaper (`SUPER+W`) changes the image only and leaves the theme alone.
- **Multi-app coverage** — 7 apps consume the same palette (fonts, radii, spacing, opacity).
- **3 pre-built themes** — catppuccin-mocha, tokyo-night, gruvbox.
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

Central `themes/available/` holds the pre-built color schemes. `flex-theme` copies the chosen one into `themes/current/` and repoints the per-app configs; the wallpaper picker itself never rewrites them. The old `generate-theme.sh` / `generate-static-theme.sh` / `extract-colors.py` tooling has been removed.

See `themes/.config/themes/WORKFLOW.md` for the full architecture.

## flex

The launcher and the wallpaper/theme/clip/wifi pickers are not in this repo.
They live in [`gom3az/flex`](https://github.com/gom3az/flex) — a Cargo
workspace holding the engine (`flex-core`) and the rice glue, the `flex`
binary and the provider binaries (`flex-rice`).

Nothing here hardcodes the checkout path. Every bind and script reaches flex
through two stable symlinks:

| Path | Resolves to |
|------|-------------|
| `~/.local/bin/flex` | `<checkout>/target/release/flex` |
| `~/.local/bin/flex-<provider>` | `<checkout>/target/release/flex-<provider>` |

Moving or re-cloning the checkout therefore means re-pointing those eleven
symlinks — the Hyprland binds and the Waybar on-clicks stay as they are.

## Installing Hyprland on Fedora

Hyprland is built from source (Fedora official repos don't ship it). See
[`docs/HYPRLAND-FEDORA-BUILD.md`](docs/HYPRLAND-FEDORA-BUILD.md) for the full build guide.

## Known issues

- Kotlin LSP `intellij-server has expired` (Neovim + Mason) — see
  [`docs/KOTLIN-LSP-EXPIRY.md`](docs/KOTLIN-LSP-EXPIRY.md) for diagnosis and the
  `faketime` workaround.
