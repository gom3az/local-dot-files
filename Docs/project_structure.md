# flex — Project Structure

Conventions for the `flex/` workspace. Read before running commands, creating
files/folders, structural changes, or adding dependencies.

## Crate layout

```text
flex/                        # cargo workspace root
  Cargo.toml                 # [workspace] members, shared deps/lints, release profile
  Cargo.lock                 # COMMITTED (Q5 — binary ships; reproducible builds)
  rustfmt.toml               # mirror wiremix, max_width=100
  LICENSE-MIT
  LICENSE-APACHE
  CHANGELOG.md
  README.md                  # ACTION: protocol, wrapper recipes, cutover table

  flex-core/                 # the reusable engine — publishable, no machine paths
    Cargo.toml               # metadata inherited from [workspace.package]
    LICENSE-MIT              # copied in so `cargo package` ships the licences
    LICENSE-APACHE
    src/
      lib.rs                 # pub Row/Tab/Mode/Outcome/Theme/App/Menu + TickHook
      backend.rs             # /dev/tty alt-screen init/restore; ACTION: writer; exits 0/130/1
      filter.rs              # hand-rolled fuzzy (~150 lines, TODO M1)
      keys.rs                # key priority chain (TODO M1)
      render.rs              # row layout widgets (TODO M1)
      width.rs               # unicode-width 0.2 truncation (TODO M1)
      theme.rs               # hardcoded Theme tokens (TODO M1)
      charset.rs             # glyph sets (default/compat/extracompat)
      meter.rs               # peak meter (hidden/normal/mono)
      preview.rs             # kitty graphics pane: geometry, escapes, PNG cache (M7)
      run.rs                 # TUI event loop
    tests/
      compliance.rs          # upstream (wiremix) design-system compliance
      dropdown.rs            # target dropdown replays
      golden.rs              # NOTE: lives in flex-rice (builds provider menus)
      keys.rs                # (M1) Q1/Q6/danger-timing state machine
      fuzzy_corpus.rs        # (M1) tier/penalty regression corpus
      dwidth.rs              # (M1) display-width fixtures
    benches/
      rerank.rs              # (M1 skeleton, M5 regression) criterion 10k rerank

  flex-rice/                 # this rice's glue — machine-specific, never published
    Cargo.toml               # publish = false; [[bin]] name = "flex"
    src/
      lib.rs                 # pub mod providers + re-exported menu()/tick_hook()
      main.rs                # clap power|launch|shot|theme|clip|center|wallpaper|wifi; prints ACTION:
      providers.rs           # module list + the per-tick refresh dispatcher
      providers/
        power.rs
        launch.rs
        clip.rs
        center.rs
        shot.rs
        theme_.rs            # `theme` is a crate-adjacent ident; file uses trailing underscore
        wallpaper.rs         # image scan + kitty-graphics preview rows (M7)
        wifi.rs              # radio/scan rows for the network dialog (M8)
    tests/
      golden.rs              # TestBackend goldens (empty tab bar M0; +danger/gauge/trunc M3)
      center.rs              # per-tab fixtures, gauge tick, TARGET/Action reporting
      clip.rs                # history rows, resolve round-trip, real-binary E2E
      clip_perf.rs           # (M1 spike, gated M5) 10k-row perf budget
      power.rs               # DRY_RUN gate + stubbed-PATH dispatch
      shot.rs                # stubbed pipeline dispatch
      theme.rs               # theme rows + switcher dispatch
      wallpaper.rs           # (M7) scan parity, pane geometry, wrapper dispatch
      wifi.rs                # (M8) radio/scan rows, live seams, wrapper dispatch
      wrappers.rs            # bind-path contract: executable + popup-wrapped
      fixtures/              # captured subprocess stdout per provider (M2)
        center/
        launch/
        wifi/                # radio + nmcli snapshots for the network dialog (M8)
    wrappers/
      flex-power.sh flex-launch.sh flex-clip.sh flex-center.sh
      flex-shot.sh flex-theme.sh flex-wallpaper.sh flex-wifi.sh
```

The split is the one that matters for reuse:

- **`flex-core`** is the engine. It has no knowledge of any particular desktop
  setup, so it can be extracted to its own repository and published untouched.
- **`flex-rice`** reads *this* machine: `~/.config/themes`,
  `~/.config/hypr/hyprpaper.conf`, `~/.cache/cliphist`, `~/Pictures/Wallpapers`
  and ML4W's wallpaper cache. It is `publish = false` by design.

Dependencies run one way (`flex-rice` → `flex-core`), and `flex-core` must
never gain a path back. The engine's only former reach into providers was
`Menu::tick`'s hardcoded dispatch, now inverted: the engine calls a
[`TickHook`] supplied by the caller. `flex-rice::tick_hook` refreshes `center`
gauges and picks up a finished `wifi` scan, and `flex-rice::menu(provider,
tabs)` installs it — **use `menu()` instead of `Menu::new` inside this repo**,
or those two providers silently stop refreshing.

`src/providers/theme_.rs` note: the module is declared as
`#[path = "providers/theme_.rs"] pub mod theme_;` to avoid confusion with
`crate::theme`. Rename only with a plan update.

## Conventions

1. **The engine never executes side effects.** `flex-core` only produces an
   `Outcome` (selected `Row` + `action_id`). Process spawn/exec, clipboard writes,
   shutdown, etc. live exclusively in `wrappers/*.sh` (M4) which parse the single
   `ACTION:` stdout line.
2. **Binary prints exactly one `ACTION:` line** to stdout on success
   (`ACTION: <provider> <action_id> <escaped-label>`). All diagnostics go to
   stderr via `eprintln!`/`anyhow`. Exit codes: `0` = action, `130` = cancel,
   `1` = error (`flex-core/src/backend.rs` owns this contract).
3. **Providers parse subprocess stdout once.** At most one child spawn per
   invocation; read stdout to `Vec<Row>` up front; filter/render in-process after
   that. No re-spawning per keystroke. Two documented exceptions, both driven by
   the `TickHook` seam: `center`'s 1 s gauge tick re-reads `wpctl`/`brightnessctl`
   in place (Q7), and `wifi` opens from the cached scan and runs **one**
   background scan whose rows replace the list on a later tick (a triggered
   `nmcli` scan blocks ~3 s, which would leave the popup blank until it returned).
3b. **Image previews are the one out-of-band surface (`flex-core/src/preview.rs`).**
   The `wallpaper` provider's pane is painted after each frame with kitty
   graphics protocol escapes written to a second `/dev/tty` handle (never
   through the ratatui buffer, so `render` stays ANSI-free and goldens stay
   pixel-exact), and non-PNG sources are converted once into
   `$XDG_CACHE_HOME/flex/previews` by ImageMagick (cached by path+mtime+size).
   Both are display-only: no provider row, id, label, filter or `ACTION:` line
   depends on them, and every failure (no kitty, no converter, unwritable
   cache) degrades to a blank pane plus one stderr line.
4. **`RowId` hash hex for clipboard (Q2).** `clip` rows use
   `action_id = hex(blake/simple-hash(content))` — stable across runs so wrappers
   can round-trip history entries. `wallpaper` reuses it over the absolute
   path and adds a hidden `--resolve` lookup, since paths contain spaces.
   (Hash fn: std-only in v1, no extra deps.)
5. **`target/` gitignored + stow-ignored.** Entries required in both
   `.gitignore` and `.stow-local-ignore`: `flex/target/`. Never commit build
   artifacts. `Cargo.lock` IS committed (Q5). The workspace keeps the build at
   `flex/target/`, so `~/.local/bin/flex` keeps resolving through the split.
6. **No `serde`/`toml` in v1.** CI grep gate rejects them:
   `! rg -l '"serde"|"toml"|serde::|toml::' flex-core/src flex-core/tests
   flex-core/benches flex-rice/src flex-rice/tests`.
   Config is CLI flags + hardcoded `Theme` only.
7. **Deterministic tests via `FLEX_TEST`.** When `FLEX_TEST=1`, RNG/time seeds are
   fixed (M1) so golden/key tests are reproducible.
8. **Lints deny by default.** `[workspace.lints]` in the root `Cargo.toml`
   (`unsafe_code` deny; clippy all+pedantic deny) with `[lints] workspace = true`
   in both members; `cargo clippy --all-targets -- -D warnings` must pass.
9. **Formatting:** `cargo fmt --all --check` green; `rustfmt.toml max_width=100`.
10. **Single `crossterm` major.** `ratatui 0.29` pulls `crossterm`; no other dep may
    pull a second major. Verify with `cargo tree -i crossterm` / `cargo tree | rg crossterm`.

## Commands (run from `flex/` unless noted)

- `cargo fmt --all --check`
- `cargo clippy --all-targets -- -D warnings`
- `cargo test` (both crates); `cargo test -p flex-core` / `-p flex-rice` to scope
- `cargo build --release` → `target/release/flex` (what the wrappers exec)
- `cargo tree -i crossterm` (single-major check)
- `cargo bench -p flex-core --bench rerank` (M5)
- Negative-dependency gate: `! rg -l '"serde"|"toml"' flex-core flex-rice`

## Stow integration

`flex/` lives inside the dotfiles repo (stow package layout). `flex/target/`
must be in `.stow-local-ignore` so `stow flex` never symlinks build output.
Wrappers are the stow-deployed entry points consumed by Hyprland keybinds.

[`TickHook`]: flex-core/src/lib.rs
