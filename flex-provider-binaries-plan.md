# Plan: per-provider Rust binaries, zero bash in the flex call path

**Status:** ✅ COMPLETE — all phases landed and pushed, 2026-09-16
(flex `bdecae8`, dotfiles `7946d61`; wrappers retired, zero bash in the flex call path; a
post-migration diagnostic-abort regression was found live and fixed — see "Verification")

**Post-review completion (working tree, uncommitted).** A follow-up review found three
target-shape/verification items still open; all are now implemented and the workspace
gates are green (`cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`,
`cargo test --locked` 492 passed, `./setup.sh --check`):
- The hidden `flex <provider> --resolve` CLI is removed from the dispatcher; the executors
  resolve row ids in-process through the library resolvers, and the B-021 tests exercise
  the resolver functions directly.
- The `ImageBackend` seam and the full `FLEX_PREVIEW` contract (`auto` default | `kitty` |
  `off`, legacy `0`/`1`, `sixel` diagnosed as not implemented and treated as `off`) are
  implemented in `flex-core/src/preview.rs`.
- `setup.sh --check` now verifies each of the nine links resolves into the current
  `target/release`, and the two missing gates are tested (per-variant cross-provider toggle
  identity; dispatcher/provider `--print-action` parity). A latent `ETXTBSY` race in the
  stub-`PATH` tests was fixed with a bounded retry at the popup exec sites.
- **"Port the legacy flows in scope" finished** (was listed under Scope/Costs but left as
  subprocess seams): `set-wallpaper.sh` and `theme-switcher.sh` (including `list`, `current`,
  `activate`, `delete` verbs) are fully ported into `flex-rice/src/exec/{wallpaper,theme}.rs`
  (shared by `flex-center`'s theme arm), with `SET_WALLPAPER`/`THEME_SWITCHER` demoted to
  override-only seams. The standalone bash scripts have been retired/deleted from dotfiles; the
  verbs are now handled directly by the Rust binaries.

**Supersedes:** the "Full plan: per-provider Rust binaries, zero bash at runtime" draft
**Companion:** `flex-monorepo-plan.md` (the move to `gom3az/flex`, already executed)

## Recommendation

Do it. The draft's direction is sound and its load-bearing claims verify: nothing outside the
eight wrappers parses `ACTION:` (grep across `dotfiles` returns zero consumers, and the eight
wrappers are the only hits for `ACTION` anywhere), `popup.sh` is a real choke point, and the
`~/.local/bin` farm already exists and is live. Two corrections are structural and are folded
into the phases below; four are contract-level.

### Decisions locked

1. **8 separate `[[bin]]` targets**, one per provider — kept as drafted. Consequences are priced
   in Phase 0 (shared runner, per-binary prefix tests, per-binary `CARGO_BIN_EXE_*` test sites).
2. **Keep `--print-action`.** Justification corrected (see C1): it is a *new* end-to-end probe of
   the row→action mapping without a pty, not a preservation device for an existing suite.
3. **Rust toggle helper**, terminal-agnostic spawning via `TERMINAL`.
4. **Port the legacy flows in scope**: `popup.sh`, theme-activate, `set-wallpaper.sh`.
5. **Kitty-only terminal template in this plan.** The template table is the extension point;
   foot/wezterm/ghostty land when a machine can run them.
6. **Sixel deferred.** `FLEX_PREVIEW=sixel` is accepted, diagnosed as unimplemented, and treated
   as `off` so a stale config cannot break the picker.

---

## Corrections to the draft

**C1 — `--print-action` does not preserve the selection suite, and the dispatch suite never
needed it.** B-020/B-022/B-027 are stderr probes run against the real binary
(`tests/launch.rs:193,643`, `tests/clip.rs:712`, `tests/wallpaper.rs:649`); they never touch
`ACTION:`. The row and golden suites are unit-level against providers and are indifferent to this
architecture. The dispatch tests already are executor-in-isolation tests: they stub `flex` on
`PATH` with a script that echoes the action line and run the wrapper under `bash` with
`POPUP_KITTY=1` (`tests/power.rs:397-405`, `tests/wifi.rs:915-919`). Keep the flag, describe it
honestly: it probes the real binary's row→action mapping with no pty. It does not carry the
suite, and nothing else in the plan should lean on it.

**C2 — executors go in the library, not in the binaries.** Integration tests can reach
`flex_rice` only; `src/bin/*.rs` is not importable. "Dispatch tests become Rust tests against
executor fns" is achievable only with `flex-rice/src/exec/*.rs` exposing
`pub fn run(action: &Action) -> Result<()>`. Convention #1 forbids the **engine** (`flex-core`)
from executing; the rice's executor module does not violate it, and the draft's reason for
putting executors in the binaries was unnecessary. Each binary stays thin: argv → shared runner →
select → `exec::<provider>::run`.

**C3 — `popup.sh` is a dotfiles file, and a script the draft keeps in bash depends on it.**
`scripts/.config/scripts/kill-menu.sh:7` execs `$HOME/.config/scripts/popup.sh menu-wide "$0" "$@"`,
reachable from the bind at `hyprland.lua:213` (SUPER+SHIFT+Escape). The draft put `popup.sh` in the
port bucket and `kill-menu.sh` in "stays bash, out of scope" — a `flex-rice` module is not callable
from a shell script, so that bind dies at decommission. The decommission line "delete …
`popup.sh`-in-flex-path" is also wrong about where the file lives. Fix: the shared helper is
exposed as `flex popup <variant> <cmd…>` on the compat dispatcher and `kill-menu.sh:7` changes one
line. `hyprland.lua:286` and `themes/.config/themes/WORKFLOW.md:123` get doc updates.

**C4 — the single-`flex: error:` invariant becomes an 8-way invariant.** B-022/B-027's contract is
"`main` owns the prefix exactly once" (`main.rs:134-143`, locked by whole-stderr-line comparisons).
With 8 binaries, define the prefix once in a shared runner (`flex_rice::runner`, used by all 8 and
by the dispatcher) and parametrise the B-027 lock test over all 8 binaries. Also note
`[profile.release] panic = "abort"` plus `unsafe_code = "deny"` in the workspace root: a panic in
an executor aborts with no unwinding, so no `Drop` cleanup runs. Executor code must therefore be
panic-free — no `unwrap`, no indexing, no slicing — as an explicit review rule, since clippy does
not enforce it.

**C5 — the terminal helper must not fail closed on an ambient variable.** `TERMINAL` is unset in a
plain shell on this host and is settable by anything. "Unknown → diagnostic + exit 1" turns someone
else's value into a dead keybind, and a classless spawn also misses the float rule. Locked
behaviour: match on the **basename** against the template table; unknown or empty → warn on stderr
and use the kitty template. `hyprland.lua:56` (`local terminal = "kitty"`) reads the exported value
instead of keeping a second copy of the fact.

**C6 — the toggle identity must be chosen, not inherited.** Today four providers share variant
`menu` and four share `menu-wide` (`tests/wrappers.rs`), and `popup.sh` toggles on the **variant**,
so pressing SUPER+T with the power popup open closes the power popup and does not open themes.
That is live behaviour. A per-binary rewrite naturally produces a per-provider class and silently
changes it. **Locked: preserve today's semantics exactly** — class `flex-menu` / `flex-menu-wide`,
toggle keyed on the variant, one test per variant. Per-provider classes are a separate, optional UX
change, not part of this plan.

**C7 — the dotfiles rewire inventory is mandatory.** The draft changes the same 13 live references
that `04e2599` had to fix, and does not enumerate them. See Phase 2; `git show 04e2599` is the
checklist and the click-through is the only real proof.

---

## Target shape

```
SUPER+X → ~/.local/bin/flex-center ──→ target/release/flex-center (ELF)
                                             ├─ runner (shared: error prefix, exit codes)
                                             ├─ popup::toggle (pgrep → pkill | spawn)
                                             ├─ providers::center select  (library)
                                             └─ exec::center::run         (library)
```

- **9 shipped entry points**: `flex` plus `flex-{power,launch,shot,theme,clip,center,wallpaper,wifi}`.
- **`flex` survives as a thin compat dispatcher**, not a second interface: `flex popup <variant> <cmd…>`
  and `flex <provider> [args…]` re-exec the matching `flex-<provider>`. It keeps `kill-menu.sh`
  working (C3), keeps the documented `flex` path in `README.md`, and owns no provider logic.
  - The dispatcher must normalise global-flag order: `flex -t nocolor launch` and
    `flex launch -t nocolor` both have to reach `flex-launch` with an equivalent argv. Parse with
    clap and reconstruct in canonical order; test all four orders plus `--help`/`--version`.
- **`ACTION:` / `--resolve` as a wire protocol is deleted.** Nothing external parses either once
  the eight wrappers are gone. The resolvers become plain library functions; hash ids stay as the
  `--print-action` contract and as the B-021 invariant. `--resolve` vanishes from the CLI, so the
  B-021 round-trip tests (`space_bearing_desktop_ids_round_trip_through_resolve`) are re-expressed
  against the resolver functions — which requires C2.
- **Farm directory unchanged in shape**: 8 binary symlinks + `flex`, recreated by `setup.sh`, which
  gains a `--check` mode asserting all 9 links resolve into the current `target/release`.

### Shared library modules (`flex-rice`)

| Module | Contents |
|---|---|
| `runner` | the single `flex: error: {err:#}` owner, `EXIT_ERROR`/`EXIT_CANCELLED` mapping, the shared entry point all 8 binaries and the dispatcher call (C4) |
| `terminal` | `detect()` reads `TERMINAL`, basename-matches a template table, falls back to kitty with a warning (C5). Kitty template: `--class flex-<variant> -o font_size=10`, `-e <cmd>`, `POPUP_KITTY=1` in the child env. Table is the extension point; foot's missing per-popup font size is documented there for later |
| `popup` | `toggle(variant)`: `pgrep -f "<class> "` → `pkill`, else spawn detached; the `POPUP_KITTY` re-entry guard. Semantics per C6 |
| `exec::*` | one module per provider, porting the wrapper logic (C2). Env seams stay as they are: `NMCLI`, `BLUETOOTHCTL`, `WPCTL`, `NOTIFY_SEND`, `THEME_SWITCHER`, `SET_WALLPAPER`, `DRY_RUN`, `FLEX_WIFI_PASSWORD`, `FLEX_CENTER_PASSWORD`, `SCREENSHOT_DIR`, `RECORDING_START`, `CLIPHIST_FILE`/`PINS` |

Two deliberate CLI passthroughs, both forced by `unsafe_code = "deny"` (no `libc` `setsid`/`termios`):
`setsid -f` for session detach and `stty -echo` for the wifi prompt. Both are subprocess calls, not
shell invocations — "zero bash" is not "zero `exec`"; say so explicitly in `README.md`.

### Preview backends (`flex-core`)

Untouched: geometry (`pane`/`fitted_box`/`placement`, `preview.rs:106,129,181`), sync dedup, cache
keying, `cell_size`. The kitty encoder moves into an `ImageBackend` seam **with one implemented
variant**; a single-variant enum is speculative generality, so introduce the seam, not the enum.
`FLEX_PREVIEW` accepts `auto` (default) | `kitty` | `off`, keeps the legacy `0`/`1` values
(`preview.rs:79-86`), and answers `sixel` with `flex: preview: sixel backend not implemented` and
behaves as `off`. Zero new crate dependencies.

---

## Pilot: `flex-shot` (Phase 1)

`flex-shot.sh` (111 lines) is the right pilot — static rows, non-destructive, and it exposes the
four seams the rest of the port needs:

1. **It generates a bash script and runs it** (`flex-shot.sh:31-71`, executed at `:86` as
   `setsid --fork bash "$cap_script"`). The port replaces the generated script with direct
   `Command` invocations and deletes the temp-file/trap machinery entirely.
2. **`win-shot` shells out to `jq`** (`flex-shot.sh:49`, `hyprctl -j activewindow | jq`). There is
   no std-only JSON path. Decide here: add `serde_json` to `[workspace.dependencies]`, or parse
   `hyprctl activewindow` text output and keep a golden test on both formats. This is a Phase 0
   decision that the draft did not price.
3. **The popup-wait loop runs `python3` inline** (`flex-shot.sh:96-109`, `hyprctl clients -j` +
   a Python one-liner). Replace with the `pgrep -f "<class>"` poll the toggle helper already uses,
   bounded at 20 × 50 ms so the existing 1 s cap is preserved.
4. **Three hardcoded class sites** (`flex-shot.sh:90` `pgrep -f 'kitty --class kitty-menu'`,
   `:101` substring match, `popup.sh`, `hyprland.lua:289,295`). Note the latent bug in the `:101`
   substring match: `'kitty-menu' in class` also matches `kitty-menu-wide`. Fix it as part of the
   rename rather than porting it.

### Pilot outcome (landed as flex `2845243`, reviewed, gates green)

- **JSON decision: std-only byte scanner, no `serde_json`.** `exec::shot::active_geometry`
  parses `"at"`/`"size"` pairs panic-free from `hyprctl -j activewindow`; unparsable output
  errors instead of capturing the wrong region (the wrapper's broken `jq` quoting meant every
  `win-shot` ran `grim -g ""` — fixed in the port, wrapper untouched).
- **Generated script, `jq`, `python3` all gone.** Direct `Command` spawns from a pure
  `plan(id) -> Vec<Step>`; the popup-wait is the toggle helper's `pgrep` poll (20 × 50 ms).
  Exact-class match via the shared `popup::match_pattern` (fixes the `-wide` collision).
- **Hidden `--capture` worker pattern** (the template for popup-death survival): parent stages
  `SCREENSHOT_DIR`/timestamp, detaches via `setsid -f <self> --capture ID FILE REC`, closes the
  popup, exits 0 — it no longer `wait`s the capture. Worker exit 130 on `slurp` cancel, quietly
  (the wrapper's `set +e` fell through to `wl-copy`/`notify-send`).
- **Snapshot convention** (copy for the next 7): `describe` lines (`grim -g <slurp> FILE`,
  `wl-copy < FILE`, `REC [-a] [-g GEOM] FILE` with `<slurp>`/`<window>` placeholders); unit
  tests pin the lines, integration tests diff stub-`PATH` call logs against the same shapes.
- **Second live wrapper bug fixed in the port:** all four recording arms invoked `"$4"` with
  only 3 args (`: command not found`) — recordings never ran. Wrapper untouched.
- **Test seam:** side-effect fns take `path_env: Option<&str>` (stub `PATH` without touching
  process env); `execute` (env/clock) vs `execute_with` (pure inputs) split.

---

## Phases

**Phase 0 — scaffolding.** ✅ DONE (flex `2845243`, dotfiles `db4f52a`). `runner`, `terminal`,
`popup` with a stub-`PATH` seam (no live `pgrep` in tests); the 8 `[[bin]]` targets and the `flex`
dispatcher (`popup` toggle, canonical re-exec, `--resolve` inline); `setup.sh` + `--check`;
`--print-action` plumbed through the runner; `flex popup` exposed; JSON decision deferred to the
pilot (see outcome above). Dotfiles side: `TERMINAL` exported (Lua local is the single source),
class rename `kitty-menu(-wide)` → `flex-menu(-wide)` across `hyprland.lua`, `popup.sh`, and
`kill-menu.sh:7` repointed at `flex popup`. Follow-up found in pilot review and fixed in the same
flex commit: the still-live `flex-shot.sh:90,101` referenced the old classes (it could no longer
find/close its own popup) — swapped to `flex-menu*`, wrapper behaviour otherwise byte-identical.

**Phase 1 — pilot `flex-shot`.** ✅ DONE (flex `2845243`). Static rows, stubbed tools, no
destructive actions. Proved the binary shape, the popup helper, the runner's prefix contract, and
the test pattern (dispatch tests are library-level tests against `exec::shot` with the same PATH
stubs). Template for the remaining 7 is the pilot-outcome section above.

**Phase 2 — rollout, power LAST.** ✅ DONE. `theme` → `wallpaper` (kitty encoder already lived in
`flex-core/src/preview.rs`; nothing moved) → `launch` → `clip` (first provider with live
`Delete`/`Toggle`) → `center` (largest: wpctl/bt/nmcli/power/theme in one executor) → `wifi`
(`stty` prompt + saved-profile flow) → `power` (double-Enter untouched, `DRY_RUN=1` reimplemented
in Rust). Each provider committed independently, CI green throughout; every executor parity-proved
against the untouched wrapper (tool-call sequences byte-compared, dry-run lines byte-compared for
power) before the wrapper was retired. Commits: `cbd47a4` (theme+wallpaper), `2675936`
(launch+clip), `0a5bb5f` (center), `6fee887` (wifi), `ba491a9` (power).

Wifi preserved all three documented behaviours from `flex-wifi.sh:149-161`: the prompt goes to
**stderr**, the read **falls back to stdin** when `/dev/tty` is unavailable, and an empty answer
prints the explicit `No password entered …` line. `stty` with stdin wired to `/dev/tty`; echo is
restored on every normal exit path, and the abort-mid-prompt risk is documented (`panic = "abort"`,
so reads return `Option`, never panic). The same prompt shape is shared by `center`'s secure-wifi
arm.

Two live wrapper bugs were found during the ports and fixed in Rust (the wrappers were left
untouched): `flex-shot.sh`'s `win-shot` `jq` quoting made every window capture run `grim -g ""`,
and all four recording arms invoked `"$4"` with only 3 arguments, so recordings never ran.

**Phase 3 — decommission.** ✅ DONE (flex `133efd2` code, `99870af` docs; dotfiles `7946d61`).
- Deleted `flex-rice/wrappers/` (8 scripts + `.gitkeep`) and `tests/wrappers.rs`; the `--help`
  contract lives on in `tests/entrypoints.rs`, and the wrapper-dispatch/parity tests were dropped
  since the executor tests are the surviving coverage (479 passed, 1 ignored). The shellcheck CI
  step is retired (no `.sh` remains in the repo); `dotfiles` retains only standalone scripts
  like `kill-menu.sh`, `cliphist.sh`, `audio-mixer-toggle.sh` (`theme-switcher.sh` and
  `set-wallpaper.sh` were deleted/superseded by Rust).
- Dotfiles rewiring (the `04e2599` hazard) done in `7946d61`: 8 binds, 2 Waybar on-clicks, 3
  script delegations, `popup.sh` deleted (orphaned), the 8 stale `~/.local/bin/flex-*.sh` links
  removed, `README.md` + `WORKFLOW.md` updated.
- Docs updated: `README.md`, `CHANGELOG.md`, `Docs/Implementation.md`, `Docs/Bug_tracking.md`
  (B-004 `Closed (retired)`), `Docs/project_structure.md`, plus in-code comments.

Live verification: `hyprctl reload` → `ok`; all 9 `~/.local/bin/flex*` links resolve; `rg` finds
no `flex-*.sh`/`popup.sh` reference anywhere in dotfiles (outside this plan).

---

## Phase 2 detail — dotfiles rewiring (the `04e2599` hazard)

✅ DONE (dotfiles `7946d61`). Every reference below was live and moved from `.sh` to the binary
name in one pass; `git show 04e2599` documents what happens when one is missed.

| Consumer | Path:line |
|---|---|
| Hyprland binds (8) | ✅ `hypr/.config/hypr/hyprland.lua` (shot/power/center/launch×2/wallpaper/theme/clip) |
| Waybar on-clicks | ✅ `waybar/.config/waybar/config.jsonc` (wifi + custom/power) |
| Script delegation | ✅ `scripts/.config/scripts/{cliphist,theme-switcher,wallpaper-picker}.sh` |
| Popup helper | ✅ `scripts/.config/scripts/kill-menu.sh:7` → `flex popup menu-wide` (dotfiles `db4f52a`) |
| Farm symlinks (9) | ✅ `~/.local/bin/flex` + `flex-{power,launch,shot,theme,clip,center,wallpaper,wifi}`; the 8 stale `.sh` links removed |
| Docs | ✅ `themes/.config/themes/WORKFLOW.md`, `README.md` (both repos) |

`kill-menu.sh`, `cliphist.sh`, `audio-mixer-toggle.sh` keep their `.sh` names — those scripts stay.

---

## Verification

Per provider: `cargo fmt --all --check`, `cargo clippy --locked --all-targets -- -D warnings`, full
suite (row/golden suites untouched; dispatch coverage ported 1:1, same cases, new harness),
headless `setsid` matrix, scratch-`HOME` live-action smoke, then the real-machine bind click-through.

New gates this plan adds, all of which the draft's shape would fail as written:

- **Prefix contract × 8**: the B-027 lock runs against all 8 binaries and asserts one
  `flex: error:` per line (C4).
- **Runner/shape**: every binary answers `--help` with exit 0; `flex <provider>` and `flex-<provider>`
  produce identical `--print-action` output for the same environment.
- **Dispatcher flag order**: `flex launch`, `flex -t nocolor launch`, `flex launch -t nocolor`,
  `flex --version`.
- **Toggle identity**: one test per variant asserting a second invocation of a *different* provider
  sharing the variant closes rather than stacks (C6, today's behaviour).
- **Terminal resolution**: `TERMINAL` unset, empty, `kitty`, `/usr/bin/kitty`, and an unknown value
  all resolve; the unknown case warns rather than exits (C5).
- **`setup.sh --check`** passes against a fresh `target/release`.
- **Panic-freedom review** of every executor module: no `unwrap`/index/slice on external data (C4).

Final sweep: `rg '\.sh'` in the binds and Waybar config returns nothing for the flex call path;
`rg 'kitty'` in `flex-rice` returns only the terminal template, the app-launch terminal branch
(see below), and comments.

Two terminal branches were left outside the sweep until later: `flex-launch.sh:58` and
`flex-center.sh:87` hardcoded `setsid -f kitty -e` for `Terminal=true` desktop entries. ✅ DONE
(flex `8cefbc2`): `exec::launch` and `exec::center` now route those through
`terminal::exec_argv` (`<terminal> -e <cmd…>`, no popup class/marker), so terminal apps follow
`$TERMINAL`; `detect()` is read only for `Terminal=true` entries, so a plain GUI launch never
consults the variable.

**Post-migration live regression (flex `8cefbc2`).** A Waybar started before
`hl.env("TERMINAL", …)` kept a **deleted** `/dev/pts/N` on fd 2 and had no `TERMINAL`, so every
`flex-wifi`/`flex-power` on-click hit `terminal::detect()`'s warning, the `eprintln!` write failed
with `EIO`, and — because `eprintln!` panics on write failure and the release profile is
`panic = "abort"` — the provider died with SIGABRT **before spawning its popup**. The bash wrappers
never had this failure mode (they hardcoded kitty and bash ignores write errors). Fixed by routing
all runtime diagnostics through `flex_core::diag` (`warn`/`warn_inline`/`note`), which discard the
write error; locked by `flex-rice/tests/diagnostics.rs` (`/dev/full` on stderr must exit 1, not die
by signal). Immediate mitigation was restarting Waybar so it inherits `TERMINAL=kitty` and a
writable stderr.

---

## Costs restated

- **8 binaries preserve an install indirection** — zero bash is the win, not fewer paths. Contained
  by `setup.sh`, but note the real bill with `lto = true`/`strip = true` at the workspace root:
  8× release build time, ~8× artifact size, and every `cargo build --release` invalidates all 9
  `~/.local/bin` symlink targets at once.
- **Theme / `set-wallpaper.sh` ports fork tested behaviour.** Parity-prove each behind the existing
  stub seams (`THEME_SWITCHER`, `SET_WALLPAPER`) before cutover, in the same commit.
- **`set-wallpaper.sh` is not small**: `socat` to the hyprpaper socket, a `pgrep -x` liveness probe,
  a restart path, a `hyprpaper.conf` rewrite, the ML4W cache write, and paired `swaync-client`
  inhibitor calls. Port it verbatim and keep a parity test on the conf bytes it writes.
- **"Zero bash at runtime" is really "zero bash in the flex call path."** State it that way.
- **Revisited frozen items**: convention #1 (the *engine* still never executes — executors are rice
  code), B-021 resolvers (internalised as library functions), B-004 shellcheck gate (retired with
  the wrappers).

---

## Risks

| Risk | Mitigation |
|---|---|
| **Missed `.sh` → dead keybind** (the `04e2599` failure) | The Phase 2 table is the checklist; the click-through is the only real proof |
| **`kill-menu.sh` breaks at decommission** | `flex popup` on the dispatcher, one-line repoint, `hyprland.lua:213` smoke in the click-through |
| **Silent toggle-UX change from per-provider classes** | C6 locks per-variant semantics with a test |
| **Dead keybind from an ambient `TERMINAL`** | C5: warn and fall back to kitty; never exit 1 on resolution |
| **Prefix invariant lost in the split** | One runner owns the prefix; the lock test is parametrised over 8 binaries |
| **Panic mid-executor under `panic = "abort"`** | Panic-free rule for executor code; `stty` echo restoration documented |
| **Generated-script and `jq`/`python3` dependencies in the pilot** | Pilot findings 1–3; the JSON decision is Phase 0 |
| **Executors unreachable from `tests/`** | C2: executors live in `flex-rice/src/exec/`, binaries are thin |
| **Dirty tree carried into the change** | `git status` clean before Phase 0 (the B-025 centre change was the last offender) |
| **No rollback for a dead live bind** | Keep the wrappers and the `.sh` farm links in place until the click-through passes |

---

## Appendix — evidence checked

| Claim | Result |
|---|---|
| Nothing external parses `ACTION:` | ✅ zero consumers in `dotfiles`; the 8 wrappers are the only hits |
| Dispatch tests are executor-in-isolation, not pty tests | ✅ `tests/power.rs:397-405`, `tests/wifi.rs:915-919` stub `flex`, set `POPUP_KITTY=1`, run `bash <wrapper>` |
| Real-binary tests use `CARGO_BIN_EXE_flex` | ✅ `tests/launch.rs:193,643`, `tests/clip.rs:712`, `tests/wallpaper.rs:649` |
| `main` owns the single `flex: error:` | ✅ `main.rs:134-143`; B-022/B-027 resolved on it |
| `popup.sh` lives in dotfiles and `kill-menu.sh` depends on it | ✅ `kill-menu.sh:7`, bind `hyprland.lua:213` |
| Toggle is keyed on the *variant* (4 `menu` + 4 `menu-wide`) | ✅ `tests/wrappers.rs` table + `popup.sh:24-28` |
| 13 live `.sh` references across 3 stow packages | ✅ hyprland 8, waybar 2, scripts 3 (all line-checked) |
| 9 farm symlinks live today | ✅ `~/.local/bin/flex*` → `/home/test/projects/flex/…` |
| Wifi prompt details are load-bearing | ✅ `flex-wifi.sh:149-161` (stderr prompt, stdin fallback, explicit empty-answer line) |
| `flex-shot.sh` embeds bash, `jq` and `python3` | ✅ `:31-71`, `:86`, `:49`, `:96-109` |
| Executors cannot be tested from `src/bin/` | ✅ integration tests link `flex_rice`, not the bins |
| `unsafe_code = "deny"` and `panic = "abort"` at the workspace root | ✅ `Cargo.toml` `[workspace.lints.rust]` / `[profile.release]` |
| Terminal hardcodes for `Terminal=true` | ✅ (resolved) were `flex-launch.sh:58`, `flex-center.sh:87`; now `$TERMINAL` via `terminal::exec_argv` (flex `8cefbc2`) |
| `TERMINAL` unset in a plain shell on this host | ✅ `TERMINAL` empty, `TERM=dumb` (hedge: says nothing about the Hyprland session) |
| Shellcheck is enforced and passing | ✅ CI step + B-004 (shellcheck 0.11.0 in `~/.local/bin`, all 8 wrappers clean) |
| "zero bash at runtime" | ❌ dotfiles only keeps non-flex scripts (`kill-menu.sh`, `cliphist.sh`, `audio-mixer-toggle.sh`); `theme-switcher.sh` and `set-wallpaper.sh` were fully ported and deleted |
| `--print-action` "preserves the full selection test suite" | ❌ no existing suite depends on `ACTION:` (C1) |
| "`popup.sh`-in-flex-path" | ❌ `popup.sh` is a dotfiles script (C3) |
| Executors live in binaries | ❌ contradicts the stated test port; moved to the library (C2) |
