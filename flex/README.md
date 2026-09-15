# flex — reusable Rust TUI menu library

`flex` powers the dotfiles popup menus (`power`, `launch`, `clip`, `center`,
`shot`, `theme`, `wallpaper`, `wifi`) behind a single `ACTION:` stdout protocol.
The library never executes side effects; thin `wrappers/*.sh` scripts parse the
`ACTION:` line and perform the real work (shutdown, clipboard copy, app exec,
wallpaper swap, Wi-Fi connect, …).

## Workspace layout

The workspace is split along the line that matters for reuse:

| Crate | What it is | Publishable |
|---|---|---|
| `flex-core` | The engine: menu/list rendering, fuzzy filtering, key handling, the design system, kitty-graphics previews. Generic — no machine-specific path anywhere. | Yes |
| `flex-rice` | This Hyprland rice's glue: the eight providers, the `flex` binary and the shell wrappers under `flex-rice/wrappers/`. Reads `~/.config/themes`, `hyprpaper.conf`, `~/.cache/cliphist` and ML4W's wallpaper cache. | No (`publish = false`) |

Dependencies run one way (`flex-rice` → `flex-core`). The engine's only former
reach into providers is now a seam: `Menu::on_tick` takes a `TickHook`, and
`flex-rice` supplies the one that refreshes `center` gauges and picks up a
finished `wifi` scan — build menus in this repo with `flex_rice::menu(…)`,
which installs it.

```sh
cargo test                       # both crates (-p flex-core / -p flex-rice to scope)
cargo build --release            # → target/release/flex (what the wrappers exec)
cargo clippy --all-targets -- -D warnings
cargo package -p flex-core       # the library half packages on its own
```

## `ACTION:` protocol

On success the binary prints **exactly one line** to stdout:

```text
ACTION: <provider> <action_id> <escaped-label>
```

- `<provider>`: one of `power|launch|shot|theme|clip|center|wallpaper|wifi`.
- `<action_id>`: opaque, provider-defined id. For `clip` it is the
  content-hash hex (`RowId`, Q2) so wrappers can round-trip history entries;
  `wallpaper` uses the same idea over the absolute path and exposes the
  hidden `flex wallpaper --resolve <id>` lookup. `wifi` ids are the fixed
  actions (`off`/`on`/`disconnect`/`wifi`/`noop`) and take their SSID from
  the escaped label, because SSIDs contain spaces.
- `<escaped-label>`: human label with `\n`/`\` escaped; wrappers must unescape.

Exit codes: `0` = action chosen, `130` = user cancelled (`Esc`/`q`), `1` = error.
All diagnostics go to **stderr**; stdout carries only the `ACTION:` line.
Deletable tabs (`clip`) also emit `ACTION:DELETE <provider> …` (confirmed
delete) and `ACTION:TOGGLE <provider> …` (NAVIGATE `m` pin toggle).

## Wrapper recipes (placeholder — full scripts land in M4)

```sh
# wrappers/launch.sh (sketch)
out="$(flex launch)" || exit "$?"   # 130 = cancel, passthrough
action_id="$(printf '%s' "$out" | awk '{print $2}')"
exec_app "$action_id"
```

Each wrapper owns its side effects. The library/binary only *selects*.

## Cutover table (M4 order: launcher FIRST, power LAST — all ✅ v1.0)

| Script (today) | Provider | Wrapper | Status |
|---|---|---|---|
| `app-launcher.sh` (deleted 2026-09-15) | `launch` | `wrappers/flex-launch.sh` | ✅ cut over (M2; keybinds → `flex-launch.sh`, `app-cache.sh` kept for control-center) |
| `cliphist.sh` (`pick()` delegates; add/pin/unpin intact) | `clip` | `wrappers/flex-clip.sh` | ✅ cut over (M4; keybind → `flex-clip.sh`, `ACTION:`/`ACTION:DELETE`/`ACTION:TOGGLE` + `clip --resolve`) |
| `control-center.sh` (deleted 2026-09-15) | `center` | `wrappers/flex-center.sh` | ✅ cut over (M5; keybind `SUPER+X` → `flex-center.sh`, `app-cache.sh` kept as row-set reference, `popup.sh` kept for kill-menu/wallpaper-picker) |
| screenshot flow (`screenshot.sh` deleted 2026-09-15) | `shot` | `wrappers/flex-shot.sh` | ✅ cut over (M3; keybind → `flex-shot.sh`, pipeline runs post-TUI) |
| `theme-switcher.sh` (`pick()` delegates; the `rofi` arm was removed 2026-09-15; list/current/activate/delete intact) | `theme` | `wrappers/flex-theme.sh` | ✅ cut over (M3; keybind → `flex-theme.sh`) |
| `power-menu.sh` (deleted 2026-09-15) | `power` | `wrappers/flex-power.sh` | ✅ cut over LAST (M6; `SUPER+M` + waybar `custom/power` → `flex-power.sh`, `DRY_RUN=1` blast-radius gate, `flex-tui.sh` deleted — zero sourcers remain) |
| `wallpaper-picker.sh` (delegating stub; `picker-chrome.sh` deleted 2026-09-15) | `wallpaper` | `wrappers/flex-wallpaper.sh` | ✅ cut over (keybind `SUPER+W` → `flex-wallpaper.sh`, fzf+`kitty icat` previews replaced by the kitty-graphics pane in `flex-core/src/preview.rs`, `set-wallpaper.sh` still owns the swap — image only, the theme is left alone) |
| `rofi/scripts/wifi.sh` (REMOVED 2026-09-15 with the whole `rofi` package) | `wifi` | `wrappers/flex-wifi.sh` | ✅ cut over (M8; Waybar `network` on-click → `flex-wifi.sh`; the rofi picker's signal bars/lock icons became the row metas, `nmcli` still owns every side effect) |

The superseded rofi pickers are gone: the `rofi` stow package was removed on
2026-09-15 (`stow -D rofi`), along with its `wifi.sh` stub and the `wifi.rasi`
/ `wifi-prompt.rasi` theme assets. `generate-theme.sh` and `theme-switcher.sh`
no longer link anything into `~/.config/rofi`, and RASI generation was dropped
entirely (`generate_rasi()`, the static-theme `colors.rasi` heredoc, the
saved-theme file list and the `theme-switcher.sh` validity check), so no
`colors.rasi`/`theme.rasi` remains in any saved theme.

Out of scope (not flex surfaces, left intact): `kill-menu.sh` (`SHIFT+Esc`,
htop-based, still uses `popup.sh`). `app-cache.sh` is kept as an orphaned
row-set reference (no functional sourcers since M5), and
`wallpaper-picker.sh` as a delegating stub to `flex-wallpaper.sh`.

## Image previews (`wallpaper`)

`flex wallpaper` is the only provider with a preview pane. `render` reserves
the right 45 % of the list area (dropped under 40 columns); `run` paints the
focused row's `Row::preview_image` there with kitty graphics protocol escapes
after every frame (`flex-core/src/preview.rs`) — no fzf, no icat, no image crate. PNG
sources are transmitted straight from disk (`t=f`); other formats are
converted once into `$XDG_CACHE_HOME/flex/previews` with ImageMagick
(`FLEX_PREVIEW_CONVERT`) and the PNG is reused afterwards. kitty stretches an
image to fill whatever `c`×`r` box it is given, so flex computes an
aspect-correct box from the PNG's `IHDR` dimensions and the terminal's cell
size (`TIOCGWINSZ`, via crossterm) and centres the image in the pane. Without a
kitty-compatible terminal (`FLEX_PREVIEW=1` overrides the detection) or with a
failing converter, the pane simply stays blank and the list still works.
