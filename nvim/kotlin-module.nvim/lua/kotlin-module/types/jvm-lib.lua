local M = {}

M.id = "jvm-lib"
M.label = "Kotlin JVM Library"

M.plugins = {
  { id = "org.jetbrains.kotlin.jvm", alias = "kotlinJvm", version_ref = "kotlin" },
}

M.source_dirs = {
  "src/main/kotlin",
  "src/main/resources",
  "src/test/kotlin",
  "src/test/resources",
}

M.render_build_script = function(opts)
  local kotlin_test = opts.kotlin_test or 'kotlin("test")'
  local plugin_line
  if opts.buildsrc_convention then
    plugin_line = '    id("' .. opts.buildsrc_convention .. '")'
  elseif opts.mode == "catalog" then
    local alias = (opts.aliases and opts.aliases.kotlinJvm) or "kotlinJvm"
    plugin_line = "    alias(libs.plugins." .. alias .. ")"
  else
    local ver = ""
    if not opts.omit_kotlin_version then
      ver = ' version "' .. opts.kotlin_version .. '"'
    end
    plugin_line = '    id("org.jetbrains.kotlin.jvm")' .. ver
  end
  local chunks = {
    "plugins {",
    plugin_line,
    "}",
  }
  if opts.repositories then
    table.insert(chunks, "")
    table.insert(chunks, "repositories {")
    table.insert(chunks, "    mavenCentral()")
    table.insert(chunks, "}")
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
  local greeter = table.concat({
    "package " .. pkg,
    "",
    "class Greeter(private val prefix: String) {",
    "    fun greet(name: String): String = \"$prefix, $name!\"",
    "}",
    "",
  }, "\n")
  local test = table.concat({
    "package " .. pkg,
    "",
    "import kotlin.test.Test",
    "import kotlin.test.assertEquals",
    "",
    "class GreeterTest {",
    "    @Test",
    "    fun greets() {",
    "        assertEquals(\"Hello, World!\", Greeter(\"Hello\").greet(\"World\"))",
    "    }",
    "}",
    "",
  }, "\n")
  return {
    { path = "src/main/kotlin/" .. pkg_path .. "/Greeter.kt", content = greeter },
    { path = "src/test/kotlin/" .. pkg_path .. "/GreeterTest.kt", content = test },
  }
end

return M