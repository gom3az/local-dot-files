# Plan: consolidate flex into a single Cargo workspace (`gom3az/flex`)

**Status:** revised after evidence review, 2026-09-16
**Supersedes:** the initial "merge the rice into a dedicated flex monorepo" draft

## Recommendation

Yes — move the rice out of `dotfiles` into a dedicated workspace repo. With personal-rice-only scope and `flex-core` never being published, the split charges all of the costs and returns none of them.

Three corrections to the original draft's evidence are load-bearing and are reflected below:

1. The Hyprland binds **were missed** (8 of them, not zero).
2. The CI blockage is a **GitHub token scope**, not a repo layout — a new repo does not fix it.
3. The test baseline is **344**, not 331, and `git subtree` is **not installed**.

---

## Why (verified evidence)

**The costs are real and recurring.**

- Engine iteration needs the uncommitted `[patch]` dance — documented at `Docs/project_structure.md:154-175` exactly as claimed.
- Every engine change costs a tag bump + `cargo update -p flex-core` + `Cargo.lock` churn.
- B-027 is unfixable from this side — the doubled `flex: error: flex: …` prefix lives in `flex-core` (`src/backend.rs:48,51,55,58,60`, `src/run.rs:102,115,116`, `src/preview.rs:475` — **nine** self-prefixed messages), and this repo can only wait on a tag.
- The test suite is split across two `cargo test` runs (`flex-rice` 235 passed / 1 ignored, `flex-core` 109 → **344**). Atomic engine+consumer changes (e.g. a `TickHook` shape change plus both call sites) are impossible.
- Docs are split-brained: design-system and engine citations in `Docs/` point at code in another repo (`Docs/project_structure.md:89,103`, `flex/README.md:95,116`).

**Correction — CI is not a cost of the split.** `gh auth status` reports token scopes `project, read:org, read:user, repo, write:packages`. There is no `workflow` scope. That blocks pushing `.github/workflows/` from *any* repo, including a brand-new `gom3az/flex`. `flex-core` having no CI is a credential limitation, not an architectural one. Fix with `gh auth refresh -s workflow` (or add the file through the web UI). Do not count this as a benefit of the merge.

**Rejected alternative — moving core back into `dotfiles`:** keeps library history inside a personal stow repo (`local-dot-files` remote) and forecloses clean publication later. Wrong direction.

**Note on scope:** `local-dot-files` is already a **public** repo, so the machine-specific rice is already public. The new repo adds no new exposure — but the "personal / never published" framing should not be read as secrecy.

---

## Target shape

New repo `gom3az/flex` (confirmed not to exist yet), a Cargo workspace:

```
flex/                    # dedicated repo
  Cargo.toml             # workspace root: shared deps, lints, release profile
  Cargo.lock             # single lockfile
  rustfmt.toml           # one copy (verified byte-identical between the two repos today)
  flex-core/             # engine (keep publishable for optionality)
  flex-rice/             # moved: src, tests, fixtures, wrappers/
```

`flex-rice → flex-core` becomes a path dependency — no tags, no `[patch]` dance, one `cargo test` (344), one fmt/clippy gate, one CHANGELOG.

---

## Phase 0 — decisions to lock before touching anything

1. **Repo:** new `gom3az/flex` rather than renaming `gom3az/flex-core`. Rationale: `flex-core` as a member name inside a `flex-core` repo is confusing and `v1.0.0` tags collide. Low stakes either way — the existing `flex-core` repo is a **single root commit** (`777d6fc`), so nothing historical is at risk.

2. **Checkout path (was unstated — now mandatory).** The new repo's on-disk location is the single decision every rewired reference depends on, and `~/projects` does not exist on this machine. `Docs/project_structure.md:160` already assumes `~/projects/flex-core`. **Lock `~/projects/flex` and record it in Phase 2.**

3. **Wrapper resolution strategy (was unstated).** Today 13 config references hardcode `$HOME/dotfiles/flex/flex-rice/wrappers/…`. Repointing them at `$HOME/projects/flex/…` merely recreates the same fragility at a new address. The wrappers already discover the *binary* by name (`flex-launch.sh:12`: `command -v flex || PATH="$HOME/.local/bin:$PATH"`); only the wrapper *scripts* are absolute. **Recommended:** create a stable `~/.local/bin/flex-<provider>.sh` symlink farm pointing into the checkout, and have every config reference `$HOME/.local/bin/flex-<provider>.sh`. The next move then touches 8 symlinks instead of 13 files across 3 stow packages. (Keep absolute, not bare-name, so Hyprland's exec environment cannot defeat it.)

4. **History import.** Importing `flex-core`'s history buys nothing: that repo has **one** commit. `dotfiles`' entire `flex/` history is **4 commits** (`a79b907`, `e6c7654`, `a75268d`, `34b9987`), and `flex/flex-core` appears in only **2** of them. The original "so blame survives" justification does not hold, and importing `flex-core`'s single commit under a fresh prefix would *break* the lineage `dotfiles`' `flex/flex-core/` prefix still has. Choose one:
   - **Preferred:** import `flex-core`'s content as a plain commit (1 commit — nothing to preserve), import `flex-rice` via `git read-tree`/manual merge. Skip `git subtree` entirely.
   - **If lineage matters:** import the engine from `dotfiles`' own `flex/flex-core` prefix instead of from `gom3az/flex-core`.

5. **`git subtree` is not installed.** `git subtree --version` → `git: 'subtree' is not a git command` (only `/usr/libexec/git-core/git-merge-subtree` exists). Either install `git-subtree`, or use the documented manual equivalent:
   ```sh
   git remote add old-core <url> && git fetch old-core
   git merge -s ours --allow-unrelated-histories --no-commit old-core/master
   git read-tree --prefix=flex-core/ -u old-core/master
   git commit -m "flex-core: import at v1.0.0 (777d6fc)"
   ```
   Whichever is chosen, write it down — the original draft assumed the tool was present.

6. **`flex-core` publishability:** keep `publish = true`-capable (zero cost, keeps options open) even though the use is personal-only.

7. **Re-baseline the gate at 344.** The original "expect 331 green" is stale (pre-wifi-provider) and would "fail" on a correct move. Also note the working tree is currently **dirty**: `flex/flex-rice/src/providers/center.rs` and `tests/center.rs` carry an uncommitted B-025 change. **Commit or stash before relocating**, so the moved tree is reproducible.

---

## Phase 1 — relocate (in the new repo)

1. Import `flex-core` (per Phase 0.4/0.5), then import `dotfiles`' `flex/flex-rice/` subtree (**the `flex/flex-rice` prefix, not `flex/`** — importing `flex/` would dump `Cargo.toml`/`README.md`/`CHANGELOG.md`/`LICENSE-*` at the new root). Bring root `LICENSE-APACHE`, `LICENSE-MIT`, `rustfmt.toml`.

2. Write the workspace-root `Cargo.toml`: `members = ["flex-core", "flex-rice"]`, `resolver = "2"`, hoist the `[workspace.dependencies]`, `[workspace.lints.*]` and `[profile.release]` currently at `dotfiles/flex/Cargo.toml:17-48`.
   - **`unicode-width` is not in the current root `[workspace.dependencies]` at all** — add it (`flex-core` depends on it).
   - Member-level `[profile.release]` is silently ignored once `flex-core` is a member — hoisting is required, and the ~984K release binary (`flex/CHANGELOG.md:310`) is the only real evidence the profile is still applied. **Re-measure it.**

3. `flex-rice/Cargo.toml`: `flex-core` becomes a path/workspace dep; keep `publish = false`, `[[bin]] name = "flex"`.

4. **Do not flatten or rename `flex-rice/wrappers/`** — the `04e2599` precedent: moving the wrapper dir breaks every bind at once.

5. **Preserve exec bits on all 8 wrappers.** Verified `100755` in the git index today. `tests/wrappers.rs` gates this, but it moves in the *same* operation, so a botched move breaks the test too. Take a `git ls-files -s flex/flex-rice/wrappers/` snapshot **before** and diff it **after**.

6. Clean up in transit:
   - Delete the orphaned `flex-core/Cargo.lock` (29 KB) and re-resolve at root (`criterion` from the engine's dev-deps enters the root lock).
   - Drop `flex-core/.cargo-ok`.
   - Update `flex-core/Cargo.toml` `repository`/`keywords`/`categories`/`description` — they still name the archived `gom3az/flex-core`.
   - `flex-core`'s own `[lints.clippy] all/pedantic = deny` already matches the root's, so no lints work is expected — **verified**: `cargo clippy --all-targets -- -W clippy::pedantic -D warnings` on flex-core @ `777d6fc` exits 0. The unified clippy gate is free.

7. One `cargo fmt --all`, `cargo clippy --all-targets -- -D warnings`, `cargo test` (**expect 344 passed / 1 ignored**), `cargo build --release` + binary-size check.

---

## Phase 2 — rewire `dotfiles` (small, but miss-one-breaks-a-keybind)

Complete inventory — **13 live config references**, all verified by grep (an earlier draft claimed 5):

| Consumer | Path | Lines |
|---|---|---|
| Hyprland binds | `hypr/.config/hypr/hyprland.lua` | 194, 201, 205, 206, 207, 208, 209, 211 — **8 binds** |
| Waybar on-clicks | `waybar/.config/waybar/config.jsonc` | 61 (wifi), 103 (power) |
| Script delegation | `scripts/.config/scripts/cliphist.sh` | 96 |
| Script delegation | `scripts/.config/scripts/theme-switcher.sh` | 181 |
| Script delegation | `scripts/.config/scripts/wallpaper-picker.sh` | 13 |

These cover `SUPER+s, SUPER+M/X, SUPER+R, SUPER+space, SUPER+W, SUPER+T, SUPER+SHIFT+V` plus the Waybar network and power modules. `git show 04e2599` documents exactly this list — the commit that had to fix all 13 after the last move, because "SUPER+W, +s, +T, +R, +X, +M and +SHIFT+V all silently did nothing." **Treat 04e2599 as the checklist.**

Also in scope:

- **`~/.local/bin/flex`** — symlink → `/home/test/dotfiles/flex/target/release/flex`. Repoint at the new checkout's `target/release/flex`. Wrappers resolve the binary through it.
- **Doc reference:** `themes/.config/themes/WORKFLOW.md:116`.
- **Already-stale refs to fix in the same pass** (they still point at the *pre-split* path and predate this work): `Docs/Implementation.md:335`, `flex/CHANGELOG.md:203`, plus `flex/wrappers/` mentions at `Docs/Implementation.md:245,246,248` and `Docs/Bug_tracking.md:11`.
- **`tests/wrappers.rs` / all `CARGO_MANIFEST_DIR` uses:** moves with the crate, **no change needed** (verified — 14 uses, all crate-relative).
- **`.gitignore`** (`flex/target/`) and **`.stow-local-ignore`** (`flex/target/`) need updating or deletion.
- **Stow:** nothing from `flex/` is currently stowed at `$HOME` (no `~/Cargo.toml`, `~/flex-rice`, `~/rustfmt.toml` symlinks), so removing the package is low risk — but state the `stow -D flex` step explicitly rather than assuming it is free.
- **Live config surface:** `~/.config/hypr` and `~/.config/themes` are directory symlinks into `dotfiles`; `~/.config/waybar/*` and `~/.config/scripts/*` are per-file symlinks. All edits below are therefore live immediately — run `hyprctl reload` and restart Waybar after rewiring.

**Ordering matters.** Delete `dotfiles/flex/` sources only **after** the new build is live, the rewiring is verified, and the click-through passes — not before Phase 3's doc edits, which reference those paths.

---

## Phase 3 — reunite tests, docs, chores

1. All 344 tests run in one `cargo test`; `cargo bench -p flex-core --bench rerank` resolves to the member again (the bench lives at `flex-core/benches/rerank.rs`).
2. **Fix B-027 properly** — this is the first concrete payoff. Sweep **all nine** engine self-prefixes (`src/backend.rs:48,51,55,58,60`; `src/run.rs:102,115,116`; `src/preview.rs:475`) so `main.rs:140` owns the only `flex: error:`, then lock with a B-022-style exact-line test. Note the test must run the real binary (`flex launch </dev/null`) and compare the whole stderr line — mind the environment-dependent `(os error 6)` suffix.
3. **Add CI.** First run `gh auth refresh -s workflow`, then add `.github/workflows/` (fmt → clippy `-D warnings` → test). This is a token fix, not a repo-layout fix; it would have been equally available to `gom3az/flex-core`.
4. Consolidate `CHANGELOG.md` (370 lines today) and `README.md` (124). Move or fold the flex docs (`Docs/Implementation.md`, `Docs/Bug_tracking.md`, `Docs/project_structure.md` — ~26 flex path references total) so citations are same-repo `file:line` again. Fix the three mutually inconsistent test counts while in there (`flex/CHANGELOG.md` "222", `Docs/project_structure.md:182` "234", `Docs/Bug_tracking.md:29` "227" — all superseded by 344).
5. Archive (don't delete) `gom3az/flex-core` read-only with a pointer commit for ~1 release cycle in case anything still references the git URL.

---

## Phase 4 — verify

**Gates**
- `cargo fmt --all --check`
- `cargo clippy --all-targets -- -D warnings`
- `cargo test` → **344 passed, 1 ignored** (not 331)
- `cargo test --release`
- `tests/wrappers.rs` green (exec bits + popup re-exec intact)
- `git ls-files -s` wrapper-mode diff before/after relocation → unchanged, all `100755`
- `cargo build --release` → binary size ≈ 984K (proves `[profile.release]` hoisting worked)

**Live smoke**

- Per-provider pty smoke: launch / clip / center / shot / theme / power / wallpaper / wifi — open, `Esc` → 130, one `Enter` → a valid `ACTION:` line.
- Then click through **every** repointed bind: `SUPER+M/X/W/T/S`, `SUPER+SHIFT+V`, `SUPER+R`, `SUPER+space`, Waybar power + network. This is the only check that catches a missed absolute path.
- `hyprctl reload` reports no config errors; Waybar restarted cleanly.

**Sweep**

- `rg "dotfiles/flex"` across `dotfiles` returns only intentional hits (expect: none in live configs).
- The same sweep **outside** `dotfiles` — `~/.local/bin`, `~/.config`, shell rc files, any systemd/dynamic Hyprland config — since the live configs are symlinks and others may not be.
- `stow -n` dry-run clean.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| **Missed absolute path → dead keybind** (the `04e2599` failure). The original draft's inventory missed 11 of 13 references, including all 8 Hyprland binds. | Use the table in Phase 2 / `git show 04e2599` as the checklist; the Phase 4 click-through is the only real proof. |
| **CI push rejected** because the merge was assumed to unblock it | `gh auth refresh -s workflow` *before* Phase 3.3; do not treat this as a merge benefit. |
| **Import tooling absent** (`git subtree` not installed) | Phase 0.5: install it or use the `read-tree` recipe. |
| **False regression** from a stale gate | Re-baseline to 344/1-ignored in Phase 0.7. |
| **Dirty tree moved verbatim** | Commit or stash the uncommitted B-025 changes in `src/providers/center.rs` + `tests/center.rs` first. |
| **Exec-bit loss on wrappers** → binds silently fail | `tests/wrappers.rs` + `git ls-files -s` snapshot diff. |
| **Broken release profile** (member `[profile.release]` ignored) | Re-measure the 984K binary in Phase 4. |
| **Stow breakage / dangling `$HOME` symlinks** | Phase 2 keeps wrapper dir depth identical; `stow -D flex` explicitly; nothing is stowed from `flex/` today. |
| **No rollback for a dead live bind** | Keep the old checkout and the old `~/.local/bin/flex` target in place until the full click-through passes, then remove. |

---

## Appendix — evidence checked

| Claim | Result |
|---|---|
| `flex-rice` `publish = false` at `flex/flex-rice/Cargo.toml:11` | ✅ exact |
| `rustfmt.toml` "already identical" | ✅ `diff` clean |
| 8 wrappers executable | ✅ all `100755` in the git index |
| `tests/wrappers.rs` moves with the crate | ✅ `CARGO_MANIFEST_DIR/wrappers`, no path edits |
| `[patch]` dance at `Docs/project_structure.md:154-175` | ✅ exact |
| Hoist range `flex/Cargo.toml:17-48` | ✅ `[workspace]` L17 … EOF L48 |
| `flex-core` @ `v1.0.0` = `777d6fc` | ✅ single root commit, 2026-09-15 |
| "flex-core has no CI" | ✅ no `.github` in the checkout — **but** caused by the token scope, not the split |
| Engine passes the stricter clippy gate | ✅ `-W clippy::pedantic -D warnings` exits 0 |
| "flex-core is publishable" | ✅ no path deps; `cargo package -p flex-core` still works inside a workspace |
| **"no `flex-*` references in `hypr/`"** | ❌ **8 binds** at `hyprland.lua:194,201,205,206,207,208,209,211` |
| **"2 hardcoded absolute paths"** | ❌ **13** live config references (8 hypr + 2 waybar + 3 scripts) |
| **"CI now unblocked by one repo"** | ❌ token lacks `workflow` scope; orthogonal to layout |
| **"222 / 109 = 331 tests"** | ❌ **235 / 109 = 344** (1 ignored); docs say 222, 234 and 227 |
| **"subtree so blame survives"** | ❌ nothing to preserve: `flex-core` = 1 commit; `dotfiles flex/` = 4 commits |
| **`git subtree` available** | ❌ not installed |
