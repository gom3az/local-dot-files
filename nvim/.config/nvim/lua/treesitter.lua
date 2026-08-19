local gh = require('utils').gh

vim.pack.add { gh 'nvim-treesitter/nvim-treesitter' }

local parser_dir = vim.fn.stdpath('data') .. '/site/parser'

vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('native-treesitter', { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if lang and vim.fn.filereadable(parser_dir .. '/' .. lang .. '.so') == 1 then
      vim.treesitter.start(args.buf, lang)
    end
  end,
})