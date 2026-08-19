# kotlin-module.nvim — Module Index

Implementation notes and design decisions behind the plugin. The authoritative product spec is
`../kotlin-module.nvim-PRD` (v0.3); this document records how the code maps to it.

## Files

| File | Purpose |
| --- | --- |
| `plugin/kotlin-module.lua` | Registers the `:NewKotlinModule` user command |
| `lua/kotlin-module/init.lua` | `setup()`, `new_module()` orchestration, two-phase commit + rollback |
| `lua/kotlin-module/project.lua` | Gradle root detection (settings-first), marker collection |
| `lua/kotlin-module/validate.lua` | Module name / package / collision validation |
| `lua/kotlin-module/gradle.lua` | Settings merge, root plugin merge, catalog merge, version inheritance, plan builder |
| `lua/kotlin-module/wizard.lua` | Chained `vim.ui.select`/`vim.ui.input` prompts |
| `lua/kotlin-module/types/jvm-lib.lua` | Kotlin/JVM library template |
| `lua/kotlin-module/types/spring-boot.lua` | Spring Boot app template |
| `tests/unit/*.lua` | `busted` specs (pure Lua, no `vim.*`) |
| `tests/wizard/*` | Headless Neovim wizard-flow tests |

## Design decisions

### Testability (no `vim.*` in pure modules)
`validate.lua`, `gradle.lua`, and the `types/*` renderers are pure Lua so `busted` (system Lua 5.4) can test
them without Neovim. `project.lua` keeps its `vim.fs` dependency behind `set_fs()`/`get_fs()`, defaulting to
`require("vim.fs")` at call time.

### Root detection is settings-first (PRD §module-location)
Only `settings.gradle.kts` / `settings.gradle` anchor a root. `pom.xml`, `build.gradle(.kts)`, and
`workspace.json` are *markers* (reported, never roots) so a mixed Maven+Gradle repo doesn't get a false root.

### Catalog vs inline mode
Mode is determined **solely** by presence of `gradle/libs.versions.toml`. In catalog mode the root file gets
`alias(libs.plugins.<Alias>) apply false` and the module uses `alias(...)`; in inline mode both get
`id("...") version "..."`.

### Inheritance-first version resolution (PRD §version-catalog / F22)
`probe_inherited_versions` scans root `build.gradle.kts` and `settings.gradle.kts` for inline
`id("...") version "..."` declarations. `resolve_plan` prefers the observed version; otherwise the catalog's
`[versions]` value (existing entries are never overwritten); otherwise the configured default
(`2.4.10` / `3.5.0` / `1.1.7`). When the root already declares a plugin (by id or by catalog alias with
`apply false`), the root merge reuses it and the module build script omits it.

### Two-phase commit (PRD §error-handling)
1. Compute the full plan (`resolve_plan`) — no side effects.
2. Create dirs + write module files, then atomically rename each modified project file (tmp + `os.rename`).
3. On any failure, delete created dirs/files in reverse order and report rollback.

### Atomic writes & encoding preservation (PRD §file-preservation)
`atomic_write` writes to a sibling `.<name>.kotlin-module.tmp` then `os.rename`s it. `merge_catalog` returns
the original bytes untouched when nothing needs inserting; EOL detection (`\n` vs `\r\n`) and BOM are
preserved on merged files.

### Catalog merge invariants
- Never overwrite an existing entry (matched by key for versions, by `id = "..."` for plugins, by
  `module = "..."` for libraries).
- Missing `[versions]` / `[plugins]` / `[libraries]` headers are created; new entries are inserted right
  after their section header.

### Module templates
- `jvm-lib`: `Greeter.kt` + `GreeterTest.kt` (mirrors IntelliJ's KotlinSample).
- `spring-boot`: `Application.kt` + empty `ApplicationTest.kt`, `application { mainClass.set(...) }`, and an
  optional `kotlin { jvmToolchain(...) }` block when `jvm_target` is provided.
- Four source dirs (main/test × kotlin/resources) per PRD F21.

### Wizard
Strict sequence: type → name (re-prompt on invalid) → package (re-prompt on invalid, pre-filled from an
existing sibling module when found) → DSL → confirm. `groovy` selection aborts with `groovy-unsupported`
and no changes. Cancel anywhere returns no result. In **inline mode** (no `gradle/libs.versions.toml`) the
wizard additionally prompts for Kotlin and Spring Boot versions, pre-filled from versions inherited from the
root build, sibling module, or built-in defaults. The final confirm summary (shown via `vim.ui.select`) lists
the module path, type, package, DSL, mode, files to create, and Gradle files to modify; choosing "cancel"
makes zero changes.

### Inheritance & conventions
- `probe_inherited_versions(root, settings, sibling)` discovers pinned versions from the root `build.gradle.kts`,
  `settings.gradle.kts`, and an existing sibling module's `build.gradle.kts`, so the generated module omits
  versions the root already declares and reuses the project's chosen Kotlin/Spring Boot versions.
- Catalog mode reuses the **existing alias key** in `libs.versions.toml` (e.g. `kotlin-jvm` instead of assuming
  `kotlinJvm`), so generated `alias(libs.plugins.<x>)` lines never reference a missing alias. Dashed keys are
  rendered as Gradle's dotted accessor form (`kotlin-jvm` → `alias(libs.plugins.kotlin.jvm)`) and existing
  dotted declarations in the root are reused. `merge_catalog` is idempotent: it never re-adds an existing
  version key, plugin id, library module, or a duplicate key under a new id/module, and it skips keys whose
  dotted accessor would collide as a prefix of an existing key.
- When the project uses a **buildSrc convention plugin** (detected via `buildsrc.convention.*` in the root or
  settings), the generated module applies that convention plugin instead of emitting individual plugins.
- When **KGP is exposed as a catalog library**, the module build keeps the kotlin plugin declarations without
  forcing duplicate version/alias additions into the root.
- A **Kotlin↔Gradle compatibility warning** (F26) is emitted when the resolved Kotlin version is incompatible
  with the project's wrapper Gradle version (e.g. Kotlin 2.x requires Gradle 7.6.3+, Gradle 9 requires
  Kotlin 2.2.20+).

### Writes summary
`new_module` prints a summary via `vim.notify` listing created files, modified Gradle files, and a reminder
that no Gradle sync was run.

## Known limitations (MVP)
- No Gradle sync / task execution; the user must re-import in their IDE.
- Groovy DSL generation is unsupported (aborts with a warning).
- `settings.gradle.kts` modification only appends an `include(":name")` line; it does not parse
  existing `include` blocks beyond deduplication.
- `find_sibling_package` infers the base package from the first sibling `.kt` file found; it does not
  detect package declarations in sibling build files or settings.