local ok, hl = pcall(require, "nvim-hl")
if not ok then return end

local s = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end

-- Canvas
s("Normal",        { fg = hl.fg, bg = hl.bg })
s("NormalFloat",   { fg = hl.fg, bg = hl.bg_alt })
s("FloatBorder",   { fg = hl.border, bg = hl.bg_alt })
s("FloatTitle",    { fg = hl.accent, bg = hl.bg_alt })

-- Lines
s("CursorLine",    { bg = hl.bg_alt })
s("CursorLineNr",  { fg = hl.fg, bg = hl.bg_alt })
s("LineNr",        { fg = hl.muted })
s("Visual",        { bg = hl.accent, fg = hl.bg })
s("WinSeparator",  { fg = hl.border })

-- Search
s("Search",        { bg = hl.accent, fg = hl.bg })
s("IncSearch",     { bg = hl.warning, fg = hl.bg })
s("CurSearch",     { bg = hl.accent, fg = hl.bg })

-- Popup menu
s("Pmenu",         { bg = hl.bg_alt, fg = hl.fg })
s("PmenuSel",      { bg = hl.accent, fg = hl.bg })
s("PmenuSbar",     { bg = hl.bg_alt })
s("PmenuThumb",    { bg = hl.muted })

-- Statusline / Tabline
s("StatusLine",    { bg = hl.bg_alt, fg = hl.fg })
s("StatusLineNC",  { bg = hl.bg, fg = hl.fg_alt })
s("TabLine",       { bg = hl.bg_alt, fg = hl.fg_alt })
s("TabLineSel",    { bg = hl.accent, fg = hl.bg })
s("TabLineFill",   { bg = hl.bg })
s("WinBar",        { bg = hl.bg_alt, fg = hl.fg })
s("WinBarNC",      { bg = hl.bg, fg = hl.fg_alt })

-- Misc
s("NonText",       { fg = hl.muted })
s("Whitespace",    { fg = hl.muted })

-- Diagnostics
s("DiagnosticError",  { fg = hl.error })
s("DiagnosticWarn",   { fg = hl.warning })
s("DiagnosticInfo",   { fg = hl.info })
s("DiagnosticHint",   { fg = hl.hint })

-- Git signs
s("DiffAdd",       { fg = hl.info })
s("DiffChange",    { fg = hl.warning })
s("DiffDelete",    { fg = hl.error })

-- Spelling
s("SpellBad",      { sp = hl.error, undercurl = true })
s("SpellCap",      { sp = hl.warning, undercurl = true })
s("SpellRare",     { sp = hl.accent, undercurl = true })
