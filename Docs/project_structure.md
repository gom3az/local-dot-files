# flex — Project Structure

Conventions for the `flex/` tree in this repo — the rice-specific half of flex.
Read before running commands, creating files/folders, structural changes, or
adding dependencies.

## Where the two halves live

| Half | Carried by | Publishable |
|---|---|---|
| **`flex-core`** — the engine: menu rendering, fuzzy filtering, key handling, the design system, kitty-graphics previews | its own repository, [gom3az/flex-core], consumed here as a **git dependency pinned by tag** | Yes |
| **`flex-rice`** — this rice's eight providers, the `flex` binary and the shell wrappers | this repo, `flex/flex-rice/` | No (`publish = false`) |

Dependencies run one way (`flex-rice` → `flex-core`), now across a repository
boundary. `flex-core` must never gain a path back into this repo. The engine's
only former reach into a consumer's providers is the `Menu::on_tick` /
[`TickHook`] seam: the engine owns the tick, the caller supplies the refresh.
`flex-rice::tick_hook` refreshes `center` gauges and picks up a finished `wifi`
scan, and `flex-rice::menu(provider, tabs)` installs it — **use `menu()`
instead of `Menu::new` inside this repo**, or those two providers silently stop
refreshing.

## Crate layout

```text
flex/                        # cargo workspace root (one member — see below)
  Cargo.toml                 # members, shared deps (incl. the flex-core pin), lints, release profile
  Cargo.lock                 # COMMITTED (Q5) — pins the flex-core git revision
  rustfmt.toml               # mirror wiremix, max_width=100
  LICENSE-MIT
  LICENSE-APACHE
  CHANGELOG.md
  README.md                  # ACTION: protocol, wrapper recipes, cutover table

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

### Why the workspace root stays with a single member

`flex/` is a one-member workspace deliberately. The root is what pins `target/`
at `flex/target/` — the path `~/.local/bin/flex` resolves through — and it
keeps `flex-rice/wrappers/` exactly where the 13 keybind/Waybar/script
references and `tests/wrappers.rs` (`CARGO_MANIFEST_DIR/wrappers`) expect them.
Flattening `flex-rice/` up into `flex/` would move the wrappers and break every
config reference at once. That is not hypothetical: it happened in `04e2599`
and took out all seven keybinds.

## Conventions

1. **The engine never executes side effects.** `flex-core` only produces an
   `Outcome` (selected `Row` + `action_id`). Process spawn/exec, clipboard
   writes, shutdown, etc. live exclusively in `wrappers/*.sh` (M4), which parse
   the single `ACTION:` stdout line.
2. **Binary prints exactly one `ACTION:` line** to stdout on success
   (`ACTION: <provider> <action_id> <escaped-label>`). All diagnostics go to
   stderr via `eprintln!`/`anyhow`. Exit codes: `0` = action, `130` = cancel,
   `1` = error (the contract lives in `flex-core/src/backend.rs`).
3. **Providers parse subprocess stdout once.** At most one child spawn per
   invocation; read stdout to `Vec<Row>` up front; filter/render in-process after
   that. No re-spawning per keystroke. Two documented exceptions, both driven by
   the `TickHook` seam: `center`'s 1 s gauge tick re-reads `wpctl`/`brightnessctl`
   in place (Q7), and `wifi` opens from the cached scan and runs **one**
   background scan whose rows replace the list on a later tick (a triggered
   `nmcli` scan blocks ~3 s, which would leave the popup blank until it returned).
3b. **Image previews are the one out-of-band surface** (`flex-core/src/preview.rs`).
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
5. **`target/` gitignored.** `.gitignore` carries `flex/target/`; never commit
   build artifacts. `Cargo.lock` IS committed (Q5) — it is also what pins the
   exact `flex-core` git revision.
   **Stow ignore files are per-package, not per-repo.** Verified against stow
   2.4.1: `stow -vvvv` prints "Using built-in ignore list" even with a
   root-level `.stow-local-ignore` present, because stow searches for
   `<stow-dir>/<package>/.stow-local-ignore`. The root file is therefore inert
   — a real trap, since its `flex/target/` line looks like it works. Working
   lists live inside the packages that need them: `kitty/.stow-local-ignore`
   (`current-theme.conf`) and `waybar/.stow-local-ignore` (`theme.css`,
   `waybar-fonts.css`) keep the theme generator's files out of stow's way so
   `stow -R kitty waybar` does not abort. Pattern semantics: a pattern with no
   `/` is matched against the **basename** (stow anchors it automatically); a
   pattern containing `/` is matched against the full path prefixed with `/`,
   so `^package/...$` can never match. A package's own ignore file is always
   ignored from stowing.
6. **No `serde`/`toml` in v1.** CI grep gate rejects them:
   `! rg -l '"serde"|"toml"|serde::|toml::' flex-rice/src flex-rice/tests`.
   Config is CLI flags + hardcoded `Theme` only.
7. **Deterministic tests via `FLEX_TEST`.** When `FLEX_TEST=1`, RNG/time seeds are
   fixed (M1) so golden/key tests are reproducible.
8. **Lints deny by default.** `[workspace.lints]` in the root `Cargo.toml`
   (`unsafe_code` deny; clippy all+pedantic deny) with `[lints] workspace = true`
   in the member; `cargo clippy --all-targets -- -D warnings` must pass. The
   engine enforces the same lints in its own repo.
9. **Formatting:** `cargo fmt --all --check` green; `rustfmt.toml max_width=100`.
10. **Single `crossterm` major.** `ratatui 0.29` pulls `crossterm`; no other dep may
    pull a second major. Verify with `cargo tree -i crossterm` / `cargo tree | rg crossterm`.

## Working on the engine

`flex-core` is a separate repository, so iterating on it takes one extra step.
Clone it beside dotfiles and patch it in **without committing the override**:

```sh
git clone https://github.com/gom3az/flex-core ~/projects/flex-core
```

Then add to `flex/Cargo.toml` (temporarily) or an uncommitted
`flex/.cargo/config.toml`:

```toml
[patch."https://github.com/gom3az/flex-core"]
flex-core = { path = "../../projects/flex-core" }
```

`cargo update -p flex-core` picks it up. Remove the override before committing.

**Releasing an engine change:** merge it in the flex-core repo, tag it, then bump
`tag = "v…"` under `[workspace.dependencies]` here and run
`cargo update -p flex-core`, which rewrites `Cargo.lock` to the new revision.

## Commands (run from `flex/` unless noted)

- `cargo fmt --all --check`
- `cargo clippy --all-targets -- -D warnings`
- `cargo test` — the rice half (222 tests). The engine's 109 tests run in its own
  repo; together they are the 331 the pre-split workspace ran.
- `cargo build --release` → `target/release/flex` (what the wrappers exec)
- `cargo tree -i crossterm` (single-major check)
- `cargo bench --bench rerank` — lives in `flex-core` now
- Negative-dependency gate: `! rg -l '"serde"|"toml"' flex-rice`

## Stow integration

`flex/` lives inside the dotfiles repo (stow package layout). `flex/target/`
must be in `.stow-local-ignore` so `stow flex` never symlinks build output.
Wrappers are the stow-deployed entry points consumed by Hyprland keybinds.

[gom3az/flex-core]: https://github.com/gom3az/flex-core
[`TickHook`]: https://github.com/gom3az/flex-core/blob/main/src/lib.rs
