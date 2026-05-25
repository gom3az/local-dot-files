local gh = require("utils").gh

vim.pack.add({ gh("j-hui/fidget.nvim") })

require("fidget").setup({})
