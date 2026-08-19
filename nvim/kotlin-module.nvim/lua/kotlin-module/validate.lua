local M = {}

local WINDOWS_RESERVED = {
  CON = true, PRN = true, AUX = true, NUL = true,
}

local function is_reserved_windows(name)
  local upper = name:upper()
  if WINDOWS_RESERVED[upper] then
    return true
  end
  if upper:match("^COM[1-9]$") or upper:match("^LPT[1-9]$") then
    return true
  end
  return false
end

M.validate_module_name = function(name)
  if name == nil or name == "" then
    return "Module name must not be empty"
  end
  if name:match("[/: \t\r\n]") then
    return string.format("Module name `%s` is not a valid Gradle path segment", name)
  end
  if name:match("[%z\1-\31\127]") then
    return string.format("Module name `%s` contains control characters", name)
  end
  if name:sub(1, 1) == "." then
    return string.format("Module name `%s` must not start with `.`", name)
  end
  if name == "." or name == ".." or name == "build" or name == "gradle" or name == "settings"
    or name == "settings.gradle" or name == "settings.gradle.kts" then
    return string.format("Module name `%s` is reserved", name)
  end
  if is_reserved_windows(name) then
    return string.format("Module name `%s` is a reserved Windows device name", name)
  end
  if name:match("[. ]$") then
    return string.format("Module name `%s` must not end with a dot or space", name)
  end
  return nil
end

M.validate_package = function(pkg)
  if pkg == nil or pkg == "" then
    return "Base package must not be empty"
  end
  if pkg:sub(1, 1) == "." or pkg:sub(-1) == "." then
    return string.format("Base package `%s` must not start or end with a dot", pkg)
  end
  for segment in pkg:gmatch("[^.]+") do
    if not segment:match("^[A-Za-z_][A-Za-z0-9_]*$") then
      return string.format("Base package `%s` contains an invalid segment `%s`", pkg, segment)
    end
  end
  if pkg:find("%.%.") then
    return string.format("Base package `%s` contains an empty segment", pkg)
  end
  return nil
end

M.package_to_path = function(pkg)
  return pkg:gsub("%.", "/")
end

M.normalize_include_name = function(raw)
  local name = raw:gsub("^:+", "")
  return name
end

M.module_collides = function(name, existing_dirs, include_names)
  for _, dir in ipairs(existing_dirs or {}) do
    local base = dir:match("([^/\\]+)/?$") or dir
    if dir == name or base == name then
      return "Module `" .. name .. "` already exists as a directory"
    end
  end
  for _, inc in ipairs(include_names or {}) do
    if inc == name then
      return "Module `" .. name .. "` already exists in settings (" .. inc .. ")"
    end
  end
  return nil
end

return M