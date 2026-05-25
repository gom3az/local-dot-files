local gh = require("utils").gh

vim.pack.add({ gh("folke/noice.nvim") })

require("noice").setup({})
