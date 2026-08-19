local M = {}

local BOM = "\239\187\191"

M.escape_pattern = function(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

M.accessor = function(key)
  return key:gsub("-", ".")
end

local function detect_eol(content)
  if content:find("\r\n", 1, true) then
    return "\r\n"
  end
  if content:find("\n", 1, true) then
    return "\n"
  end
  return "\n"
end

local function has_bom(content)
  return content:sub(1, #BOM) == BOM
end

M.normalize_include_name = function(raw)
  return (raw:gsub("^:+", ""))
end

M.parse_includes = function(content)
  local set = {}
  local pos = 1
  while true do
    local s = content:find("include", pos, true)
    if not s then
      break
    end
    local open = content:find("%(", s)
    if not open then
      pos = s + 1
    else
      local depth = 1
      local i = open + 1
      local close
      while i <= #content do
        local ch = content:sub(i, i)
        if ch == "(" then
          depth = depth + 1
        elseif ch == ")" then
          depth = depth - 1
          if depth == 0 then
            close = i
            break
          end
        end
        i = i + 1
      end
      if not close then
        break
      end
      local args = content:sub(open + 1, close - 1)
      for arg in args:gmatch('"([^"]*)"') do
        set[M.normalize_include_name(arg)] = true
      end
      for arg in args:gmatch("'([^']*)'") do
        set[M.normalize_include_name(arg)] = true
      end
      pos = close + 1
    end
  end
  return set
end

M.merge_settings = function(content, module_name)
  local set = M.parse_includes(content)
  if set[module_name] then
    return content, { inserted = false, reason = "already-included" }
  end
  local eol = detect_eol(content)
  local line = 'include(":' .. module_name .. '")'
  local trailing = content:match("\n$") ~= nil
  local out
  if trailing then
    out = content .. line .. eol
  else
    out = content .. eol .. line .. eol
  end
  return out, { inserted = true, line = line }
end

local function find_plugins_block_lines(lines)
  for i, line in ipairs(lines) do
    if line:match("^%s*plugins%s*{") then
      local depth = 0
      local opened = false
      for j = i, #lines do
        local _, close_count = lines[j]:gsub("}", "")
        local _, open_count = lines[j]:gsub("{", "")
        if not opened then
          opened = true
          depth = depth + open_count
        else
          depth = depth + open_count - close_count
        end
        if depth <= 0 then
          return i, j
        end
      end
    end
  end
  return nil, nil
end

local function block_declares(content, start, finish, plugin)
  local block = content:sub(start, finish)
  if block:find(plugin.id, 1, true) then
    return true
  end
  if plugin.alias then
    local raw = M.escape_pattern(plugin.alias)
    if block:find("libs%.plugins%." .. raw, 1) then
      return true
    end
    local dotted = M.accessor(plugin.alias)
    local accessor = M.escape_pattern(dotted)
    if accessor ~= raw and block:find("libs%.plugins%." .. accessor, 1) then
      return true
    end
  end
  return false
end

M.merge_root_plugins = function(content, decls)
  local eol = detect_eol(content)
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local block_start, block_end = find_plugins_block_lines(lines)
  local missing = {}
  local reused = {}

  local function block_text()
    return table.concat(lines, "\n", block_start, block_end)
  end

  for _, decl in ipairs(decls) do
    if block_start and block_declares(block_text(), 1, #block_text(), decl) then
      table.insert(reused, decl)
    else
      table.insert(missing, decl)
    end
  end

  if #missing == 0 then
    return content, { modified = false, inserted = {}, reused = reused }
  end

  if block_start then
    local out_lines = {}
    for idx, line in ipairs(lines) do
      if idx == block_end then
        for _, decl in ipairs(missing) do
          table.insert(out_lines, "    " .. decl.line)
        end
      end
      table.insert(out_lines, line)
    end
    local inserted = {}
    for _, decl in ipairs(missing) do
      table.insert(inserted, decl.line)
    end
    return table.concat(out_lines, eol), { modified = true, inserted = inserted, reused = reused }
  end

  local inserted = {}
  local block_lines = { "plugins {" }
  for _, decl in ipairs(missing) do
    table.insert(block_lines, "    " .. decl.line)
    table.insert(inserted, decl.line)
  end
  table.insert(block_lines, "}")
  local new_block = table.concat(block_lines, eol)
  local prefix = has_bom(content) and BOM or ""
  local body = content:sub(#prefix + 1)
  local final_content
  if body == "" then
    final_content = prefix .. new_block .. eol
  else
    final_content = prefix .. new_block .. eol .. body .. (body:match("\n$") and "" or eol)
  end
  return final_content, { modified = true, inserted = inserted, reused = reused, block_created = true }
end

local function section_bounds(lines, header)
  local start_idx, end_idx
  for idx, line in ipairs(lines) do
    if line:match("^%s*%[" .. header .. "%]%s*$") then
      start_idx = idx
    elseif start_idx and line:match("^%s*%[") then
      end_idx = idx - 1
      break
    end
  end
  if start_idx and not end_idx then
    end_idx = #lines
  end
  return start_idx, end_idx
end

local function section_has(lines, header, pattern)
  local s, e = section_bounds(lines, header)
  if not s then
    return false
  end
  for idx = s + 1, e do
    if lines[idx]:match(pattern) then
      return true
    end
  end
  return false
end

local function section_keys(lines, header)
  local s, e = section_bounds(lines, header)
  local keys = {}
  if not s then
    return keys
  end
  for idx = s + 1, e do
    local key = lines[idx]:match("^%s*([%w%.%-%_]+)%s*=")
    if key then
      table.insert(keys, key)
    end
  end
  return keys
end

local function accessor_path(key)
  return key:gsub("[%-%.%_]", ".")
end

local function section_prefix_collides(existing_keys, new_key)
  local np = accessor_path(new_key)
  for _, e in ipairs(existing_keys) do
    local ep = accessor_path(e)
    if ep ~= np
      and (np:find("^" .. M.escape_pattern(ep) .. "%.") or ep:find("^" .. M.escape_pattern(np) .. "%.")) then
      return e
    end
  end
  return nil
end

M.merge_catalog = function(content, version_adds, plugin_adds, library_adds)
  local eol = detect_eol(content)
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local function ensure_section(header)
    local s = section_bounds(lines, header)
    if s then
      return s
    end
    table.insert(lines, "")
    table.insert(lines, "[" .. header .. "]")
    return #lines, #lines
  end

  local inserted = {}

  local function insert_entry(section, key, line, meta)
    if section_has(lines, section, "^%s*" .. M.escape_pattern(key) .. "%s*=") then
      return false
    end
    local existing = section_keys(lines, section)
    table.insert(existing, key)
    if section_prefix_collides(existing, key) then
      return false
    end
    local s = ensure_section(section)
    table.insert(lines, s + 1, line)
    table.insert(inserted, meta)
    return true
  end

  for _, v in ipairs(version_adds) do
    insert_entry("versions", v.key, v.key .. ' = "' .. v.value .. '"', { section = "versions", key = v.key })
  end

  for _, p in ipairs(plugin_adds) do
    if not section_has(lines, "plugins", 'id%s*=%s*"' .. M.escape_pattern(p.id) .. '"') then
      insert_entry("plugins", p.key,
        p.key .. ' = { id = "' .. p.id .. '", version.ref = "' .. p.version_ref .. '" }',
        { section = "plugins", key = p.key })
    end
  end

  for _, l in ipairs(library_adds) do
    if not section_has(lines, "libraries", 'module%s*=%s*"' .. M.escape_pattern(l.module) .. '"') then
      insert_entry("libraries", l.key,
        l.key .. ' = { module = "' .. l.module .. '", version.ref = "' .. l.version_ref .. '" }',
        { section = "libraries", key = l.key })
    end
  end

  if #inserted == 0 then
    return content, { modified = false, inserted = inserted }
  end

  local out = table.concat(lines, eol)
  if not out:match("\n$") then
    out = out .. eol
  end
  return out, { modified = true, inserted = inserted }
end

M.probe_inherited_versions = function(root_build_content, settings_content, sibling_content)
  local observed = {}
  local function probe(content, target)
    if not content then
      return nil
    end
    local m = content:match('id%s*%("' .. target .. '"%s*%)%s*version%s*"([^"]+)"')
    return m
  end
  for _, id in ipairs({ "org.jetbrains.kotlin.jvm", "org.jetbrains.kotlin.plugin.spring", "org.springframework.boot", "io.spring.dependency-management" }) do
    local v = probe(root_build_content, id) or probe(settings_content, id) or probe(sibling_content, id)
    if v then
      observed[id] = v
    end
  end
  return observed
end

M.detect_toolchain_resolver = function(settings_content)
  if not settings_content then
    return false
  end
  return settings_content:find("foojay", 1, true) ~= nil
    or settings_content:find("toolchainManagement", 1, true) ~= nil
end

M.detect_buildsrc_convention = function(root_build_content, settings_content)
  local hay = (root_build_content or "") .. "\n" .. (settings_content or "")
  return hay:match('id%s*%(%s*"(buildsrc%.convention%.[^"]+)"')
end

M.detect_kgp_as_library = function(catalog_content)
  if not catalog_content then
    return false
  end
  return catalog_content:find('module%s*=%s*"org%.jetbrains%.kotlin:kotlin%-gradle%-plugin"', 1) ~= nil
end

M.catalog_plugin_alias = function(catalog_content, plugin_id)
  if not catalog_content then
    return nil
  end
  local in_plugins = false
  for line in catalog_content:gmatch("[^\r\n]+") do
    if line:match("^%s*%[plugins%]%s*$") then
      in_plugins = true
    elseif line:match("^%s*%[") then
      in_plugins = false
    elseif in_plugins then
      local key = line:match("^%s*([%w%-]+)%s*=")
      local id = line:match('id%s*=%s*"([^"]+)"')
      if key and id == plugin_id then
        return key
      end
    end
  end
  return nil
end

local function version_tuple(v)
  if not v then
    return nil
  end
  local major, minor, patch = v:match("^(%d+)%.(%d+)%.?(%d*)")
  if not major then
    return nil
  end
  return tonumber(major), tonumber(minor or 0), tonumber(patch ~= "" and patch or 0)
end

M.check_kotlin_gradle_compat = function(kotlin_version, gradle_version)
  if not kotlin_version or not gradle_version then
    return nil
  end
  local kmaj, kmin, kpatch = version_tuple(kotlin_version)
  local gmaj, gmin, gpatch = version_tuple(gradle_version)
  if not kmaj or not gmaj then
    return nil
  end
  if kmaj == 2 then
    if gmaj < 7 or (gmaj == 7 and gmin < 6) or (gmaj == 7 and gmin == 6 and gpatch < 3) then
      return string.format(
        "Kotlin plugin %s requires Gradle 7.6.3+; the project uses Gradle %s",
        kotlin_version, gradle_version
      )
    end
    if gmaj >= 9 and (kmin < 2 or (kmin == 2 and kpatch < 20)) then
      return string.format(
        "Gradle %s requires the Kotlin Gradle Plugin 2.2.20+; the project uses Kotlin %s",
        gradle_version, kotlin_version
      )
    end
  end
  return nil
end

local function declared_in_root(content, decl)
  if not content then
    return false
  end
  return block_declares(content, 1, #content, decl)
end

M.resolve_plan = function(params)
  local settings_content = params.settings_content
  local root_build_content = params.root_build_content
  local catalog_content = params.catalog_content
  local catalog_present = catalog_content ~= nil
  local root_build_present = root_build_content ~= nil
  local mode = catalog_present and "catalog" or "inline"

  local observed = M.probe_inherited_versions(root_build_content, params.settings_content, params.sibling_build_content)
  local kotlin_version = observed["org.jetbrains.kotlin.jvm"] or params.kotlin_version
  local spring_boot_version = observed["org.springframework.boot"] or params.spring_boot_version
  local spring_plugin_version = observed["org.jetbrains.kotlin.plugin.spring"] or kotlin_version
  local dep_mgmt_version = observed["io.spring.dependency-management"] or params.dep_mgmt_version or "1.1.7"

  local type_module = params.type_module
  local plugin_requirements = type_module.plugins

  local buildsrc_convention = params.buildsrc_convention or M.detect_buildsrc_convention(root_build_content, params.settings_content)
  local kgp_as_library = M.detect_kgp_as_library(catalog_content) or params.kgp_as_library == true
  local use_buildsrc = buildsrc_convention ~= nil
  local use_kgp_library = not use_buildsrc and kgp_as_library

  local aliases = {}
  for _, pr in ipairs(plugin_requirements) do
    aliases[pr.alias] = M.catalog_plugin_alias(catalog_content, pr.id) or pr.alias
  end

  local decls = {}
  for _, pr in ipairs(plugin_requirements) do
    local version = pr.id == "org.jetbrains.kotlin.jvm" and kotlin_version
      or pr.id == "org.jetbrains.kotlin.plugin.spring" and spring_plugin_version
      or pr.id == "org.springframework.boot" and spring_boot_version
      or pr.id == "io.spring.dependency-management" and dep_mgmt_version
    local decl = {
      id = pr.id,
      alias = aliases[pr.alias],
      version = version,
      version_ref = pr.version_ref,
    }
    if mode == "catalog" then
      decl.line = "alias(libs.plugins." .. M.accessor(decl.alias) .. ") apply false"
    else
      decl.line = 'id("' .. pr.id .. '") version "' .. version .. '" apply false'
    end
    table.insert(decls, decl)
  end

  local version_adds = {}
  local plugin_adds = {}
  local library_adds = {}
  if mode == "catalog" then
    for _, d in ipairs(decls) do
      if not (use_buildsrc and (d.id == "org.jetbrains.kotlin.jvm" or d.id == "org.jetbrains.kotlin.plugin.spring")) then
        table.insert(plugin_adds, { key = d.alias, id = d.id, version_ref = d.version_ref })
      end
    end
    local existing_versions = {}
    if catalog_content then
      for line in catalog_content:gmatch("[^\r\n]+") do
        local k, v = line:match("^%s*([%w%.%-]+)%s*=%s*\"([^\"]+)\"")
        if k then
          existing_versions[k] = v
        end
      end
    end
    if not existing_versions.kotlin then
      table.insert(version_adds, { key = "kotlin", value = kotlin_version })
    end
    if params.type_module.id == "spring-boot" and not existing_versions["spring-boot"] then
      table.insert(version_adds, { key = "spring-boot", value = spring_boot_version })
    end
    if params.type_module.id == "spring-boot" and not existing_versions["spring-dependency-management"] then
      table.insert(version_adds, { key = "spring-dependency-management", value = dep_mgmt_version })
    end
    if not use_kgp_library then
      table.insert(library_adds, { key = "kotlin-test", module = "org.jetbrains.kotlin:kotlin-test", version_ref = "kotlin" })
    end
  end

  local settings_out, settings_info = M.merge_settings(settings_content, params.module)
  local root_decls = {}
  for _, d in ipairs(decls) do
    if use_buildsrc then
      if d.id ~= "org.jetbrains.kotlin.jvm" and d.id ~= "org.jetbrains.kotlin.plugin.spring" then
        if not (root_build_present and declared_in_root(root_build_content, d)) then
          table.insert(root_decls, d)
        end
      end
    elseif use_kgp_library then
      if d.id ~= "org.jetbrains.kotlin.jvm" and d.id ~= "org.jetbrains.kotlin.plugin.spring" then
        if not (root_build_present and declared_in_root(root_build_content, d)) then
          table.insert(root_decls, d)
        end
      end
    else
      if not (root_build_present and declared_in_root(root_build_content, d)) then
        table.insert(root_decls, d)
      end
    end
  end

  local root_out, root_info
  if root_build_present then
    root_out, root_info = M.merge_root_plugins(root_build_content, root_decls)
  else
    local lines = {}
    table.insert(lines, "plugins {")
    for _, d in ipairs(root_decls) do
      table.insert(lines, "    " .. d.line)
    end
    table.insert(lines, "}")
    root_out = table.concat(lines, "\n") .. "\n"
    root_info = { modified = true, block_created = true, inserted = {} }
    for _, d in ipairs(root_decls) do
      table.insert(root_info.inserted, d.line)
    end
  end

  local catalog_out, catalog_info
  if mode == "catalog" then
    catalog_out, catalog_info = M.merge_catalog(catalog_content, version_adds, plugin_adds, library_adds)
  else
    catalog_out, catalog_info = catalog_content, { modified = false, inserted = {} }
  end

  local kotlin_jvm_decl
  for _, d in ipairs(decls) do
    if d.id == "org.jetbrains.kotlin.jvm" then
      kotlin_jvm_decl = d
    end
  end
  local omit_kotlin_version = use_buildsrc
    or use_kgp_library
    or (root_build_present and kotlin_jvm_decl and declared_in_root(root_build_content, kotlin_jvm_decl))
    or (mode == "catalog")

  local toolchain_resolver = M.detect_toolchain_resolver(settings_content)
  local jvm_target = params.jvm_target or (toolchain_resolver and "21" or nil)

  local render_aliases = {}
  for k, v in pairs(aliases) do
    render_aliases[k] = M.accessor(v)
  end

  local include_repositories = not (
    settings_content and settings_content:find("dependencyResolutionManagement", 1, true)
  )

  local build_script = type_module.render_build_script({
    mode = mode,
    pkg = params.pkg,
    module = params.module,
    kotlin_version = kotlin_version,
    spring_boot_version = spring_boot_version,
    dependency_management_version = dep_mgmt_version,
    omit_kotlin_version = omit_kotlin_version,
    kotlin_test = mode == "catalog" and "libs.kotlin.test" or 'kotlin("test")',
    aliases = render_aliases,
    buildsrc_convention = buildsrc_convention,
    kgp_as_library = use_kgp_library,
    jvm_target = jvm_target,
    repositories = include_repositories,
  })

  local files = {}
  table.insert(files, { path = params.module_dir .. "/build.gradle.kts", content = build_script })
  for _, f in ipairs(type_module.render_files({ pkg = params.pkg, module = params.module })) do
    table.insert(files, { path = params.module_dir .. "/" .. f.path, content = f.content })
  end

  local writes = {
    { path = params.settings_path, content = settings_out },
  }
  if root_build_present then
    table.insert(writes, { path = params.root_build_path, content = root_out })
  else
    table.insert(writes, { path = params.root_build_path, content = root_out, created = true })
  end
  if mode == "catalog" and catalog_info.modified then
    table.insert(writes, { path = params.catalog_path, content = catalog_out })
  end

  local dirs = {}
  table.insert(dirs, params.module_dir)
  for _, d in ipairs(type_module.source_dirs) do
    table.insert(dirs, params.module_dir .. "/" .. d)
  end

  local info = {
    mode = mode,
    settings = settings_info,
    root = root_info,
    catalog = catalog_info,
    kotlin_version = kotlin_version,
    spring_boot_version = spring_boot_version,
    omit_kotlin_version = omit_kotlin_version,
    toolchain_resolver = toolchain_resolver,
    jvm_target = jvm_target,
    buildsrc_convention = buildsrc_convention,
    kgp_as_library = use_kgp_library,
    aliases = aliases,
  }

  return {
    mode = mode,
    writes = writes,
    files = files,
    dirs = dirs,
    info = info,
    errors = {},
  }
end

return M