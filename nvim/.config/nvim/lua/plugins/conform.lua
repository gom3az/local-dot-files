local gh = require('utils').gh

vim.pack.add { gh 'stevearc/conform.nvim' }

-- kotlin-lsp accepts format requests for *.gradle.kts but returns no edits,
-- so Gradle KTS scripts route through ktlint instead; plain .kt keeps using
-- kotlin-lsp via the LSP fallback.
require('conform').setup({
  formatters_by_ft = {
    json = { 'jq' },
    kotlin = function(bufnr)
      if vim.api.nvim_buf_get_name(bufnr):match('%.gradle%.kts$') then
        return { 'ktlint' }
      end
      return {}
    end,
  },
  default_format_opts = { lsp_format = 'fallback', timeout_ms = 10000 },
  notify_no_formatters = false,
  formatters = {
    -- File mode: ktlint's --stdin path crashes on `%` in source. With
    -- stdin=false conform writes a temp file next to the original file,
    -- so the project's .editorconfig chain still applies.
    ktlint = { args = { '--format', '--log-level=none', '$FILENAME' }, stdin = false },
  },
})

-- kotlin-lsp removes unused imports via the `source.organizeImports` code
-- action, not through formatting. nvim aggregates actions across clients
-- and, with `apply = true`, applies the action directly when exactly one
-- matches (kotlin-lsp always returns exactly one for .kt files).
local function organize_imports(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local supports_code_action = vim.iter(clients):any(function(client)
    return client:supports_method('textDocument/codeAction', bufnr)
  end)
  if not supports_code_action then return end
  vim.lsp.buf.code_action({
    bufnr = bufnr,
    context = {
      only = { 'source.organizeImports' },
      diagnostics = {},
    },
    apply = true,
  })
end

local function format_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= '' or not vim.bo[bufnr].modifiable then return end
  organize_imports(bufnr)
  require('conform').format({ bufnr = bufnr })
end

vim.api.nvim_create_autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('conform-format', { clear = true }),
  desc = 'Format buffer on save',
  callback = function(args)
    format_buffer(args.buf)
  end,
})

vim.keymap.set({ 'n', 'x' }, '<leader>cf', function()
  format_buffer(0)
end, { desc = '[C]ode [F]ormat buffer' })

vim.keymap.set({ 'n', 'x' }, '<leader>cJ', function()
  require('conform').format({ bufnr = 0, formatters = { 'jq' }, lsp_format = 'never' })
end, { desc = '[C]ode [J]SON format' })
