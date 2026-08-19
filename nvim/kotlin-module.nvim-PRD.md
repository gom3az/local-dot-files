# kotlin-module.nvim — Product Requirements Document

| | |
|---|---|
| **Product** | `kotlin-module.nvim` — an IntelliJ-IDEA-style "New Kotlin Module" wizard for Neovim |
| **Version** | 0.3 (reviewed — F21–F29 resolved) |
| **Status** | Proposed |
| **Author** | Product / maintainer (TBD) |
| **Last updated** | 2026-08-15 |
| **Deliverable type** | Standalone Neovim plugin (pure Lua) — **planning/documentation only, no code in this PRD** |

> **Revision note (v0.3):** re-reviewed against the actual IntelliJ Kotlin/Gradle module-generation sources (JetBrains/intellij-community `project-wizard`, fetched at master). Key changes: source layout now includes `src/main/resources` + `src/test/resources` (F21); inline mode resolves versions **inheritance-first** — probing the root `plugins {}`, a sibling module, and `pluginManagement`, and omitting the version in the module build file when the root already declares it (F22); buildSrc-convention-plugin and KGP-as-library (`[libraries] kotlinGradlePlugin`) wiring is recognized and reused (F23); toolchain block is conditional on a resolver and its value comes from the detected JDK (F24); catalog merges prefer observed project versions over baked defaults (F25); a wizard-time Kotlin↔Gradle compatibility warning is added (F26); F27 confirmed-no-change (IntelliJ `*Kt` main-class naming matches the PRD's `ApplicationKt`); version examples updated to current releases (IntelliJ's bundled default is KGP 2.4.10) (F28); wizard pre-fills inherit project conventions (base package, DSL, versions) in line with IntelliJ's add-module short flow (F29). References updated with the authoritative source files.
>
> **Revision note (v0.2):** incorporates the `prd-analysis` review. Key changes: catalog mode is now **presence-based** (F1); root detection is **settings-first** (F2); Spring Boot template adds the **kotlin-spring plugin + `mainClass` + toolchain** (F3); both templates emit **`testImplementation(kotlin("test"))`** (F4); include-collision checks use a **normalized include-set parser** (F5); plugin merges **dedupe by plugin id**, never duplicating a declaration (F6); generation is **two-phase with rollback** (F7); O3 date and metric proxies fixed (F8/F9); minor/nit items F10–F20 folded in (EOL/BOM, Windows-safe validation, test strategy, template-content contract at M0, Groovy-DSL prompt behavior, metric definitions/privacy).

---

## Executive Summary

`kotlin-module.nvim` is a new, standalone, pure-Lua Neovim plugin that replicates the IntelliJ IDEA `File → New → Module` flow for Kotlin/Gradle multi-module projects. Where IntelliJ turns a few clicks into a fully wired Gradle subproject — directory, `build.gradle.kts`, `src/` trees with sample code, an `include(":name")` entry in `settings.gradle.kts`, root-level plugin declarations with `apply false`, and version-catalog entries — Neovim users today must perform each of these steps by hand across three or more files. No existing Neovim plugin, including `gradle.nvim` (oclay1st), which handles `gradle init` project creation and task execution but has no "add module to an existing multi-module build" flow, addresses this gap.

The plugin delivers a chained, cancel-safe wizard driven by the standard `vim.ui.select` / `vim.ui.input` hooks. It automatically upgrades to a Telescope or dressing UI when present, but has **zero required dependencies**. The MVP supports exactly two module types — **Kotlin JVM Library** and **Spring Boot** — and performs all Gradle integration through idempotent, tolerant line-based file merging: appending `include(":name")` without duplicates, declaring plugins in the root build script with `apply false`, and using version-catalog aliases (`alias(libs.plugins.kotlinJvm)`) when a `gradle/libs.versions.toml` catalog is present, with a clean inline-version fallback when it is not. The plugin never executes a Gradle sync, never overwrites existing user files, and never makes network calls in the MVP.

The primary target is the Kotlin/Spring developer on Neovim — specifically a kickstart-style dotfiles setup using the native `vim.pack` plugin manager on Neovim 0.12+, with 42 Spring-focused plugins (nvim-java, spring-boot.nvim, jdtls, kotlin-lsp, neotest, mason, telescope). The plugin is deliberately opinionated about this environment while remaining installable via `vim.pack`, `lazy.nvim`, and `packer.nvim`. Success is measured by a North Star of successful modules created per user per week and time-to-working-module, with supporting HEART and OKR metrics. This PRD defines the MVP scope, user stories, technical approach, and a phased roadmap that defers catalog creation and inline→alias migration to later releases.

---

## Problem Statement

Kotlin and Spring developers using Neovim on multi-module Gradle builds face a slow, error-prone, entirely manual workflow every time they start a new module. In IntelliJ IDEA this is a single wizard action; in Neovim it requires:

1. `mkdir` for the module directory tree (`src/main/kotlin/<pkg>/`, `src/test/kotlin/<pkg>/`),
2. Hand-writing a `build.gradle.kts` with the correct plugins, and sample source files,
3. Appending `include(":name")` to `settings.gradle.kts` (while avoiding accidental duplication or corrupting surrounding `pluginManagement` / `dependencyResolutionManagement` / BOM blocks),
4. Adding matching plugin declarations with `apply false` to the root `build.gradle.kts`,
5. Synchronizing versions — ideally through a version catalog (`gradle/libs.versions.toml`) using `alias(libs.plugins.…)`, falling back to inline versions when no catalog exists.

Each step is a chance to introduce subtle build breakage: a duplicated `include`, a version mismatch, a malformed merge of a hand-edited settings file. The impact is developer friction (several minutes per module), context switching away from the editor, and build-file corruption that only surfaces at the next `gradle build`.

The gap is not served by existing tooling. `gradle.nvim` (oclay1st) covers project creation *from scratch* (`gradle init`) and task execution, but has no "add a module to an existing project" flow — and it carries hard dependencies (plenary.nvim, nui.nvim). No other Neovim plugin targets this exact workflow.

---

## Goals & Objectives

### Goals

- **G1 — Parity with the IntelliJ new-module flow:** Enable a Neovim user to create a Kotlin JVM Library or Spring Boot module in a multi-module Gradle project with a few keystrokes, producing the same wired-up result IntelliJ would produce.
- **G2 — Zero-friction adoption:** Installable with `vim.pack`, `lazy.nvim`, and `packer.nvim`; zero required plugin dependencies; a single command (`:NewKotlinModule`) plus one documented keymap.
- **G3 — Never break a user's build:** All Gradle file mutations must be idempotent, non-destructive, and tolerant of user-written `settings.gradle.kts` / root build scripts (no fragile regex rewrites, no overwrites, no network calls, no Gradle sync).
- **G4 — Version-correct by default:** Match the project's conventions — use version-catalog aliases when a catalog exists, inline versions otherwise — with sensible defaults the user can override.
- **G5 — Testable and maintainable:** A small, documented codebase with fixture-based tests proving idempotent merges across representative project shapes.

### Objectives (SMART)

- **O1:** Ship MVP with exactly two module types (Kotlin JVM Library, Spring Boot) and the full wizard + Gradle-integration flow by **2026-10-30** (target: end of Phase 1, see Timeline).
- **O2:** By **2026-10-15**, achieve 100% pass on the fixture-based test suite covering the four core project shapes (catalog-present incl. the conventional blockless `libs.versions.toml`, catalog-absent, missing-root-build-file, existing-module-collision) plus the merge edge shapes (colon-less include, multi-arg include, plugin-id version conflict, CRLF/BOM, buildSrc-convention & KGP-as-library wiring), and a regression suite for idempotency. Idempotency is asserted **at the merge-engine level** (applying each merge function to already-merged file states must be a no-op / byte-identical); the wizard-level double-run test covers the "cancel then re-run" path only, since a successful run creates the module directory that collision checks then reject.
- **O3:** By **2027-01-31**, reach **zero** reported build-file corruption incidents attributable to the plugin's merges (bug category "corruption of user build files") over the 30 consecutive days following the v1 (M4, 2026-12-31) release.
- **O4:** By **2026-12-31**, achieve a median **time-to-working-module** of ≤ 3 minutes (wizard start → first `gradle build` of the new module succeeds with no manual edits) across all four fixture project shapes in manual QA sessions (target at least 10 QA sessions).
- **O5:** By **2027-03-31**, reach **≥ 100** GitHub stars and **≥ 25** GitHub release-asset downloads, plus at least **10** opt-in survey registrations from active users (see Adoption metrics for proxy definitions and why clone counts are not used).

---

## User Personas

### Primary Persona: Kotlin/Spring Developer on Neovim

- **Role:** Backend developer working on Kotlin microservices / Spring Boot services; daily driver is Neovim, not an IDE.
- **Environment:** Kickstart-style dotfiles repo using native `vim.pack` (Neovim 0.12+), ~42 plugins focused on Spring Java/Kotlin: `nvim-java`, `spring-boot.nvim`, `jdtls`, `kotlin-lsp` (via `intellij-server`; root markers `settings.gradle`, `settings.gradle.kts`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `workspace.json`), `neotest`, `mason`, `telescope` + `telescope-ui-select` (which upgrades `vim.ui.select` to a Telescope dropdown), `nui.nvim` present but not required. Leader key is space.
- **Goals:** Add new service/library modules to multi-module Gradle builds without leaving the editor or hand-editing build files; keep conventions (catalog vs inline versions, Kotlin DSL) consistent with the repo.
- **Pain Points:** Manual `mkdir` + build-file authoring; the merge/edit of `settings.gradle.kts` and root `build.gradle.kts` is error-prone; version drift between modules; duplicated `include()` entries; no way to get a working module scaffold quickly.
- **Tech Proficiency:** High (Lua configs, LSP, Git, Gradle).

### Secondary Persona: Multi-Module Repository Maintainer

- **Role:** Senior engineer / tech lead owning the build configuration of a large Kotlin monorepo (many Gradle modules).
- **Goals:** Standardize how modules are created so all contributors get consistent scaffolds, correct `apply false` plugin declarations, and correct catalog usage; enforce conventions without writing documentation nobody reads.
- **Pain Points:** Inconsistent hand-written module build files; contributors who add `include()` at the wrong place or duplicate it; contributors who inline versions instead of using the catalog; PR review time spent fixing build-file scaffolding.
- **Tech Proficiency:** High.

---

## User Stories & Requirements

### Feature Area 1: Wizard Launch

#### User Story (US-1)

```
As a Kotlin/Spring developer,
I want to launch a "New Kotlin Module" wizard with a single command or keymap,
So that I can create a Gradle module without leaving Neovim or hand-editing build files.

Acceptance Criteria:
- Command `:NewKotlinModule` is registered by the plugin's `plugin/` directory and works with no additional setup.
- The plugin's README documents a recommended keymap `vim.keymap.set("n", "<leader>km", ":NewKotlinModule<CR>")` (leader is space in the target environment).
- The command works when invoked from any buffer inside the target Gradle project.
- The command is a no-op with a clear error notification if no Gradle project root is detected.
- Repeated invocation opens a fresh wizard (no stale state carried over).
```

#### Requirements

- Register `:NewKotlinModule` (user command) in `plugin/` directory.
- Lazy-load the plugin on command invocation (plugin/command activation; works with `vim.pack`, `lazy.nvim` `cmd = { "NewKotlinModule" }`, and `packer.nvim`).
- Document the recommended `<leader>km` mapping in README (plugin must not define global mappings by default).

---

### Feature Area 2: Project Root Detection

#### User Story (US-2)

```
As a Kotlin/Spring developer,
I want the wizard to detect the Gradle project root automatically,
So that I don't have to specify where the multi-module build lives.

Acceptance Criteria:
- **Root detection is settings-first, in two phases.** Phase (a) build root: walk upward from the current buffer's directory (or `vim.fn.getcwd()` fallback) to the first ancestor containing `settings.gradle` or `settings.gradle.kts`; this settings file defines the build root and is the only anchor for module registration. Phase (b) diagnostics: the remaining kotlin-lsp markers (`pom.xml`, `build.gradle`, `build.gradle.kts`, `workspace.json`) are used only as fallback hints and in error messages, never as the root anchor.
- Invoking the wizard from inside an existing module directory (which contains its own `build.gradle.kts`) must still resolve to the build root, not the subproject directory.
- A settings file (`settings.gradle` / `settings.gradle.kts`) is required for module registration; its presence/absence is reported clearly to the user.
- If no settings file is found anywhere up to the filesystem root, the wizard aborts immediately with a `vim.notify` error listing the markers searched and the search start directory.
- The detected root is used for every subsequent read/write operation (all paths resolved against it).
```

#### Requirements

- `lua/kotlin-module/project.lua` owns root discovery: an upward walk for the settings file (`vim.fs.find(..., { upward = true })` or a manual walk) with kotlin-lsp markers as diagnostics, `vim.fs.dirname` for path manipulation, `vim.uv.fs_stat` for existence checks.
- Root detection is a distinct module so it can be unit-tested in isolation; a fixture covers "wizard invoked from inside an existing module."

---

### Feature Area 3: Module Name & Package Validation

#### User Story (US-3)

```
As a Kotlin/Spring developer,
I want invalid or colliding module names and packages to be rejected before anything is written,
So that I never corrupt the build or create a module that Gradle cannot include.

Acceptance Criteria:
- Module name validation rejects: empty input; names containing `/`, `:`, whitespace, or control characters; names starting with `.`; reserved names (`.`, `..`, `build`, `gradle`, `settings`, `settings.gradle`, `settings.gradle.kts`); and any name that is not a valid single Gradle path segment.
- Module name collision checks against BOTH (a) the normalized include-set of existing `include(…)` entries in the settings file (handles colon-less, multi-arg, and commented forms — see Feature Area 8) and (b) existing directories under the project root; both checks must pass.
- Base package validation requires a valid dotted identifier: one or more segments, each matching `[A-Za-z_][A-Za-z0-9_]*`, no leading/trailing dot, no empty segments; multi-segment packages are allowed (e.g., `com.example`).
- Filesystem-safety rules beyond the path-segment check: names that are Windows reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`), trailing dots/spaces (Windows), and case-insensitive collisions on case-insensitive filesystems are rejected; a name colliding with an existing *file* (not directory) at the target location is rejected.
- Validation messages are shown via `vim.notify` with actionable wording (e.g., "Module name `foo/bar` is not a valid Gradle path segment").
- Validation happens interactively at input time; an invalid value re-prompts rather than failing the whole wizard.
- No files are created or modified before all validations pass.
```

#### Requirements

- `lua/kotlin-module/validate.lua` exposes pure, unit-testable validators: `validate_module_name`, `validate_package`, `module_collides` (dir + include-list aware).
- Validation is input-time (re-prompt) and gate-time (final confirm) — defense in depth.

---

### Feature Area 4: Kotlin JVM Library Module Type

#### User Story (US-4)

```
As a Kotlin/Spring developer,
I want to create a "Kotlin JVM Library" module that matches what IntelliJ generates,
So that I get a buildable library module wired into the multi-module build with no manual work.

Acceptance Criteria:
- Creates directory tree `<root>/<module>/src/main/kotlin/<pkg>/`, `<root>/<module>/src/test/kotlin/<pkg>/`, plus empty `src/main/resources/` and `src/test/resources/` (IntelliJ's standard four-dir source layout — F21).
- Generates `build.gradle.kts` applying the `org.jetbrains.kotlin.jvm` plugin; when a version catalog is in use this is `alias(libs.plugins.kotlinJvm)`, otherwise `id("org.jetbrains.kotlin.jvm") version "<kotlinVersion>"` (or no version when the root build script already declares it — F22).
- Generates a sample library stub class (e.g., `Greeter.kt` with a public function) under `src/main/kotlin/<pkg>/` and a matching unit-test stub (e.g., `GreeterTest.kt` using kotlin.test) under `src/test/kotlin/<pkg>/`.
- Does NOT emit an explicit `kotlin-stdlib` dependency (KGP adds it automatically); DOES emit `testImplementation(kotlin("test"))` (catalog: `testImplementation(libs.kotlin.test)` with a `[libraries] kotlin-test` entry merged on demand) so the kotlin.test-based test stub compiles without edits.
- The module is registered in `settings.gradle.kts` via `include(":<module>")` and its plugin is declared `apply false` in the root build script (see Feature Areas 6–8).
- The generated module is buildable by a standard `gradle :<module>:build` with no manual edits in the QA fixture environment.
```

#### Requirements

- `lua/kotlin-module/types/jvm-lib.lua` encapsulates the JVM Library template: file list (four-dir source layout: `src/main/kotlin`, `src/main/resources`, `src/test/kotlin`, `src/test/resources`), content templates (with `<pkg>`, `<module>`, `<kotlinVersion>` placeholders), and Gradle plugin + dependency requirements (incl. `testImplementation(kotlin("test"))`).
- Sample code must be valid idiomatic Kotlin with no compile-time errors when generated against the fixture Kotlin version; `gradle :<module>:build` must pass in the QA fixture (covered by a real-Gradle smoke test, not just content assertions).

---

### Feature Area 5: Spring Boot Module Type

#### User Story (US-5)

```
As a Kotlin/Spring developer,
I want to create a "Spring Boot" module with the standard boot scaffold,
So that I get a runnable Spring Boot application wired into the build without hand-writing build files.

Acceptance Criteria:
- Creates directory tree `<root>/<module>/src/main/kotlin/<pkg>/` and `<root>/<module>/src/test/kotlin/<pkg>/`, plus empty `src/main/resources/` and `src/test/resources/` (IntelliJ's standard four-dir source layout — F21).
- Generates `build.gradle.kts` applying `org.jetbrains.kotlin.jvm`, `org.jetbrains.kotlin.plugin.spring`, `org.springframework.boot`, and `io.spring.dependency-management` plugins (catalog aliases when available: `libs.plugins.kotlinJvm`, `libs.plugins.kotlinSpring`, `libs.plugins.springBoot`, `libs.plugins.springDependencyManagement`; inline `id(…) version "…"` otherwise). The `kotlin-spring` plugin is required so that `@Configuration`/`@SpringBootApplication` classes (final by default in Kotlin) can be CGLIB-proxied — matching what start.spring.io generates by default.
- Generates a sample `Application.kt` annotated `@SpringBootApplication` with a `main` function under `src/main/kotlin/<pkg>/`, plus a test stub. The build file sets the runnable main class explicitly: `application { mainClass.set("<pkg>.ApplicationKt") }` (Boot does not auto-resolve Kotlin file-derived main classes for `bootRun`/`bootJar`), and declares a `kotlin { jvmToolchain(...) }` toolchain block **only when a toolchain resolver (e.g., Foojay) or a daemon toolchain is available; the value is derived from the project's detected/dialed JDK feature version (fallback `21`)** — mirroring IntelliJ's conditional `withKotlinJvmToolchain(selectedJdkJvmTarget)` (F24).
- Spring Boot module generation resolves the Kotlin version and Spring Boot version **inheritance-first**: probe the root `plugins {}`, a sibling module, and `pluginManagement` for an already-pinned version (F22/F29); use it as the pre-filled default, or omit the version from the module file when the root already declares the plugin. Fall back to configurable `opts` defaults. Where the Boot BOM aligns the Kotlin version, the Kotlin prompt may be skipped with a note.
- Does NOT emit an explicit `kotlin-stdlib` dependency (KGP adds it automatically); Spring Boot dependencies declared per the boot-dependency-management plugin convention.
- The module is registered in `settings.gradle.kts` and its plugins declared `apply false` in the root build script.
- The generated module is buildable by `gradle :<module>:build` with no manual edits AND starts successfully (`bootRun` or a startup smoke test in the QA fixture environment) in the QA fixture environment.
- Test stubs resolve: the build file declares `testImplementation(kotlin("test"))` (catalog: `testImplementation(libs.kotlin.test)` with a `[libraries] kotlin-test` entry merged on demand) so the generated test compiles without edits.
```

#### Requirements

- `lua/kotlin-module/types/spring-boot.lua` encapsulates the Spring Boot template (same contract as `jvm-lib.lua` — four-dir source layout — plus kotlin-spring plugin, `mainClass`, conditional JDK-derived toolchain).
- Default Kotlin/Spring Boot versions live in a single config table (`opts`) so they can be updated without touching templates.
- The generated Boot module must pass a startup smoke test in the QA fixture (see M2/M3), not merely compile.

---

### Feature Area 6: Version Catalog vs. Inline Fallback

#### User Story (US-6)

```
As a Kotlin/Spring developer,
I want the plugin to automatically use my project's version conventions,
So that new modules stay consistent with existing modules and the build keeps working.

Acceptance Criteria:
- The plugin always probes for a version catalog first. **Catalog mode is enabled by the presence of `gradle/libs.versions.toml` alone** — Gradle auto-imports this default path as the `libs` catalog with no `versionCatalogs` block required (the presence of an explicit `versionCatalogs` reference in the settings file is only a secondary confirmation signal, never a gate).
- Catalog mode: generated module build files reference plugins via `alias(libs.plugins.<name>)`; missing catalog entries (plugin aliases and/or version keys, e.g. `kotlin` and `spring-boot` versions) are merged into `gradle/libs.versions.toml` WITHOUT duplicating existing keys and WITHOUT disturbing existing `[versions]`, `[libraries]`, `[plugins]`, `[bundles]` content. When merging a missing version key, prefer an **observed** project version (root `plugins {}`, a sibling module, or `pluginManagement` — F25) over the baked-in `opts` default.
- Inline mode (no catalog): module build files use `id("org.jetbrains.kotlin.jvm") version "<kotlinVersion>"` (and spring boot/dependency-management equivalents); the root build script declares the same `id(…) version "…" apply false`. **Version resolution is inheritance-first (F22):** probe the root `plugins {}`, a sibling module, and `pluginManagement` for an already-pinned Kotlin (and Spring Boot) version; use the observed version as the pre-filled prompt default, or **omit the version entirely** in the module build file when the root build script already declares the plugin id with a version (IntelliJ's `usesParentKotlinVersion` / `usesPluginManagementKotlinVersion` / `usesVersionCatalogVersionInBuildSrc` behavior). Fall back to `opts` defaults only when nothing is observed.
- If a `gradle/libs.versions.toml` appears in the project after a later run (was absent, now present), the plugin switches to alias mode on the next generation.
- Idempotency: running generation twice for the same module/type never duplicates `include`, plugin declarations, catalog keys, or version entries.
- **Existing build wiring wins (F23):** if the project wires Kotlin via a `buildSrc` convention plugin (e.g. `id("buildsrc.convention.kotlin-jvm")`) or declares KGP as a `[libraries]` catalog entry (`kotlinGradlePlugin = { module = "org.jetbrains.kotlin:kotlin-gradle-plugin", version.ref = "kotlin" }` — the pattern IntelliJ's own generated multi-module samples use), the plugin recognizes that shape and reuses it for the new module's build file instead of forcing a fresh `alias(libs.plugins.kotlinJvm)` declaration.
- **Kotlin↔Gradle compatibility warning (F26):** before writing, the plugin emits a non-blocking `vim.notify` warning when the resolved Kotlin version is known-incompatible with the project's Gradle version (mirrors IntelliJ's `KotlinGradleCompatibilityStore` gate, but as a warning not a hard stop).
```

#### Requirements

- `lua/kotlin-module/gradle.lua` owns catalog probing (fs presence check for `gradle/libs.versions.toml`, with the `versionCatalogs` block read as a secondary signal only), version-inheritance probing (root `plugins {}` / sibling module / `pluginManagement` — F22/F25), buildSrc-convention & KGP-as-library detection (F23), the Kotlin↔Gradle compatibility check (F26), and all catalog/file mutations.
- Catalog merge is **resolved by plugin id, not key name**: an existing catalog may already declare the plugin under a different alias (e.g. `kotlin-jvm` vs `kotlinJvm`); the merge reuses an existing key and its `version.ref` when the plugin id is already present, and only adds a new key when the id is truly absent. Line-oriented: parse keys, add only missing entries, preserve ordering and all other content byte-for-byte.
- Newly created catalog aliases follow IntelliJ/Spring Initializr-style camelCase conventions (`kotlinJvm`, `springBoot`, `springDependencyManagement`), but the resolver never assumes a preferred key name for existing catalogs.

---

### Feature Area 7: Root Build Script Auto-Creation

#### User Story (US-7)

```
As a Kotlin/Spring developer,
I want the plugin to create a minimal root build.gradle.kts when one is missing,
So that the new module's plugins are declared with apply false and the module stays buildable.

Acceptance Criteria:
- If no root `build.gradle.kts` exists at the project root, the plugin creates one containing a `plugins {}` block declaring the new module's plugins with `apply false` (catalog aliases or inline versions, consistent with Feature Area 6).
- The newly created root build script is minimal and valid: no phantom dependencies, no unrelated content.
- If a root build script already exists, the plugin merges ONLY the missing `apply false` plugin declarations into its `plugins {}` block (see Feature Area 8 for merge rules); all other content is untouched.
- The module is buildable **without any root-level declarations** (inline plugins in the module file work even if the root file is absent or minimal).
- The created/merged root file is reported in the success notification.
```

#### Requirements

- Root-file creation is gated on `vim.uv.fs_stat` checks (never overwrite an existing file).
- Generated root file template is version-consistent with the module file (same catalog/inline decision).

---

### Feature Area 8: Idempotent Settings & Root Merging

#### User Story (US-8)

```
As a Kotlin/Spring developer,
I want the plugin to append include(":name") and plugin declarations without disturbing my build files,
So that my settings.gradle.kts and root build.gradle.kts stay valid and un-corrupted.

Acceptance Criteria:
- `include(":<module>")` is appended to `settings.gradle.kts` (or `settings.gradle`) only if not already present; re-running never duplicates the entry.
- Collision detection uses a **normalized include-set parser** (not string-exact matching): it handles the colon-less form `include("foo")` (equivalent to `include(":foo")`), multi-argument `include(":a", ":b")`, commented entries `include(":foo") // comment`, and dynamic patterns such as `include(":lib:*")`. Only after parsing all include statements into a normalized project-name set is a name treated as "already included."
- The merge preserves all existing blocks byte-for-byte: `pluginManagement`, `dependencyResolutionManagement`, BOM/repositories/dependency blocks, comments, and blank lines. The file's dominant end-of-line convention (LF/CRLF) is detected and preserved; a UTF-8 BOM is never split or duplicated; a missing trailing newline is normalized only for the inserted lines.
- The root `plugins {}` block receives only the missing `id(…) version "…" apply false` / `alias(libs.plugins.…) apply false` lines. **Deduplication is by plugin id, not by line text**: if the root (or catalog) already declares a plugin id with a different version, the plugin does NOT add a second declaration — it reuses the existing declaration/version and logs "reused existing version", or aborts with a clear notification; it never writes a duplicate plugin declaration (which would fail the build with "plugin already requested").
- Merging is implemented with tolerant line-based logic (block-aware insertion points), NOT fragile regex substitution over the whole file.
- **Two-phase commit with rollback.** Phase 1 validates all target file states and computes every mutation with no writes. Phase 2 performs the writes; if any write fails after the first (permission denied, disk full), the plugin deletes only the files/directories created by this invocation (they provably did not exist before) and reports a rollback notice — leaving no partial state. Merged files are written atomically (temp file + rename) where possible.
- If the settings file or root build file cannot be parsed to a safe insertion point, the wizard aborts with a clear error and NO files are written (no partial state).
- The merge is validated by fixture tests for: catalog-present (incl. the conventional blockless `libs.versions.toml`), catalog-absent, missing-root-file, existing-module-collision, colon-less include, multi-arg include, plugin-id version conflict, CRLF/BOM, buildSrc-convention-plugin wiring, KGP-as-library (`[libraries] kotlinGradlePlugin`) wiring, and idempotent double-run shapes.
```

#### Requirements

- `lua/kotlin-module/gradle.lua` implements the mutation engine; all merge logic is pure functions over line tables so it is testable without a running Neovim. It also exposes the normalized include-set parser shared with `validate.lua`.
- Every mutation returns the exact diff/insertions performed for the success notification and for tests.
- Safety invariant (tested): **the plugin only ever appends or inserts missing lines; it never deletes or rewrites existing user content, and it never writes a duplicate plugin declaration or `include` entry.**
- Rollback safety invariant (tested): a failure mid-write removes only paths created by the current invocation; a success or cancel leaves no stray artifacts.

---

### Feature Area 9: Success Notification & Post-Generation Behavior

#### User Story (US-9)

```
As a Kotlin/Spring developer,
I want clear feedback about what was created,
So that I can verify the result and know what to do next.

Acceptance Criteria:
- On success, `vim.notify` (INFO) shows a summary listing every created path (module dir, build file, sample sources) and every modified/created Gradle file with a short description of each change. Because `vim.notify` INFO may be swallowed by user `notify` configuration, the same summary is echoed to `:messages` (or a quickfix list) as a fallback channel.
- The notification includes the module's include path (e.g., `include(":foo")`) and notes which mode was used (version catalog aliases vs. inline versions).
- The notification states explicitly that no Gradle sync/task was run (MVP behavior).
- On any validation failure, the wizard aborts with a single clear `vim.notify` error; no files were created or modified (verified by test).
- On any generation-phase failure after writes began, the plugin rolls back all paths created by this invocation, reports the rollback in the error notification, and guarantees a consistent (pre-invocation) filesystem state (verified by a failure-path test).
- On user cancel at any prompt (Esc / Ctrl-C / rejected select), the wizard exits silently or with a subtle info notification and makes zero file-system changes.
```

#### Requirements

- Single post-generation summary builder shared by both module types (report of `created_files`, `appended_to`, `created_root_script`, `mode`).
- Cancel-abort path is exercised in tests to assert zero filesystem mutation.

---

## Success Metrics

### Primary Metrics (North Star)

The North Star for a scaffolding dev-tool is **"successful modules created per user per week"** — it captures both adoption and task success. **Time-to-working-module** is the complementary efficiency metric.

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Successful modules created per user per week (opt-in telemetry / manual surveys) | 0 (new product) | ≥ 2 / week for active users (top decile ≥ 5) | By 2027-03-31 |
| Time-to-working-module (wizard start → first `gradle build` succeeds, no manual edits) | N/A (manual flow ~5–15 min) | ≤ 3 min median; ≤ 1 min for wizard portion | By 2026-12-31 |

> **Note on measurement:** the MVP makes **no network calls** (security constraint), so per-user metrics cannot be collected automatically in MVP. For MVP, North Star progress is measured via manual QA sessions and opt-in user surveys; opt-in telemetry (disabled by default, clearly documented, `opts`-gated, with an explicit privacy posture covering what is collected and why) is proposed for v1. GitHub stars and **release-asset download counts** are the public adoption proxies — GitHub clone counts are noisy and are **not** install counts, `vim.pack` has no lockfile-report mechanism, and no README "install badge" exists for Neovim plugins, so those are explicitly not used. "Active user" is defined as a user who has created ≥ 1 module in the reporting period; "wizard session" is a wizard invocation that reaches the final confirmation summary.

### Secondary Metrics

| Metric | Baseline | Target |
|--------|----------|--------|
| GitHub stars | 0 | ≥ 100 by 2027-03-31 |
| GitHub release-asset downloads (API-measured proxy for installs; clones are not counts) | 0 | ≥ 25 by 2027-03-31 |
| Module-scaffold acceptance rate (QA + user reports: module builds with no manual fixes) | N/A | ≥ 95% of generated modules |
| Repeat wizard use per active user per month (v1 opt-in telemetry; MVP proxy: self-reported in survey) | N/A | ≥ 50% of active users use the wizard ≥ 2×/month (target set in the v1 telemetry window) |
| Build-file corruption bug reports (category: user's Gradle files damaged by plugin) | N/A | **0** sustained 30 days post-v1 |
| First-run success (new user, all four fixture project shapes) | N/A | 100% of fixture test shapes pass on CI |

### Framework: HEART (primary) + OKRs (reporting)

**HEART mapping** (recommended for user-centric dev tools; the plugin is a user-experience product whose core value is task completion):

| HEART dimension | Metric(s) | How measured |
|-----------------|-----------|--------------|
| **Happiness** | Issue-rate inverse, "works first time" reports, plugin discussion/survey sentiment | GitHub issues/discussions triage, opt-in survey (v1) |
| **Engagement** | Modules created per week; wizard sessions per user | Opt-in telemetry (v1); QA logs (MVP) |
| **Adoption** | GitHub stars, release-asset downloads, README-driven first-run success | GitHub API release/download stats |
| **Retention** | Repeat wizard use per month; module-creation rate trend | Opt-in telemetry (v1); user interviews |
| **Task Success** | Time-to-working-module; scaffold acceptance rate; build-file corruption rate | Manual QA (MVP); opt-in telemetry + issue triage (v1) |

**OKRs (reporting frame for the first release cycle):**

```
Objective: Become the standard way to add Kotlin/Spring modules to multi-module Gradle builds in Neovim.

Key Results:
- KR1: Launch v0.1 (MVP) publicly with README, MIT license, docs/, and CI test suite by 2026-10-30.
- KR2: Reach 0 build-file-corruption bug reports for 30 consecutive days after v1 by 2027-01-31.
- KR3: Achieve ≥ 95% scaffold-acceptance rate across the four fixture project shapes by 2026-12-31.
- KR4: Reach ≥ 100 GitHub stars and ≥ 25 release-asset downloads by 2027-03-31.
- KR5: 100% of reported wizard-crash bugs fixed within 14 days (issue-response SLO).
```

---

## Scope

### In Scope (MVP)

**Delivery**

- Standalone plugin repository: `README.md`, MIT `LICENSE`, minimal `docs/`, full test suite.
- Consumable in the target dotfiles via `vim.pack.add { { src = gh '<user>/kotlin-module.nvim' } }` inside a `lua/plugins/*.lua` file; also installable via `lazy.nvim` and `packer.nvim` (generic plugin repo shape).

**MVP module types (exactly two)**

1. **Kotlin JVM Library** — `org.jetbrains.kotlin.jvm` plugin, library semantics, four-dir source layout (`src/main/kotlin/<pkg>/`, `src/main/resources/`, `src/test/kotlin/<pkg>/`, `src/test/resources/`), sample lib stub class + unit-test stub.
2. **Spring Boot module** — `org.jetbrains.kotlin.jvm` + `org.jetbrains.kotlin.plugin.spring` + `org.springframework.boot` + `io.spring.dependency-management` plugins, `@SpringBootApplication Application.kt` sample in `src/main/kotlin/<pkg>/` + test stub, `application { mainClass.set("<pkg>.ApplicationKt") }`, conditional JDK-derived toolchain.

**Wizard UX**

- Chained `vim.ui.select` / `vim.ui.input` prompts (standard UI hooks; automatically enhanced by telescope-ui-select or dressing when present; graceful default UI otherwise). No hard dependency on nui.nvim or telescope.
- Wizard inputs: module name (validated), base package (validated dotted identifier), module type (JVM Library | Spring Boot), build-script DSL (informational, defaults to Kotlin DSL — if a user selects Groovy, the wizard aborts with "Groovy `build.gradle` generation is not supported in MVP"; Groovy `settings.gradle` merging is supported), and — for Spring Boot and for inline-version mode — Kotlin/Spring Boot versions with sensible defaults.
- Graceful cancel/rejection at any step with zero partial writes.

**Gradle integration depth (all required for MVP)**

1. Append `include(":<module>")` to `settings.gradle.kts` (or `settings.gradle`) without duplicating entries; tolerant line-based merge that preserves `pluginManagement` / `dependencyResolutionManagement` / BOM blocks.
2. Ensure module plugins declared in root `build.gradle.kts` `plugins {}` block with `apply false` (via version-catalog alias when catalog in use).
3. Version catalog handling: probe for `gradle/libs.versions.toml` (file presence = catalog mode; an explicit `versionCatalogs` reference is a secondary signal only); use `alias(libs.plugins.kotlinJvm)` etc. and merge missing version/plugin entries by plugin id without duplicating keys. No catalog → inline `id("…") version "<ver>"` in the module build file and matching `id(…) version "<ver>" apply false` in root. Always probe for catalog first; switch to alias mode if a catalog appears later. Wizard prompts for versions (pre-filled defaults) in inline mode.
4. If root `build.gradle.kts` does not exist, auto-create a minimal root build script declaring the module plugins with `apply false` (module remains buildable without any root-level declarations via inline plugins).
5. Generate sample code files per module type.
6. Post-generation: `vim.notify` success summary listing created paths. **Never execute a Gradle sync in the MVP.**

### Out of Scope

**Explicitly excluded (MVP):**

- Kotlin Multiplatform (KMP) module type.
- Android module type.
- Kotlin JVM **Application** module type.
- Running Gradle tasks / `gradle sync`; any Gradle daemon interaction.
- `gradle init` new-project flow (creating a build from scratch — that is `gradle.nvim`'s domain).
- IntelliJ `.iml` / `.idea` generation.
- Maven builds (`.pom`-based projects).
- Custom source-set creation.
- Network calls of any kind.

**Deferred (later phases — see Timeline):**

- Option B: create a version catalog during generation when none exists.
- Option C: migrate an existing inline-version module to catalog aliases ("switch inline → alias").
- Additional module types (KMP, Android, Application), Maven support, opt-in telemetry.

---

## Technical Considerations

### Architecture

Pure-Lua plugin with a small, testable module graph. Proposed repo layout:

```
kotlin-module.nvim/
├── plugin/
│   └── kotlin-module.lua          # registers :NewKotlinModule (user command)
├── lua/kotlin-module/
│   ├── init.lua                   # public API: setup(opts), command entry point
│   ├── project.lua                # settings-first root discovery (upward walk), project model
│   ├── wizard.lua                 # chained vim.ui.select/input state machine, cancel handling
│   ├── validate.lua               # pure validators (module name, package, collision checks)
│   ├── types/
│   │   ├── jvm-lib.lua            # JVM Library template (files, content, plugin requirements)
│   │   └── spring-boot.lua        # Spring Boot template
│   └── gradle.lua                 # ALL file mutations: settings merge, root merge, catalog merge, root auto-create
├── tests/                         # busted or mini.test suite
├── docs/                          # minimal docs (wizard flow, config, conventions)
├── README.md
└── LICENSE                        # MIT
```

**Data flow:** `:NewKotlinModule` → `init.lua` → `project.lua` (root detection) → `wizard.lua` (collect inputs via `vim.ui.*`, validate via `validate.lua`) → template selection (`types/*.lua`) → `gradle.lua` (validate file states, compute mutations, apply idempotent writes) → `init.lua` reports via `vim.notify`. Every module boundary is a pure-function seam (file reads in, mutation lists out), enabling fixture-based tests without a full Neovim harness.

**Runtime APIs used:** `vim.fs.root`, `vim.fs.dirname`, `vim.uv.fs_mkdir`, `vim.uv.fs_stat`, `vim.uv.fs_read`/`fs_write` (or `vim.fs` read helpers), `vim.system` (only for nothing in MVP — reserved for future gradle-command integration), `vim.ui.select`, `vim.ui.input`, `vim.notify`.

### Dependencies

**Required runtime dependencies:** none (the plugin is deliberately dependency-free). `vim.ui` is the only UI surface; it is the standard hook that `telescope-ui-select` / `dressing.nvim` upgrade — the plugin benefits automatically when those are present, and degrades gracefully to the default `vim.ui` implementation when they are not. `nui.nvim` is present in the target environment but is **not** a dependency of this plugin.

**Dev/test dependencies:** `busted` or `mini.test` for the test suite; a small fixture repo with pinned Gradle/KGP/Spring Boot versions for integration-style assertions (or pure content-assertion tests that avoid needing a JVM — preferred to keep CI light).

### Test Strategy

- **Unit tests (JVM-free, primary):** pure functions in `validate.lua` and `gradle.lua` (merge plans, include-set parser, catalog merge, validators) asserted against line/table inputs. This is the bulk of the suite and runs with zero JVM.
- **Engine fixtures:** the full mutation engine applied to representative project fixtures (catalog-present incl. blockless, catalog-absent, missing-root-file, collision, colon-less/multi-arg includes, plugin-id version conflict, CRLF/BOM, buildSrc-convention & KGP-as-library wiring, inheritance-first version omission), asserting byte-for-byte preservation of non-inserted content and idempotent double-application (no-op).
- **Headless wizard tests:** `wizard.lua` driven against a **fake `vim.ui`** stub covering happy path, per-step cancel, invalid-input re-prompt, and the abort-before-write / rollback guarantees.
- **Real-Gradle smoke tests (M2/M3):** for each MVP module type, generate into a scratch fixture and run `./gradlew :<module>:build` (and, for Spring Boot, a startup smoke test); assert green with no manual edits. Requires a JVM — run on CI as a separate optional job to keep the default CI light.
- **QA matrix:** manual QA sessions (≥ 10, per O4) across all four fixture shapes, timed for the time-to-working-module metric.

### Security

- **Never overwrite user files.** The plugin only ever *appends* or *inserts missing lines*; any mutation that would require rewriting existing content aborts with a clear error.
- **Abort-on-doubt.** Any validation failure, unparseable insertion point, or unexpected file shape → abort with a clear message and **zero file writes** (no partial state; enforced by tests).
- **Rollback on write failure.** Generation is two-phase (compute-all, then write). If any write fails after the first, the plugin deletes only the files/directories it created (which provably did not exist before) and reports the rollback; merged files are written atomically (temp file + rename) where possible. A failure never leaves a partially-created module or a partially-merged build file.
- **No network calls in MVP.** No HTTP, no Gradle daemon, no plugin portal fetches. Version defaults are baked into config.
- **No `eval`/`execute` of user build-file content.** Merges operate on parsed line/key structures, never on executing or interpreting user scripts.
- **Graceful cancel.** Esc/Ctrl-C at any wizard step leaves the filesystem untouched.
- Plugin code should be reviewed for path traversal: module name and package are validated before being used in path construction (no `/`, no `..` segments).

### Performance

- Wizard interactions are synchronous and trivial (prompt latency is the only perceptible wait; target < 100 ms per step including validation).
- Full generation (directory creation + file writes + three Gradle file merges) targets **< 500 ms** for a typical project with a few hundred-line settings file; file I/O is performed with `vim.uv` synchronous calls (trivial at these file sizes), keeping the implementation simple and deterministic.
- The plugin adds zero startup cost: no eager `require` at startup; lazy-loaded via the `:NewKotlinModule` command (works with `vim.pack` custom load, `lazy.nvim` `cmd` trigger, `packer.nvim`).

### Compatibility

| Dimension | Support |
|-----------|---------|
| Neovim | Target **0.12+** (native `vim.pack` environment, `vim.ui` upgrades). Minimum supported **0.10+** (`vim.fs.root`, `vim.fs.find(…, { upward = true })`, `vim.uv`, `vim.system` all present in 0.10). |
| Plugin managers | `vim.pack` (primary), `lazy.nvim`, `packer.nvim` — generic plugin repo shape (`.lua` modules + `plugin/` dir, no manager-specific code). |
| Platforms | Linux / macOS / WSL (primary QA); Windows supported via `vim.uv`/`vim.system` abstractions (best-effort, no POSIX-only calls). |
| Gradle | Gradle 7.x–8.x+ with Kotlin DSL (`build.gradle.kts`) and Groovy settings fallback (`settings.gradle`); KGP 1.9+; Spring Boot 2.7+ / 3.x defaults. |
| LSP/IDE env | Works alongside nvim-java, spring-boot.nvim, jdtls, kotlin-lsp, neotest; root markers shared with kotlin-lsp. |

---

## Design & UX Requirements

### Visual Design

- No custom UI chrome in MVP. The wizard renders entirely through `vim.ui.select` (dropdown) and `vim.ui.input` (prompt), inheriting the user's chosen UI provider (default, telescope-ui-select, or dressing). No new highlight groups in MVP (can be added later for status messages).
- Text content follows editor conventions: plain, terse, action-first labels (e.g., `[1] Kotlin JVM Library  [2] Spring Boot`).
- Success/error notifications use `vim.notify` levels `INFO` / `ERROR` respectively; info-level summary is collapsed-friendly (concise list).

### Interaction Patterns

- **Chained prompts** with a strict order: **(1) module type** → **(2) module name** → **(3) base package** → **(4) build-script DSL** (informational; Kotlin DSL is the default and the only generating option in MVP — selecting Groovy aborts with a clear message) → **(5) versions when in inline mode** (Kotlin; plus Spring Boot for boot modules; pre-filled sensible defaults) → **(6) final confirmation summary** → generate.
- **Inheritance pre-fills (F29, IntelliJ short-flow parity):** where the project already pins conventions, prompts pre-fill from the project instead of asking fresh — base package pre-fills from an existing sibling module's package/group where detectable; DSL pre-fills from the existing settings/build dialect; version prompts pre-fill from the observed root/sibling/`pluginManagement` version (F22). Every pre-fill remains overridable.
- Each prompt shows a short context header (e.g., `kotlin-module: module name [enter to confirm, <Esc> to cancel]`).
- Confirmation summary displays: module path, package, type, DSL, mode (catalog aliases vs inline versions), and the list of files to be created/modified — user confirms or cancels.
- Rejection of invalid input re-prompts in place (does not restart the wizard).
- Back/cancel semantics: `<Esc>` / `Ctrl-C` anywhere exits cleanly.

### Command & Keybindings

- Command: `:NewKotlinModule`.
- Recommended mapping (documented, not set by default): `vim.keymap.set("n", "<leader>km", ":NewKotlinModule<CR>", { desc = "New Kotlin Module" })` — fits the space-leader target environment.

### Error & Validation UX

- Errors are specific and actionable. Examples: `No Gradle project root found (searched for settings.gradle, settings.gradle.kts, pom.xml, build.gradle, build.gradle.kts, workspace.json from <dir>)`; `Module name 'foo/bar' is not a valid Gradle path segment`; `Module 'foo' already exists in settings.gradle.kts (include(":foo"))`; `Cannot find a safe insertion point in settings.gradle.kts — aborting, no changes made`.
- **Abort-before-write guarantee:** any error surfaced to the user before generation means the filesystem was not modified (explicitly tested); if an error occurs *during* generation, the plugin rolls back everything it created (explicitly tested) and reports the rollback.
- Where a failure is ambiguous, the plugin errs on the side of aborting and asks the user to create the module manually, rather than guessing.

### User Flows

**Happy path (catalog project, Spring Boot module):**

1. User runs `:NewKotlinModule` (or `<leader>km`) from a buffer inside the project.
2. Plugin detects the build root by walking upward from the buffer for the settings file; finds `settings.gradle.kts` and `gradle/libs.versions.toml` present → catalog mode.
3. Wizard: select **Spring Boot** → enter `order-service` → enter `com.acme.order` → Kotlin DSL (default) → versions pre-filled (skipped in catalog mode) → confirm summary.
4. Plugin creates `order-service/` tree + `Application.kt` + test stub; appends `include(":order-service")` to settings; adds `alias(libs.plugins.kotlinJvm)`, `alias(libs.plugins.kotlinSpring)`, `alias(libs.plugins.springBoot)`, `alias(libs.plugins.springDependencyManagement) apply false` to root `plugins {}`; merges missing catalog keys; writes `mainClass` and `testImplementation(kotlin("test"))` per the template contract.
5. `vim.notify` INFO summary lists all created/modified files + mode used.

**Fallback path (no catalog):** same as above, but wizard additionally prompts for Kotlin version (pre-filled via inheritance — F22 — else `2.4.x`, matching IntelliJ's current bundled default of 2.4.10) and, for boot, Spring Boot version (pre-filled `3.5.x`); module + root build files use inline `id(…) version "…"` (version omitted when the root already declares the plugin); success summary notes "inline versions (no version catalog detected)".

**Cancel path:** user hits `<Esc>` at step 3 → silent exit, zero changes.

**Error path (collision):** user enters a module name that already exists → error notification, re-prompt, no writes.

### Accessibility

- All interactions are keyboard-driven (no mouse requirement).
- Prompts and notifications are plain text compatible with screen-reader/reduced-motion setups; no color-only signaling (icons not required; text carries the message).
- High-contrast default: relies on the user's colorscheme and standard `vim.notify`/`vim.ui` highlight links, which respect `background=` and custom colorschemes.

---

## Timeline & Milestones

| Milestone | Target Date | Deliverables |
|-----------|-------------|--------------|
| M0 — Design freeze | 2026-08-31 | PRD sign-off; **template-content contract agreed** (exact `build.gradle.kts`/sample-code contents per module type, reviewed against the "buildable with no manual edits" ACs — incl. kotlin-test dependency, kotlin-spring plugin, `mainClass`, conditional JDK-derived toolchain, four-dir source layout, inheritance-first version handling); module-layout agreed; fixture project shapes specified; plugin name availability verified |
| M1 — Spike/validation | 2026-09-15 | Proof that tolerant line-based merge handles the fixture shapes (incl. settings-first root resolution from inside an existing module); template-content contract reviewed against "buildable, no manual edits" ACs; Groovy-settings merge scope resolved; buildSrc-convention & KGP-as-library detection validated (F23); pinned Gradle/KGP/Spring Boot version set published |
| M2 — MVP alpha | 2026-10-15 | `:NewKotlinModule` end-to-end for both module types; wizard + validation; all six Gradle-integration items implemented |
| M3 — MVP release (v0.1) | 2026-10-30 | README, MIT LICENSE, docs/, full test suite green on CI; released for `vim.pack`/lazy/packer |
| M4 — v1 | 2026-12-31 | O4 metrics met (≤ 3 min time-to-working-module); O3 corruption-rate goal entered; issue triage SLO active |
| M5 — v1.1 / later | 2027-03-31 | Option B + Option C landed; adoption KRs reviewed |

### Phase 1: MVP (v0.1) — 2026-09-01 → 2026-10-30

Wizard + validation + the two module types + all six required Gradle-integration behaviors + test suite + packaging. **Explicitly excluded:** KMP/Android/Application types, Maven, any Gradle execution, catalog creation (Option B), inline→alias migration (Option C).

### Phase 2: v1 — 2026-11-01 → 2026-12-31

Hardening: broad fixture coverage (more project shapes, Groovy settings variants, exotic-but-valid `settings.gradle.kts` layouts), edge-case UX polish, docs expansion (troubleshooting, migration notes for `gradle.nvim` users), opt-in telemetry design (still disabled by default), and the reporting dashboards for HEART/OKR metrics.

### Phase 3: Later (post-v1.1)

- **Option B — "create catalog during generation":** when no `gradle/libs.versions.toml` exists, optionally scaffold one (with `versionCatalogs` wiring in settings) instead of falling back to inline versions.
- **Option C — "switch inline → alias":** a maintenance command that migrates an existing inline-version module's build file (and root declarations) to catalog aliases once a catalog is introduced.
- Candidate backlog: Kotlin Multiplatform / Android / Application module types; Maven support; custom source-set creation; `gradle :<module>:build` post-generation command (needs `vim.system` integration + explicit opt-in).

---

## Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Gradle DSL syntax drift across Gradle/KGP versions** (e.g., `apply false` semantics, catalog alias conventions, plugin-block requirements change between Gradle 8/9, KGP majors) | H — generated files silently wrong or non-buildable | M | Pin the generated templates to a documented, tested Gradle+KGP version range; fixture tests pin exact versions; keep versions in a single config table; document supported range in README; add a v1 "version guard" that warns when the user's Gradle/KGP versions are outside the tested range. |
| **Malformed or unexpected user build files** (hand-edited `settings.gradle.kts` / root file with unusual formatting, comments mid-block, `include` variants) | H — merge corrupts a user's build | M | Tolerant block-aware line-based merge with safe-insertion-point detection; **normalized include-set parsing** (colon-less, multi-arg, commented, dynamic patterns) before any presence check; abort-with-error and zero writes whenever a safe insertion point cannot be found; fixture suite covers messy-but-valid layouts; strict "never rewrite existing lines" invariant enforced by tests. |
| **Duplicate plugin-id with different version** (root `plugins {}` or catalog already declares a plugin id under another key/version; adding a second declaration fails the build with "plugin already requested") | H — build break | M | **Merge/dedupe by plugin id, never by line text or key name**: reuse the existing declaration/version and log "reused existing version", or abort with a clear notification; a dedicated fixture covers the version-conflict shape. |
| **CRLF / UTF-8 BOM / missing trailing newline** in files to be merged | M — line-based appends corrupt the file or orphan the BOM | L | Detect and preserve the file's dominant EOL; never split a BOM; normalize only inserted lines; dedicated CRLF/BOM fixtures. |
| **Read-only / permission-denied directories or unwritable settings file** | M — mid-write failure leaves partial state | L | Two-phase commit with rollback of self-created paths; atomic write (temp file + rename) for merged files; clear error including the failing path; failure-path fixture test. |
| **Absent catalog / absent root build file** (project has neither, or root build script missing) | M — module buildable but conventions not followed; generation must fall back cleanly | H (common in real repos) | Feature Area 6 (probe-first — **presence of `gradle/libs.versions.toml` alone**, inline fallback) and Feature Area 7 (minimal root auto-create) are first-class MVP behaviors with dedicated fixtures; generated inline files remain buildable without root-level declarations so the module is never a broken orphan. |
| **Version drift of Kotlin / Spring Boot defaults** (baked-in defaults become outdated vs. released versions) | M — outdated scaffolds prompt manual fixes | M | **Inheritance-first version resolution (F22)** — always prefer a version observed from the project's root/sibling/`pluginManagement` over the baked default; single configurable `opts` version table (updated at each release); wizard always allows override in inline mode; non-blocking Kotlin↔Gradle compatibility warning (F26); version-guard warning (v1) comparing default to a catalog-observed version when available. |
| **Merge corrupting settings.gradle.kts** (duplicate `include`, entry inserted inside a block, byte-level damage) | H — breaks the entire build for all modules | L (with mitigations) | Idempotent key-based `include` check before append; insertion always at a safe block boundary; byte-for-byte preservation of all other content (tested); double-run idempotency tests; the "0 corruption bugs" O3 objective gates v1 GA. |
| **AGP/KGP version skew** (Android Gradle Plugin vs KGP incompatibility in multi-module builds) | N/A for MVP — Android module type is out of scope | — | Explicitly out of scope; re-assess when Android module type is added in a later phase. |
| **Plugin naming** (`kotlin-module.nvim` provisional — name collision on GitHub / marketplace confusion with `gradle.nvim`) | L | L | Resolve naming in Open Questions; check GitHub for existing `kotlin-module.nvim`; pick an unambiguous name (e.g., `kotlin-module.nvim` vs `neovim-kotlin-wizard`) before public release; register the GitHub org/owner accordingly. |
| **kotlin-lsp / nvim-java interactions** (generated files not indexed until LSP restart) | L | M | Document "restart LSP or `:LspRestart` after module creation" in README; no plugin-side action in MVP. |

---

## Dependencies & Assumptions

### Dependencies

**Runtime (none required):** pure Neovim APIs only — `vim.fs`, `vim.uv`, `vim.ui`, `vim.notify`, `vim.system` (reserved). Optional UI enhancement is *inherited* from telescope-ui-select / dressing if the user has them.

**Dev/CI:** busted or mini.test; a small fixture repo with pinned Gradle/KGP/Spring Boot versions for integration-style assertions (pure content-assertion tests preferred to keep CI JVM-free).

**Distribution:** GitHub repo (hosted under a to-be-confirmed org/owner); git-tag-based releases consumable by `vim.pack`, `lazy.nvim`, `packer.nvim`.

### Assumptions

- The target environment is a kickstart-style dotfiles repo on **Neovim 0.12+** using **`vim.pack`**, 42 Spring/Kotlin plugins, space leader, and telescope-ui-select; the plugin targets this but remains generically installable.
- **Kotlin DSL is the default build-script dialect** (assumed overwhelmingly dominant for Kotlin projects); Groovy `settings.gradle` is supported for settings merging but no Groovy `build.gradle` templates are generated in MVP.
- Version-catalog presence is determined by the existence of `gradle/libs.versions.toml` alone (Gradle auto-imports this default path as the `libs` catalog); the presence of an explicit `versionCatalogs` block in the settings file is treated as a secondary confirmation signal only.
- Users want the module to follow existing project conventions (catalog when present, inline otherwise) rather than being asked to choose.
- The module name the user enters is intended as a top-level subproject of the detected root (single-segment `include(":name")`).
- Gradle builds in the user's project use a wrapper (`gradlew`) and standard `src/main/kotlin` / `src/test/kotlin` layout.
- The plugin's sample code is a starting scaffold the user will edit; it must compile as generated but is not intended to be production logic.

---

## Open Questions

| Question | Owner | Status | Resolution Date |
|----------|-------|--------|-----------------|
| **Plugin naming:** keep `kotlin-module.nvim` or adopt an alternative (e.g., `neovim-kotlin-wizard`, `kotlin-wizard.nvim`)? Must check GitHub for existing `kotlin-module.nvim` repo collision before release. | Maintainer | Open | Before M0 (2026-08-31) |
| **Recommended keybinding:** confirm `<leader>km` is acceptable (vs. `<leader>Km`, `<leader>gk`, or none — leave to users entirely). | Maintainer + target-user sample | Open | By M2 (2026-10-15) |
| **Default Kotlin version** for inline mode and for catalog `[versions]` creation: which baseline (e.g., `2.4.x` at time of release; IntelliJ's current bundled default is 2.4.10)? Confirm a policy for bumping defaults per release, and the pinned fixture version set (Gradle + KGP + Spring Boot) published at M1. | Maintainer | Open | By M1 (2026-09-15) |
| **Default Spring Boot version** for boot modules (e.g., `3.5.x` current at release): confirm baseline and whether to support Boot 2.7 LTS generation. | Maintainer | Open | By M1 (2026-09-15) |
| **Maven support later:** decide whether `.pom`-based projects (with kotlin-maven-plugin) should ever be supported, or remain permanently out of scope. | Maintainer + community input | Open | Post-v1 (≥ 2027-01-01) |
| **Groovy DSL generation:** should a later version generate Groovy `build.gradle` templates, or stay Kotlin-DSL-only? | Maintainer | Open | Post-v1 |
| **Opt-in telemetry** for per-user North Star metrics — design decision for v1: privacy posture (default-off, what is collected and why, local-only alternatives), definitions of "active user" / "wizard session". | Maintainer | Open | By M4 (2026-12-31) |
| **`settings.gradle` Groovy fallback:** confirm scope of Groovy settings merging (append-only `include(":x")` support) vs. abort when settings are Groovy. | Maintainer | Open | By M1 (2026-09-15) |

---

## Appendix

### Glossary

- **Multi-module build:** a Gradle build whose root is defined by a `settings.gradle` / `settings.gradle.kts` file and which registers subprojects via `include(":name")` (colon-delimited).
- **Version catalog:** a `gradle/libs.versions.toml` file exposing `[versions]`, `[libraries]`, `[plugins]`, `[bundles]`. Gradle **auto-imports** this default path as the `libs` catalog — no `versionCatalogs` block is required for it to be active.
- **`apply false`:** declaring a plugin in the root build's `plugins {}` block without applying it, so subprojects can apply it by id/alias without resolving it again.
- **KGP:** Kotlin Gradle Plugin (`org.jetbrains.kotlin.jvm`); auto-adds `kotlin-stdlib`, so no explicit stdlib dependency should be emitted.
- **Inheritance-first version resolution:** probing the root `plugins {}` block, a sibling module, and `pluginManagement` for an already-pinned Kotlin/Spring Boot version, then omitting the version from a new module's build file when the root already declares it (IntelliJ's `usesParentKotlinVersion` / `usesPluginManagementKotlinVersion` / `usesVersionCatalogVersionInBuildSrc`).
- **BuildSrc convention plugin:** a `buildSrc/` subproject defining reusable plugins (e.g. `id("buildsrc.convention.kotlin-jvm")`) plus KGP declared as a `[libraries]` catalog entry (`kotlinGradlePlugin`) — the wiring pattern IntelliJ's own generated multi-module samples use; recognized and reused rather than overridden.
- **Root markers:** files that identify a project root; for kotlin-lsp: `settings.gradle`, `settings.gradle.kts`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `workspace.json`.
- **`vim.ui` hooks:** the standard `vim.ui.select` / `vim.ui.input` override points that UI plugins (telescope-ui-select, dressing) upgrade.
- **Idempotent merge:** a mutation that produces the same final file state regardless of how many times it is applied (no duplicate `include`, keys, or plugin declarations).
- **Tolerant line-based merge:** parsing a file into block-aware line structures and inserting only missing lines at safe block boundaries, preserving all other content byte-for-byte (as opposed to whole-file regex rewriting).

### References

- IntelliJ IDEA `File → New → Module` behavior (Gradle subproject creation + settings wiring) — source of behavioral parity. Authoritative sources: JetBrains/intellij-community (master) — `plugins/kotlin/project-wizard/gradle/src/org/jetbrains/kotlin/tools/projectWizard/gradle/GradleKotlinNewProjectWizard.kt` (inheritance-first KGP version resolution via `resolveKotlinVersionToUse` + `usesParentKotlinVersion`/`usesPluginManagementKotlinVersion`/`usesVersionCatalogVersionInBuildSrc`; conditional `withKotlinJvmToolchain(selectedJdkJvmTarget)`; standard four-dir source layout in `AssetsStep`); its generated-sample templates under `plugins/kotlin/project-wizard/gradle/resources/fileTemplates/internal/` (`KotlinSampleGradleToml.toml.ft` with camelCase keys + KGP-as-`[libraries]` entry; `KotlinSampleSettings.gradle.kts.ft`; `KotlinSampleAppBuildGradle.gradle.kts.ft`; `KotlinSampleConventionPlugin.gradle.kts.ft` — buildSrc convention-plugin wiring); `plugins/kotlin/project-wizard/idea/.../BuildSystemKotlinNewProjectWizard.kt` (`DEFAULT_KOTLIN_VERSION = "2.4.10"`); `plugins/kotlin/project-wizard/idea/.../KotlinModuleBuilder.kt` (JPS builder, `DEFAULT_JVM_TARGET = "1.8"`, standard layout with resources dirs).
- `oclay1st/gradle.nvim` — existing plugin (gradle-init project creation + task execution; no add-module-to-existing-build flow; hard deps plenary + nui) — competitive gap reference.
- Neovim docs: `:h vim.pack` / `vim.pack.add`, `:h vim.fs.root()`, `:h vim.uv`, `:h vim.system`, `:h vim.ui.select`, `:h vim.ui.input`, `:h vim.notify`.
- Gradle User Manual: "Structuring Multi-Project Builds" (include syntax), "Sharing Build Logic", "Using Version Catalogs" (incl. automatic import of the default `gradle/libs.versions.toml` as `libs`), "Plugins: applying plugins with apply false".
- Spring Framework Kotlin support / start.spring.io defaults — basis for requiring the `org.jetbrains.kotlin.plugin.spring` plugin (CGLIB proxying of final `@Configuration` classes) in the Spring Boot template.
- Evgeni Chasnovski, *A Guide to vim.pack* (2026-03-13) — target environment's `vim.pack` consumption pattern (`vim.pack.add({ { src = … } })`).
- `telescope-ui-select.nvim` / `dressing.nvim` — `vim.ui.select` upgrade behavior relied upon for the "no required dependencies" UX promise.

---

*End of document — deliverable is planning/documentation only; no plugin code is included in this PRD.*
