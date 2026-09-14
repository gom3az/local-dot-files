# Kotlin LSP "intellij-server has expired" (Neovim + Mason)

`kotlin-lsp` stops starting and every Kotlin buffer loses LSP. The Neovim LSP log
(`~/.local/state/nvim/lsp.log`) shows only this on each launch:

```
IJ_JAVA_OPTIONS=
idea.config.path=/tmp/idea-system.../config
idea.system.path=/tmp/idea-system.../system
Log file: /tmp/idea-system.../system/log/intellij-server.log
This build of intellij-server has expired.
The IDE will now close.
Please download a new build from https://www.jetbrains.com/intellij-server/
```

## Why it happens

`kotlin-lsp` is IntelliJ packaged as an LSP server (`intellij-server`). Like all
IntelliJ EAP/preview builds it carries a hard-coded ~30-day evaluation expiry,
independent of Mason. Reinstalling via `:Mason` does not help while the Mason
registry and upstream are pinned to the same build — verified 2026-09-08 with
`kotlin-server-262.9593.0` (released 2026-07-27, still `Latest` at
`github.com/Kotlin/kotlin-lsp/releases`). 43 days old = expired.

This is a repeat of [Kotlin/kotlin-lsp#217](https://github.com/Kotlin/kotlin-lsp/issues/217)
(`v262.4739.0`, June 2026). JetBrains documents the policy for the LSP preview as
"each build renews the evaluation period and is limited to 30 days"
(`blog.jetbrains.com/idea/2026/08/intellij-idea-goes-lsp`).

## How to confirm

```bash
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
timeout 20 intellij-server --stdio </dev/null 2>&1 | head -n 10
# expired build prints "This build of intellij-server has expired."
cat ~/.local/share/nvim/mason/packages/kotlin-lsp/mason-receipt.json
# check "id": "pkg:generic/Kotlin/kotlin-lsp@kotlin-lsp/v..." vs upstream Latest
```

## Workaround: freeze the server clock with faketime

Until JetBrains ships a build newer than the installed one, run the server under
`faketime` with a date inside its validity window (after release, before ~+30d):

```bash
sudo dnf install libfaketime
```

`nvim/.config/nvim/lua/plugins/lsp.lua`:

```lua
vim.lsp.config('kotlin-lsp', {
  -- WORKAROUND 2026-09-08: kotlin-server-262.9593.0 (Jul 27) is expired;
  -- intellij-server quits after its 30-day EAP period. Freeze its clock
  -- until JetBrains ships a new build. See Kotlin/kotlin-lsp#217.
  cmd = { 'faketime', '2026-08-15 12:00:00', 'intellij-server', '--stdio' },
```

Verify:

```bash
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"
timeout 20 faketime '2026-08-15 12:00:00' intellij-server --stdio </dev/null 2>&1 | head -n 10
# healthy: 4 startup lines, no "has expired" message
```

Then restart Neovim and open a `.kt` file.

## Removing the workaround

1. `:Mason` → update `kotlin-lsp`, or check upstream releases for a tag newer
   than the installed `kotlin-server-*` directory.
2. Revert `cmd` to `{ 'intellij-server', '--stdio' }` and restart Neovim.
3. Delete this doc section once no pinned install needs it — the frozen clock
   can confuse Gradle caching/diagnostics if left in place permanently.
