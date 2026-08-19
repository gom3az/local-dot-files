# kotlin-module.nvim

Create Kotlin Gradle modules from Neovim, following IntelliJ IDEA's module-creation conventions (per the
`kotlin-module.nvim-PRD` at the repo root).

`kotlin-module` detects your Gradle project (via `settings.gradle.kts`/`settings.gradle`), lets you pick a
module type and base package, then generates the module source tree and merges the module into
`settings.gradle.kts`, the root `build.gradle.kts`, and (when present) `gradle/libs.versions.toml` — all
atomically, with rollback on failure.

## Requirements

- Neovim 0.10+ (uses `vim.ui`, `vim.fs`, `vim.log.levels`)

## Installation

Using lazy.nvim:

```lua
{
  dir = "~/dotfiles/nvim/kotlin-module.nvim",
  cmd = { "NewKotlinModule" },
  keys = {
    { "<leader>km", "<cmd>NewKotlinModule<cr>", desc = "New Kotlin module" },
  },
  config = function()
    require("kotlin-module").setup()
  end,
}
```

Using vim.pack (if you vendor it into a packdir):

```lua
vim.api.nvim_create_user_command("NewKotlinModule", function()
  require("kotlin-module").new_module()
end, {})
```

## Usage

Run `:NewKotlinModule`. The wizard walks you through:

1. **Module type** — `jvm-lib` (Kotlin/JVM library) or `spring-boot` (Spring Boot app).
2. **Module name** — a valid Gradle path segment (e.g. `order-service`).
3. **Base package** — a dotted identifier (e.g. `com.acme`).
4. **DSL** — `kotlin` only in the MVP; selecting `groovy` aborts with a warning.
5. **Confirm** — `create` writes the module; `cancel` aborts with no changes.

Cancel at any prompt (press `Esc`/`Ctrl-c` in the input) leaves the project untouched.

### Generated layout

For a `spring-boot` module named `order-service` in package `com.acme`:

```
order-service/
├── build.gradle.kts
└── src/
    ├── main/
    │   ├── kotlin/com/acme/Application.kt
    │   └── resources/
    └── test/
        ├── kotlin/com/acme/ApplicationTest.kt
        └── resources/
```

Files merged into the existing project (atomically, with rollback on error):

- `settings.gradle.kts` — adds `include(":order-service")`
- root `build.gradle.kts` — adds `alias(libs.plugins.<X>) apply false` declarations (or inline `id(...) version "..."` when no catalog is used), reusing existing declarations
- `gradle/libs.versions.toml` — adds missing `[versions]`, `[plugins]`, `[libraries]` entries; otherwise left byte-identical

## Configuration

```lua
require("kotlin-module").setup({
  kotlin_version = "2.4.10",
  spring_boot_version = "3.5.0",
  dependency_management_version = "1.1.7",
})
```

These are used when a version can't be inherited from the project. If the root `build.gradle.kts` or
`settings.gradle.kts` already declares a plugin version inline, that version is reused
(inheritance-first resolution, mirroring IntelliJ's `usesParentKotlinVersion` behavior).

## Behavior notes

- **Catalog mode** is selected solely by the presence of `gradle/libs.versions.toml`; otherwise **inline mode**
  is used (`id("org.jetbrains.kotlin.jvm") version "2.4.10"`).
- Existing `[versions]`/`[plugins]`/`[libraries]` entries are never overwritten; a missing section header is
  created.
- No Gradle sync or task is run (MVP behavior) — reload/re-import the project in your IDE.
- CRLF and BOM in existing files are preserved.
- Root detection: walking up from the current buffer's directory, anchored at the first
  `settings.gradle`/`settings.gradle.kts`. `pom.xml`, `build.gradle(.kts)`, and `workspace.json` are reported
  as markers but never treated as a Gradle root by themselves.

## Tests

Unit tests run under plain Lua via `busted` (no Neovim needed):

```sh
luarocks install --local busted
/home/test/.luarocks/bin/busted tests/unit/
```

Wizard flow tests run under a headless Neovim instance:

```sh
bash tests/wizard/run_wizard_tests.sh
```

## License

MIT — see [LICENSE](LICENSE).