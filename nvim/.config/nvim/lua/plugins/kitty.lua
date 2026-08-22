local gh = require("utils").gh

vim.pack.add({ gh("mikesmithgh/kitty-scrollback.nvim") })

require("kitty-scrollback").setup()
