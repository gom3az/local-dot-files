local M = {}

local project = require("kotlin-module.project")
local wizard = require("kotlin-module.wizard")
local validate = require("kotlin-module.validate")
local gradle = require("kotlin-module.gradle")

local opts = {
  kotlin_version = "2.4.10",
  spring_boot_version = "3.5.0",
  dependency_management_version = "1.1.7",
  jvm_target = nil,
}

M.setup = function(user_opts)
  opts = vim.tbl_deep_extend("force", opts, user_opts or {})
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function path_exists(path)
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

local function atomic_write(path, content)
  local dir = vim.fs.dirname(path)
  local tmp = dir .. "/." .. vim.fs.basename(path) .. ".kotlin-module.tmp"
  local f = io.open(tmp, "wb")
  if not f then
    return false, "cannot open " .. tmp .. " for writing"
  end
  f:write(content)
  f:close()
  local ok, err = os.rename(tmp, path)
  if not ok then
    os.remove(tmp)
    return false, err
  end
  return true, nil
end

local function read_gradle_version(root)
  local props = root .. "/gradle/wrapper/gradle-wrapper.properties"
  local content = read_file(props)
  if not content then
    return nil
  end
  return content:match("gradle%-([%d%.]+)%-")
end

local function find_sibling_build(root, include_names)
  for _, name in ipairs(include_names or {}) do
    local p = root .. "/" .. name .. "/build.gradle.kts"
    if path_exists(p) then
      return p
    end
  end
  return nil
end

local function find_sibling_package(root, include_names)
  for _, name in ipairs(include_names or {}) do
    local dir = root .. "/" .. name .. "/src/main/kotlin"
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/**/*.kt", false, true)
      if #files > 0 then
        local content = read_file(files[1])
        if content then
          local pkg = content:match("^%s*package%s+([%w%.]+)")
          if pkg then
            return pkg
          end
        end
      end
    end
  end
  return nil
end

local create_module

M.new_module = function()
  local cwd = vim.fn.getcwd()
  local bufdir = vim.fn.expand("%:p:h")
  local start_dir = bufdir ~= "" and bufdir or cwd

  local detected = project.detect(start_dir)
  if not detected.root or not detected.settings_file then
    vim.notify(
      "No Gradle project root found (searched for settings.gradle, settings.gradle.kts, pom.xml, build.gradle, build.gradle.kts, workspace.json from "
        .. start_dir .. ")",
      vim.log.levels.ERROR
    )
    return
  end

  local settings_path = detected.root .. "/" .. detected.settings_file
  local settings_content = read_file(settings_path)
  local include_names = {}
  for name in pairs(gradle.parse_includes(settings_content)) do
    table.insert(include_names, name)
  end

  local root_build_path = detected.root .. "/build.gradle.kts"
  local catalog_path = detected.root .. "/gradle/libs.versions.toml"

  local root_exists = path_exists(root_build_path)
  if not root_exists then
    local groovy_root = detected.root .. "/build.gradle"
    if path_exists(groovy_root) then
      root_build_path = groovy_root
      root_exists = true
    end
  end

  local root_content = root_exists and read_file(root_build_path) or nil
  local catalog_content = read_file(catalog_path)

  local sibling_build = find_sibling_build(detected.root, include_names)
  local sibling_content = sibling_build and read_file(sibling_build) or nil
  local observed = gradle.probe_inherited_versions(root_content, settings_content, sibling_content)

  local default_pkg = find_sibling_package(detected.root, include_names)

  wizard.run({
    inline = catalog_content == nil,
    defaults = {
      pkg = default_pkg,
      kotlin = observed["org.jetbrains.kotlin.jvm"] or opts.kotlin_version,
      spring_boot = observed["org.springframework.boot"] or opts.spring_boot_version,
      dsl = detected.settings_file:match("%.gradle$") and "groovy" or "kotlin",
    },
  }, function(result, cancel_reason)
    if not result then
      if cancel_reason == "groovy-unsupported" then
        vim.notify("Groovy `build.gradle` generation is not supported in MVP", vim.log.levels.WARN)
      end
      return
    end
    create_module(result, detected, settings_content, settings_path, root_build_path, catalog_path, root_content, catalog_content, sibling_content, include_names, observed)
  end)
end

create_module = function(result, detected, settings_content, settings_path, root_build_path, catalog_path, root_content, catalog_content, sibling_content, include_names, observed)
  local type_module = require("kotlin-module.types." .. result.type_id)
  local module_dir = detected.root .. "/" .. result.module

  if path_exists(module_dir) then
    vim.notify("Module `" .. result.module .. "` already exists as a directory or file at " .. module_dir, vim.log.levels.ERROR)
    return
  end

  local existing_dirs = {}
  for _, entry in ipairs(vim.fn.readdir(detected.root)) do
    if vim.fn.isdirectory(detected.root .. "/" .. entry) == 1 and entry ~= "gradle" and entry ~= ".gradle" then
      table.insert(existing_dirs, entry)
    end
  end

  local colliding = validate.module_collides(result.module, existing_dirs, include_names)
  if colliding then
    vim.notify(colliding, vim.log.levels.ERROR)
    return
  end

  local buildsrc_convention = gradle.detect_buildsrc_convention(root_content, settings_content)

  local plan = gradle.resolve_plan({
    settings_content = settings_content,
    root_build_content = root_content,
    catalog_content = catalog_content,
    sibling_build_content = sibling_content,
    settings_path = settings_path,
    root_build_path = root_build_path,
    catalog_path = catalog_path,
    module = result.module,
    pkg = result.pkg,
    module_dir = module_dir,
    type_module = type_module,
    kotlin_version = result.kotlin_version or observed["org.jetbrains.kotlin.jvm"] or opts.kotlin_version,
    spring_boot_version = result.spring_boot_version or observed["org.springframework.boot"] or opts.spring_boot_version,
    dep_mgmt_version = opts.dependency_management_version,
    jvm_target = opts.jvm_target,
    buildsrc_convention = buildsrc_convention,
  })

  local gradle_version = read_gradle_version(detected.root)
  local compat_warning = gradle.check_kotlin_gradle_compat(plan.info.kotlin_version, gradle_version)
  if compat_warning then
    vim.notify(compat_warning, vim.log.levels.WARN)
  end

  local summary_lines = {
    "kotlin-module: create module `" .. result.module .. "`?",
    "  type: " .. type_module.label,
    "  package: " .. result.pkg,
    "  dsl: " .. result.dsl,
    "  mode: " .. plan.mode .. (plan.info.buildsrc_convention and " (buildSrc convention: " .. plan.info.buildsrc_convention .. ")" or ""),
    "  include: :" .. result.module,
    "  files to create:",
  }
  for _, file in ipairs(plan.files) do
    table.insert(summary_lines, "    + " .. file.path)
  end
  table.insert(summary_lines, "  gradle files to modify:")
  if plan.info.settings.inserted then
    table.insert(summary_lines, "    ~ " .. settings_path .. " (" .. plan.info.settings.line .. ")")
  end
  if plan.info.root.modified then
    table.insert(summary_lines, "    ~ " .. root_build_path .. " (+ " .. #plan.info.root.inserted .. " plugin declaration(s))")
  end
  if plan.info.catalog.modified then
    table.insert(summary_lines, "    ~ " .. catalog_path)
  end

  wizard.confirm({}, table.concat(summary_lines, "\n"), function(confirm)
    if confirm ~= "create" then
      vim.notify("kotlin-module: cancelled — no changes made", vim.log.levels.INFO)
      return
    end

    local created = {}
    local function cleanup()
      for i = #created, 1, -1 do
        local p = created[i]
        if vim.fn.isdirectory(p) == 1 then
          vim.fn.delete(p, "rf")
        else
          os.remove(p)
        end
      end
    end

    local ok, write_err = pcall(function()
      for _, dir in ipairs(plan.dirs) do
        vim.fn.mkdir(dir, "p")
        table.insert(created, dir)
      end
      for _, file in ipairs(plan.files) do
        local dir = vim.fs.dirname(file.path)
        vim.fn.mkdir(dir, "p")
        local f = io.open(file.path, "wb")
        if not f then
          error("cannot write " .. file.path)
        end
        f:write(file.content)
        f:close()
        table.insert(created, file.path)
      end
      for _, write in ipairs(plan.writes) do
        local wok, werr = atomic_write(write.path, write.content)
        if not wok then
          error(werr or ("cannot write " .. write.path))
        end
      end
    end)

    if not ok then
      cleanup()
      vim.notify("Rollback complete — error during generation: " .. tostring(write_err), vim.log.levels.ERROR)
      return
    end

    local lines = {
      "kotlin-module: created module `" .. result.module .. "`",
      "  type: " .. type_module.label,
      "  package: " .. result.pkg,
      "  mode: " .. plan.mode .. (plan.info.buildsrc_convention and " (buildSrc convention: " .. plan.info.buildsrc_convention .. ")" or ""),
      "  include: :" .. result.module,
      "  files:",
    }
    for _, file in ipairs(plan.files) do
      table.insert(lines, "    - " .. file.path)
    end
    table.insert(lines, "  gradle files modified:")
    if plan.info.settings.inserted then
      table.insert(lines, "    - " .. settings_path .. " (+ " .. plan.info.settings.line .. ")")
    end
    if plan.info.root.modified then
      table.insert(lines, "    - " .. root_build_path .. " (+ " .. #plan.info.root.inserted .. " plugin declaration(s))")
    end
    if plan.info.catalog.modified then
      table.insert(lines, "    - " .. catalog_path)
    end
    table.insert(lines, "  note: no Gradle sync/task was run (MVP behavior)")

    local summary = table.concat(lines, "\n")
    vim.notify(summary, vim.log.levels.INFO)
    vim.cmd("messages")
  end)
end

return M