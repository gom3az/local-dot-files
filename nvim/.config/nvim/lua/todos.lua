local M = {}

local keywords = {
  TODO = 'DiagnosticWarn',
  FIXME = 'DiagnosticError',
  HACK = 'WarningMsg',
  WARN = 'DiagnosticWarn',
  PERF = 'DiagnosticInfo',
  NOTE = 'DiagnosticHint',
}

for kw, hl in pairs(keywords) do
  vim.api.nvim_set_hl(0, 'NativeTodo' .. kw, { link = hl })
end

local function apply()
  for kw in pairs(keywords) do
    vim.cmd('syntax clear NativeTodo' .. kw)
    vim.cmd('syntax match NativeTodo' .. kw .. ' /\\c\\<' .. kw .. '\\>/ containedin=.*Comment.*')
  end
end

local aug = vim.api.nvim_create_augroup('native-todo', { clear = true })

local function schedule_apply()
  vim.schedule(function()
    pcall(apply)
  end)
end

vim.api.nvim_create_autocmd({ 'FileType', 'Syntax' }, {
  group = aug,
  callback = function()
    if vim.bo.filetype == '' then
      return
    end
    if vim.bo.syntax ~= '' and vim.fn.exists('b:current_syntax') == 1 then
      pcall(apply)
    else
      schedule_apply()
    end
  end,
})

return M