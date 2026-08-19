local ok, pal = pcall(require, "nvim-hl")
if not ok then
  pal = {
    bg = "#1a1b26",
    bg_alt = "#24283b",
    fg = "#a9b1d6",
    fg_alt = "#8b93b3",
    accent = "#bb9af7",
    muted = "#414868",
    error = "#f7768e",
    warning = "#e0af68",
    info = "#9ece6a",
    hint = "#7dcfff",
  }
end

local MODE_MAP = {
  ["n"] = { "NORMAL", "StModeNormal" },
  ["no"] = { "NORMAL", "StModeNormal" },
  ["v"] = { "VISUAL", "StModeVisual" },
  ["V"] = { "VISUAL", "StModeVisual" },
  ["\22"] = { "VISUAL", "StModeVisual" },
  ["i"] = { "INSERT", "StModeInsert" },
  ["ic"] = { "INSERT", "StModeInsert" },
  ["ix"] = { "INSERT", "StModeInsert" },
  ["R"] = { "REPLACE", "StModeReplace" },
  ["Rv"] = { "REPLACE", "StModeReplace" },
  ["c"] = { "COMMAND", "StModeCommand" },
  ["t"] = { "TERMINAL", "StModeTerminal" },
}

local function set_mode_groups()
  vim.api.nvim_set_hl(0, "StModeNormal", { bg = pal.accent, fg = pal.bg })
  vim.api.nvim_set_hl(0, "StModeInsert", { bg = pal.info, fg = pal.bg })
  vim.api.nvim_set_hl(0, "StModeVisual", { bg = pal.warning, fg = pal.bg })
  vim.api.nvim_set_hl(0, "StModeReplace", { bg = pal.error, fg = pal.bg })
  vim.api.nvim_set_hl(0, "StModeCommand", { bg = pal.hint, fg = pal.bg })
  vim.api.nvim_set_hl(0, "StModeTerminal", { bg = pal.muted, fg = pal.bg })
end

local function esc(s)
  return (s:gsub("%%", "%%%%"))
end

local function special_buffer()
  local bt = vim.bo.buftype
  if bt == "" then return nil end
  local name = vim.fn.bufname("%")
  local label = vim.bo.filetype ~= "" and vim.bo.filetype or bt
  local path = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
  return string.format(" %s%s %s ", esc(label), "%=", esc(path))
end

local function render()
  local ok2, result = pcall(function()
    local special = special_buffer()
    if special then return special end

    local parts = {}

    local m = MODE_MAP[vim.fn.mode(1)] or { "NORMAL", "StModeNormal" }
    table.insert(parts, string.format("%%#%s# %-7s %%*", m[2], m[1]) .. "%<")

    local rec = vim.fn.reg_recording()
    if rec ~= "" then
      table.insert(parts, "  📍 recording @" .. rec)
    end

    local head = vim.b.gitsigns_head
    if head and head ~= "" then
      table.insert(parts, "  " .. esc(head))
      local sd = vim.b.gitsigns_status_dict
      if sd then
        local diff = {}
        if (sd.added or 0) > 0 then table.insert(diff, "+" .. sd.added) end
        if (sd.removed or 0) > 0 then table.insert(diff, "-" .. sd.removed) end
        if (sd.changed or 0) > 0 then table.insert(diff, "~" .. sd.changed) end
        if #diff > 0 then table.insert(parts, " " .. table.concat(diff, " ")) end
      end
    end

    table.insert(parts, "%=")

    local err = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
    local warn = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
    if err > 0 or warn > 0 then
      local dparts = {}
      if err > 0 then dparts[#dparts + 1] = string.format("%%#DiagnosticError# E%d %%*", err) end
      if warn > 0 then dparts[#dparts + 1] = string.format("%%#DiagnosticWarn# W%d %%*", warn) end
      table.insert(parts, table.concat(dparts, " "))
    end

    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients > 0 then
      local names = {}
      for _, c in ipairs(clients) do
        local busy = c.progress and c.progress.pending and next(c.progress.pending) ~= nil
        names[#names + 1] = c.name .. (busy and "⚙" or "")
      end
      table.insert(parts, " [" .. table.concat(names, ",") .. "]")
    end

    local enc = vim.bo.fileencoding or vim.o.encoding
    table.insert(parts, string.format(" %s %s", esc(vim.bo.filetype), esc(enc)))
    table.insert(parts, " %p%% %l:%c ")

    return table.concat(parts)
  end)
  if ok2 then return result end
  return " statusline error"
end

set_mode_groups()
vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Re-apply statusline mode highlight groups",
  callback = set_mode_groups,
})
vim.api.nvim_create_autocmd("LspProgress", {
  desc = "Refresh statusline on LSP progress",
  callback = function()
    vim.cmd("redrawstatus")
  end,
})

vim.o.laststatus = 3
vim.o.statusline = "%!v:lua.require('statusline').render()"

return { render = render }