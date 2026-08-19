local M = {}

M.id = "spring-boot"
M.label = "Spring Boot"

M.plugins = {
  { id = "org.jetbrains.kotlin.jvm", alias = "kotlinJvm", version_ref = "kotlin" },
  { id = "org.jetbrains.kotlin.plugin.spring", alias = "kotlinSpring", version_ref = "kotlin" },
  { id = "org.springframework.boot", alias = "springBoot", version_ref = "spring-boot" },
  { id = "io.spring.dependency-management", alias = "springDependencyManagement", version_ref = "spring-dependency-management" },
}

M.source_dirs = {
  "src/main/kotlin",
  "src/main/resources",
  "src/test/kotlin",
  "src/test/resources",
}

local function toolchain_block(opts)
  if not opts.jvm_target then
    return nil
  end
  return table.concat({
    "kotlin {",
    "    jvmToolchain(" .. opts.jvm_target .. ")",
    "}",
  }, "\n")
end

M.render_build_script = function(opts)
  local kotlin_test = opts.kotlin_test or 'kotlin("test")'
  local function a(name)
    return (opts.aliases and opts.aliases[name]) or name
  end
  local plugin_lines
  if opts.buildsrc_convention then
    plugin_lines = { '    id("' .. opts.buildsrc_convention .. '")' }
  elseif opts.mode == "catalog" then
    plugin_lines = {
      "    alias(libs.plugins." .. a("kotlinJvm") .. ")",
      "    alias(libs.plugins." .. a("kotlinSpring") .. ")",
      "    alias(libs.plugins." .. a("springBoot") .. ")",
      "    alias(libs.plugins." .. a("springDependencyManagement") .. ")",
      "    application",
    }
  else
    local kotlin_ver = ""
    if not opts.omit_kotlin_version then
      kotlin_ver = ' version "' .. opts.kotlin_version .. '"'
    end
    local versions = {
      { id = "org.jetbrains.kotlin.jvm", version = kotlin_ver },
      { id = "org.jetbrains.kotlin.plugin.spring", version = kotlin_ver },
      { id = "org.springframework.boot", version = ' version "' .. opts.spring_boot_version .. '"' },
      { id = "io.spring.dependency-management", version = ' version "' .. (opts.dependency_management_version or "1.1.7") .. '"' },
    }
    plugin_lines = {}
    for _, p in ipairs(versions) do
      table.insert(plugin_lines, '    id("' .. p.id .. '")' .. p.version)
    end
    table.insert(plugin_lines, "    application")
  end

  local chunks = {
    "plugins {",
    table.concat(plugin_lines, "\n"),
    "}",
  }
  if opts.repositories then
    table.insert(chunks, "")
    table.insert(chunks, "repositories {")
    table.insert(chunks, "    mavenCentral()")
    table.insert(chunks, "}")
  end

  table.insert(chunks, "")
  table.insert(chunks, "application {")
  table.insert(chunks, "    mainClass.set(\"" .. opts.pkg .. ".ApplicationKt\")")
  table.insert(chunks, "}")

  local tc = toolchain_block(opts)
  if tc then
    table.insert(chunks, "")
    table.insert(chunks, tc)
  end

  table.insert(chunks, "")
  table.insert(chunks, "dependencies {")
  table.insert(chunks, "    testImplementation(" .. kotlin_test .. ")")
  table.insert(chunks, "}")

  return table.concat(chunks, "\n") .. "\n"
end

M.render_files = function(opts)
  local pkg = opts.pkg
  local pkg_path = pkg:gsub("%.", "/")
  local application = table.concat({
    "package " .. pkg,
    "",
    "import org.springframework.boot.autoconfigure.SpringBootApplication",
    "import org.springframework.boot.runApplication",
    "",
    "@SpringBootApplication",
    "class Application",
    "",
    "fun main(args: Array<String>) {",
    "    runApplication<Application>(*args)",
    "}",
    "",
  }, "\n")
  local test = table.concat({
    "package " .. pkg,
    "",
    "import kotlin.test.Test",
    "",
    "class ApplicationTest {",
    "    @Test",
    "    fun contextLoads() {",
    "    }",
    "}",
    "",
  }, "\n")
  return {
    { path = "src/main/kotlin/" .. pkg_path .. "/Application.kt", content = application },
    { path = "src/test/kotlin/" .. pkg_path .. "/ApplicationTest.kt", content = test },
  }
end

return M