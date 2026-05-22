local gh = require('utils').gh

vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }
vim.pack.add { gh 'nvim-treesitter/nvim-treesitter-textobjects' }

vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99

local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'kotlin', 'java' }
require('nvim-treesitter').install(parsers)

local function treesitter_attach(buf, language)
  if not vim.treesitter.language.add(language) then return end
  vim.treesitter.start(buf, language)
  local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
  if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
end

local available_parsers = require('nvim-treesitter').get_available()
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local buf, filetype = args.buf, args.match
    local language = vim.treesitter.language.get_lang(filetype)
    if not language then return end
    local installed = require('nvim-treesitter').get_installed 'parsers'
    if vim.tbl_contains(installed, language) then
      treesitter_attach(buf, language)
    elseif vim.tbl_contains(available_parsers, language) then
      require('nvim-treesitter').install(language, function() treesitter_attach(buf, language) end)
    end
  end,
})