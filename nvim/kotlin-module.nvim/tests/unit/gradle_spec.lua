package.path = "/home/test/dotfiles/nvim/kotlin-module.nvim/lua/?.lua;/home/test/dotfiles/nvim/kotlin-module.nvim/lua/?/init.lua;"
  .. package.path

local gradle = require("kotlin-module.gradle")

local SETTINGS = [[pluginManagement {
    repositories {
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

rootProject.name = "demo"

include(":app")
include(":utils")
]]

local CATALOG = [[[versions]
kotlin = "2.4.10"
spring-boot = "3.5.0"

[libraries]
kotlinx = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "kotlin" }

[plugins]
kotlinJvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
]]

local ROOT = [[plugins {
    alias(libs.plugins.kotlinJvm) apply false
}

repositories {
    mavenCentral()
}
]]

local function type_for(id)
  return require("kotlin-module.types." .. id)
end

local function build_script(plan)
  return plan.files[1].content
end

local function make_plan(params)
  params = params or {}
  local t = type_for(params.type_id or "jvm-lib")
  return gradle.resolve_plan({
    settings_content = params.settings_content or SETTINGS,
    root_build_content = params.root_build_content,
    catalog_content = params.catalog_content,
    sibling_build_content = params.sibling_build_content,
    settings_path = "/proj/settings.gradle.kts",
    root_build_path = "/proj/build.gradle.kts",
    catalog_path = "/proj/gradle/libs.versions.toml",
    module = params.module or "order-service",
    pkg = params.pkg or "com.acme",
    module_dir = "/proj/order-service",
    type_module = t,
    kotlin_version = params.kotlin_version or "2.4.10",
    spring_boot_version = params.spring_boot_version or "3.5.0",
    dep_mgmt_version = params.dep_mgmt_version or "1.1.7",
    jvm_target = params.jvm_target,
    buildsrc_convention = params.buildsrc_convention,
  })
end

describe("parse_includes", function()
  it("parses colon and colon-less forms", function()
    local set = gradle.parse_includes([[
include(":foo")
include("bar")
]])
    assert.is_true(set.foo)
    assert.is_true(set.bar)
  end)

  it("parses multi-arg and commented forms", function()
    local set = gradle.parse_includes([[include(":a", ":b") // comment
include("c") // trailing
]])
    assert.is_true(set.a)
    assert.is_true(set.b)
    assert.is_true(set.c)
  end)

  it("parses dynamic patterns", function()
    local set = gradle.parse_includes([[include(":lib:*")
]])
    assert.is_true(set["lib:*"])
  end)
end)

describe("merge_settings", function()
  it("appends include only when missing", function()
    local out, info = gradle.merge_settings(SETTINGS, "order-service")
    assert.is_true(info.inserted)
    assert.is_truthy(out:find('include(":order-service")', 1, true))
  end)

  it("does not duplicate an existing include", function()
    local content = SETTINGS .. '\ninclude(":order-service")\n'
    local out, info = gradle.merge_settings(content, "order-service")
    assert.is_false(info.inserted)
    assert.equal(content, out)
  end)

  it("handles colon-less equivalence", function()
    local content = SETTINGS .. '\ninclude("order-service")\n'
    local out, info = gradle.merge_settings(content, "order-service")
    assert.is_false(info.inserted)
    assert.equal(content, out)
  end)

  it("handles a missing trailing newline", function()
    local content = SETTINGS:sub(1, -2)
    local out, info = gradle.merge_settings(content, "order-service")
    assert.is_true(info.inserted)
    assert.is_truthy(out:find('\ninclude(":order-service")\n', 1, true))
  end)
end)

describe("merge_root_plugins", function()
  it("adds missing plugin declarations", function()
    local decls = {
      { id = "org.springframework.boot", alias = "springBoot", line = 'alias(libs.plugins.springBoot) apply false' },
    }
    local out, info = gradle.merge_root_plugins(ROOT, decls)
    assert.is_true(info.modified)
    assert.is_truthy(out:find("libs.plugins.springBoot", 1, true))
    assert.is_truthy(out:find("libs.plugins.kotlinJvm", 1, true))
  end)

  it("does not duplicate an existing plugin id", function()
    local decls = {
      { id = "org.jetbrains.kotlin.jvm", alias = "kotlinJvm", line = 'alias(libs.plugins.kotlinJvm) apply false' },
    }
    local out, info = gradle.merge_root_plugins(ROOT, decls)
    assert.is_false(info.modified)
    assert.equal(ROOT, out)
  end)

  it("reuses an existing declaration even under a different version", function()
    local content = [[plugins {
    id("org.jetbrains.kotlin.jvm") version "2.4.9" apply false
}
]]
    local decls = {
      { id = "org.jetbrains.kotlin.jvm", alias = nil, line = 'id("org.jetbrains.kotlin.jvm") version "2.4.10" apply false' },
    }
    local out, info = gradle.merge_root_plugins(content, decls)
    assert.is_false(info.modified)
    assert.equal(content, out)
    assert.same(decls, info.reused)
  end)

  it("creates a plugins block when none exists", function()
    local content = "repositories {\n    mavenCentral()\n}\n"
    local decls = {
      { id = "org.jetbrains.kotlin.jvm", alias = "kotlinJvm", line = 'alias(libs.plugins.kotlinJvm) apply false' },
    }
    local out, info = gradle.merge_root_plugins(content, decls)
    assert.is_true(info.block_created)
    assert.is_truthy(out:find("plugins {", 1, true))
    assert.is_truthy(out:find("libs.plugins.kotlinJvm", 1, true))
  end)
end)

describe("merge_catalog", function()
  it("adds missing entries without touching existing", function()
    local out, info = gradle.merge_catalog(CATALOG,
      { { key = "kotlin", value = "2.4.10" } },
      { { key = "springBoot", id = "org.springframework.boot", version_ref = "spring-boot" } },
      { { key = "kotlin-test", module = "org.jetbrains.kotlin:kotlin-test", version_ref = "kotlin" } }
    )
    assert.is_true(info.modified)
    assert.is_truthy(out:find("springBoot", 1, true))
    assert.is_truthy(out:find("kotlin-test", 1, true))
    assert.is_truthy(out:find("kotlinx", 1, true))
  end)

  it("does not duplicate an existing plugin id", function()
    local out, info = gradle.merge_catalog(CATALOG, {}, {
      { key = "kotlinJvm", id = "org.jetbrains.kotlin.jvm", version_ref = "kotlin" },
    }, {})
    assert.is_false(info.modified)
    assert.equal(CATALOG, out)
  end)

  it("creates sections that are missing", function()
    local out, info = gradle.merge_catalog("", { { key = "kotlin", value = "2.4.10" } }, {}, {})
    assert.is_true(info.modified)
    assert.is_truthy(out:find("[versions]", 1, true))
    assert.is_truthy(out:find('kotlin = "2.4.10"', 1, true))
  end)

  it("places entries after their newly-created section header", function()
    local out = gradle.merge_catalog(
      '[versions]\nkotlin = "2.4.10"\n',
      {},
      { { key = "kotlinJvm", id = "org.jetbrains.kotlin.jvm", version_ref = "kotlin" } },
      { { key = "kotlin-test", module = "org.jetbrains.kotlin:kotlin-test", version_ref = "kotlin" } }
    )
    local plugins_pos = out:find("[plugins]", 1, true)
    local plugin_entry = out:find("kotlinJvm", 1, true)
    local libraries_pos = out:find("[libraries]", 1, true)
    local library_entry = out:find("kotlin-test", 1, true)
    assert.is_truthy(plugins_pos and plugin_entry and libraries_pos and library_entry)
    assert.is_true(plugin_entry > plugins_pos, "plugin entry must be after [plugins] header")
    assert.is_true(library_entry > libraries_pos, "library entry must be after [libraries] header")
  end)
end)

describe("resolve_plan", function()
  it("uses catalog mode when catalog present", function()
    local plan = make_plan({ catalog_content = CATALOG, type_id = "jvm-lib" })
    assert.equal("catalog", plan.mode)
    assert.is_truthy(build_script(plan):find("alias(libs.plugins.kotlinJvm)", 1, true))
  end)

  it("uses inline mode when no catalog and includes version", function()
    local plan = make_plan({ type_id = "jvm-lib" })
    assert.equal("inline", plan.mode)
    assert.is_truthy(build_script(plan):find('id("org.jetbrains.kotlin.jvm") version "2.4.10"', 1, true))
  end)

  it("omits version when root already declares the plugin", function()
    local plan = make_plan({ root_build_content = ROOT, type_id = "jvm-lib" })
    assert.is_truthy(build_script(plan):find('id("org.jetbrains.kotlin.jvm")\n', 1, true))
  end)

  it("generates Spring Boot plugins and mainClass", function()
    local plan = make_plan({ catalog_content = CATALOG, type_id = "spring-boot" })
    local script = build_script(plan)
    assert.is_truthy(script:find("alias(libs.plugins.kotlinSpring)", 1, true))
    assert.is_truthy(script:find("alias(libs.plugins.springBoot)", 1, true))
    assert.is_truthy(script:find('mainClass.set("com.acme.ApplicationKt")', 1, true))
    assert.is_truthy(script:find("testImplementation(libs.kotlin.test)", 1, true))
  end)

  it("auto-creates root build script when missing", function()
    local plan = make_plan({ root_build_content = nil, type_id = "jvm-lib" })
    local found
    for _, w in ipairs(plan.writes) do
      if w.path == "/proj/build.gradle.kts" then
        found = w
      end
    end
    assert.is_not_nil(found)
    assert.is_true(found.created)
    assert.is_truthy(found.content:find("apply false", 1, true))
  end)

  it("produces four source dirs and sample files", function()
    local plan = make_plan({ type_id = "jvm-lib" })
    local dirs = table.concat(plan.dirs, "\n")
    assert.is_truthy(dirs:find("src/main/kotlin", 1, true))
    assert.is_truthy(dirs:find("src/main/resources", 1, true))
    assert.is_truthy(dirs:find("src/test/kotlin", 1, true))
    assert.is_truthy(dirs:find("src/test/resources", 1, true))
    assert.is_truthy(plan.files[2].path:find("Greeter.kt", 1, true))
    assert.is_truthy(plan.files[3].path:find("GreeterTest.kt", 1, true))
  end)
end)

describe("idempotency", function()
  it("double-run settings merge is a no-op", function()
    local once, info1 = gradle.merge_settings(SETTINGS, "order-service")
    assert.is_true(info1.inserted)
    local twice, info2 = gradle.merge_settings(once, "order-service")
    assert.is_false(info2.inserted)
    assert.equal(once, twice)
  end)

  it("double-run root merge is a no-op", function()
    local decls = {
      { id = "org.springframework.boot", alias = "springBoot", line = 'alias(libs.plugins.springBoot) apply false' },
    }
    local once, info1 = gradle.merge_root_plugins(ROOT, decls)
    assert.is_true(info1.modified)
    local twice, info2 = gradle.merge_root_plugins(once, decls)
    assert.is_false(info2.modified)
    assert.equal(once, twice)
  end)
end)

describe("CRLF and BOM preservation", function()
  it("preserves CRLF in settings merge", function()
    local content = "rootProject.name = \"demo\"\r\ninclude(\":app\")\r\n"
    local out, info = gradle.merge_settings(content, "order-service")
    assert.is_true(info.inserted)
    assert.is_truthy(out:find("\r\ninclude(\":order-service\")\r\n", 1, true))
    assert.is_nil(out:find("\ninclude(\":order-service\")\n", 1, true))
  end)

  it("preserves BOM and inserts after it", function()
    local bom = "\239\187\191"
    local content = bom .. "rootProject.name = \"demo\"\ninclude(\":app\")\n"
    local out, info = gradle.merge_settings(content, "order-service")
    assert.is_true(info.inserted)
    assert.is_truthy(out:sub(1, 3) == bom)
  end)
end)

describe("catalog alias resolution (F23/alias-reuse)", function()
  it("resolves the existing alias key for a plugin id", function()
    local catalog = [[[versions]
kotlin = "2.4.10"

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
]]
    assert.equal("kotlin-jvm", gradle.catalog_plugin_alias(catalog, "org.jetbrains.kotlin.jvm"))
    assert.is_nil(gradle.catalog_plugin_alias(catalog, "org.springframework.boot"))
  end)

  it("reuses the catalog alias in the module build script", function()
    local catalog = [[[versions]
kotlin = "2.4.10"

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
]]
    local plan = make_plan({ catalog_content = catalog, type_id = "jvm-lib" })
    assert.equal("kotlin-jvm", plan.info.aliases.kotlinJvm)
    assert.is_truthy(build_script(plan):find("alias(libs.plugins.kotlin.jvm)", 1, true))
    assert.is_nil(build_script(plan):find("alias(libs.plugins.kotlin-jvm)", 1, true))
  end)
end)

describe("inheritance probing (F22/F25/G3)", function()
  it("probes a sibling module build file for a pinned version", function()
    local sibling = 'plugins {\n    id("org.jetbrains.kotlin.jvm") version "2.5.0"\n}\n'
    local observed = gradle.probe_inherited_versions(nil, nil, sibling)
    assert.equal("2.5.0", observed["org.jetbrains.kotlin.jvm"])
  end)

  it("prefers sibling version in resolve_plan", function()
    local sibling = 'plugins {\n    id("org.jetbrains.kotlin.jvm") version "2.5.0"\n}\n'
    local plan = make_plan({ sibling_build_content = sibling, type_id = "jvm-lib" })
    assert.equal("2.5.0", plan.info.kotlin_version)
    assert.is_truthy(build_script(plan):find('id("org.jetbrains.kotlin.jvm") version "2.5.0"', 1, true))
  end)
end)

describe("toolchain (F24)", function()
  it("emits jvmToolchain when a resolver is detected", function()
    local settings = 'plugins {\n    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"\n}\nrootProject.name = "demo"\n'
    local plan = make_plan({ settings_content = settings, type_id = "spring-boot", catalog_content = CATALOG })
    assert.is_true(plan.info.toolchain_resolver)
    assert.equal("21", plan.info.jvm_target)
    assert.is_truthy(build_script(plan):find("jvmToolchain(21)", 1, true))
  end)

  it("omits toolchain when no resolver present", function()
    local plan = make_plan({ type_id = "spring-boot", catalog_content = CATALOG })
    assert.is_false(plan.info.toolchain_resolver)
    assert.is_nil(plan.info.jvm_target)
    assert.is_nil(build_script(plan):find("jvmToolchain", 1, true))
  end)
end)

describe("buildSrc convention + KGP-as-library (F23)", function()
  it("uses the buildSrc convention plugin in the module", function()
    local root = 'plugins {\n    id("buildsrc.convention.kotlin-jvm") apply false\n}\n'
    local plan = make_plan({ root_build_content = root, type_id = "jvm-lib" })
    assert.equal("buildsrc.convention.kotlin-jvm", plan.info.buildsrc_convention)
    assert.is_truthy(build_script(plan):find('id("buildsrc.convention.kotlin-jvm")', 1, true))
    assert.is_nil(build_script(plan):find("alias(libs.plugins.kotlinJvm)", 1, true))
  end)

  it("does not force kotlinJvm when KGP is a catalog library", function()
    local catalog = [[[versions]
kotlin = "2.4.10"

[libraries]
kotlinGradlePlugin = { module = "org.jetbrains.kotlin:kotlin-gradle-plugin", version.ref = "kotlin" }
kotlin-test = { module = "org.jetbrains.kotlin:kotlin-test", version.ref = "kotlin" }

[plugins]
kotlinJvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
]]
    local plan = make_plan({ catalog_content = catalog, type_id = "jvm-lib" })
    assert.is_true(plan.info.kgp_as_library)
    assert.is_truthy(build_script(plan):find("alias(libs.plugins.kotlinJvm)", 1, true))
  end)

  it("detects buildSrc convention id from settings", function()
    local settings = 'pluginManagement {\n    plugins {\n        id("buildsrc.convention.spring-boot") version "1.0"\n    }\n}\n'
    assert.equal("buildsrc.convention.spring-boot", gradle.detect_buildsrc_convention(nil, settings))
  end)
end)

describe("Kotlin/Gradle compatibility warning (F26)", function()
  it("warns when Kotlin 2.x needs a newer Gradle", function()
    local warn = gradle.check_kotlin_gradle_compat("2.4.10", "7.5")
    assert.is_not_nil(warn)
    assert.is_truthy(warn:find("requires Gradle 7.6.3+", 1, true))
  end)

  it("returns nil when compatible", function()
    assert.is_nil(gradle.check_kotlin_gradle_compat("2.4.10", "8.10"))
    assert.is_nil(gradle.check_kotlin_gradle_compat("2.4.10", nil))
    assert.is_nil(gradle.check_kotlin_gradle_compat(nil, "8.10"))
  end)
end)

describe("accessor/escape helpers", function()
  it("converts dashes to dots", function()
    assert.equal("kotlin.jvm", gradle.accessor("kotlin-jvm"))
    assert.equal("spring.dependency.management", gradle.accessor("spring-dependency-management"))
    assert.equal("kotlinJvm", gradle.accessor("kotlinJvm"))
  end)

  it("escapes Lua pattern metacharacters", function()
    assert.equal("spring%-boot", gradle.escape_pattern("spring-boot"))
    assert.equal("kotlin%.test", gradle.escape_pattern("kotlin.test"))
    assert.equal("kotlin%-test", gradle.escape_pattern("kotlin-test"))
  end)
end)

describe("catalog merge dedup (F-dash-key regression)", function()
  local DASH_CATALOG = [[[versions]
kotlin = "2.4.10"
spring-boot = "3.5.0"
spring-dependency-management = "1.1.7"

[plugins]
spring-dependency-management = { id = "io.spring.dependency-management", version.ref = "spring-dependency-management" }
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }

[libraries]
kotlin-test = { module = "org.jetbrains.kotlin:kotlin-test", version.ref = "kotlin" }
]]

  it("is a no-op when all dash-keyed entries already exist", function()
    local out, info = gradle.merge_catalog(DASH_CATALOG,
      {
        { key = "kotlin", value = "2.4.10" },
        { key = "spring-boot", value = "3.5.0" },
        { key = "spring-dependency-management", value = "1.1.7" },
      },
      {
        { key = "kotlin-jvm", id = "org.jetbrains.kotlin.jvm", version_ref = "kotlin" },
        { key = "spring-boot", id = "org.springframework.boot", version_ref = "spring-boot" },
        { key = "spring-dependency-management", id = "io.spring.dependency-management", version_ref = "spring-dependency-management" },
      },
      {
        { key = "kotlin-test", module = "org.jetbrains.kotlin:kotlin-test", version_ref = "kotlin" },
      }
    )
    assert.is_false(info.modified)
    assert.equal(DASH_CATALOG, out)
  end)

  it("adds a genuinely missing dash-keyed entry exactly once", function()
    local out, info = gradle.merge_catalog(DASH_CATALOG, {},
      { { key = "kotlin-spring", id = "org.jetbrains.kotlin.plugin.spring", version_ref = "kotlin" } },
      {})
    assert.is_true(info.modified)
    local count = select(2, out:gsub('kotlin%-spring = %{ id = "org%.jetbrains%.kotlin%.plugin%.spring"', ""))
    assert.equal(1, count)
  end)

  it("skips a plugin when its key already exists under a different id", function()
    local catalog = [[[plugins]
spring-boot = { id = "com.example.other" }
]]
    local out, info = gradle.merge_catalog(catalog, {},
      { { key = "spring-boot", id = "org.springframework.boot", version_ref = "spring-boot" } },
      {})
    assert.is_false(info.modified)
    assert.equal(catalog, out)
  end)

  it("skips a library when its key already exists under a different module", function()
    local catalog = [[[libraries]
kotlin-test = { module = "org.example:other" }
]]
    local out, info = gradle.merge_catalog(catalog, {}, {},
      { { key = "kotlin-test", module = "org.jetbrains.kotlin:kotlin-test", version_ref = "kotlin" } })
    assert.is_false(info.modified)
    assert.equal(catalog, out)
  end)

  it("does not insert a version key that collides as a dotted prefix", function()
    local catalog = [[[versions]
spring-dependency-management = "1.1.7"
]]
    local out, info = gradle.merge_catalog(catalog,
      { { key = "spring-dependency", value = "1.0" } }, {}, {})
    assert.is_false(info.modified)
    assert.equal(catalog, out)
  end)
end)

describe("dashed accessor reuse in root (G-remat regression)", function()
  local DASH_CATALOG = [[[versions]
kotlin = "2.3.21"
spring-boot = "4.1.0"
spring-dependency-management = "1.1.7"

[plugins]
spring-dependency-management = { id = "io.spring.dependency-management", version.ref = "spring-dependency-management" }
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
kotlin-spring = { id = "org.jetbrains.kotlin.plugin.spring", version.ref = "kotlin" }
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }

[libraries]
kotlin-test = { module = "org.jetbrains.kotlin:kotlin-test", version.ref = "kotlin" }
]]

  local REMAT_ROOT = [[plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.spring)
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.spring.dependency.management)
}
]]

  it("reuses dotted root declarations and renders dotted module aliases", function()
    local plan = make_plan({
      settings_content = 'rootProject.name = "remat"\ninclude(":core")\n',
      root_build_content = REMAT_ROOT,
      catalog_content = DASH_CATALOG,
      type_id = "spring-boot",
    })
    assert.is_false(plan.info.root.modified)
    assert.is_false(plan.info.catalog.modified)
    local script = build_script(plan)
    assert.is_truthy(script:find("alias(libs.plugins.kotlin.jvm)", 1, true))
    assert.is_truthy(script:find("alias(libs.plugins.kotlin.spring)", 1, true))
    assert.is_truthy(script:find("alias(libs.plugins.spring.boot)", 1, true))
    assert.is_truthy(script:find("alias(libs.plugins.spring.dependency.management)", 1, true))
    assert.is_nil(script:find("kotlin%-jvm", 1, true))
  end)

  it("does not append broken dashed aliases to the root", function()
    local plan = make_plan({
      settings_content = 'rootProject.name = "remat"\ninclude(":core")\n',
      root_build_content = REMAT_ROOT,
      catalog_content = DASH_CATALOG,
      type_id = "spring-boot",
    })
    local root_out
    for _, w in ipairs(plan.writes) do
      if w.path == "/proj/build.gradle.kts" then
        root_out = w.content
      end
    end
    assert.equal(REMAT_ROOT, root_out)
    assert.is_nil(root_out:find("libs%.plugins%.kotlin%s%-%s*jvm", 1))
  end)
end)