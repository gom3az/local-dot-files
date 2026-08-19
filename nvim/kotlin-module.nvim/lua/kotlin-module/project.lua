local M = {}

local SETTINGS_FILES = { "settings.gradle.kts", "settings.gradle" }
local MARKERS = { "settings.gradle", "settings.gradle.kts", "pom.xml", "build.gradle", "build.gradle.kts", "workspace.json" }

M.SETTINGS_FILES = SETTINGS_FILES
M.MARKERS = MARKERS

local fs

M.set_fs = function(impl)
  fs = impl
end

local function get_fs()
  if fs then
    return fs
  end
  return require("vim.fs")
end

local function real_exists(path)
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

M.find_root = function(start_dir, path_exists)
  local impl = get_fs()
  path_exists = path_exists or function(dir, name)
    return impl.exists and impl.exists(impl.joinpath(dir, name)) or real_exists(impl.joinpath(dir, name))
  end

  local dir = start_dir
  while dir and dir ~= "/" do
    for _, settings in ipairs(SETTINGS_FILES) do
      if path_exists(dir, settings) then
        return dir, settings
      end
    end
    dir = impl.dirname(dir)
  end
  return nil, nil
end

M.find_markers = function(start_dir, path_exists)
  local impl = get_fs()
  path_exists = path_exists or function(dir, name)
    return impl.exists and impl.exists(impl.joinpath(dir, name)) or real_exists(impl.joinpath(dir, name))
  end
  local found = {}
  local dir = start_dir
  while dir and dir ~= "/" do
    for _, marker in ipairs(MARKERS) do
      if path_exists(dir, marker) then
        found[#found + 1] = { dir = dir, marker = marker }
      end
    end
    dir = impl.dirname(dir)
  end
  return found
end

M.detect = function(start_dir)
  local impl = get_fs()
  local path_exists = function(dir, name)
    return impl.exists and impl.exists(impl.joinpath(dir, name)) or real_exists(impl.joinpath(dir, name))
  end
  local root, settings_file = M.find_root(start_dir, path_exists)
  local markers = M.find_markers(start_dir, path_exists)
  return {
    root = root,
    settings_file = settings_file,
    markers = markers,
  }
end

return M