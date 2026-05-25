local gh = require("utils").gh

vim.pack.add({ gh("echasnovski/mini.nvim") })

require("mini.pairs").setup()
require("mini.ai").setup({
  mappings = {
    around_next = "aa",
    inside_next = "ii",
  },
  n_lines = 500,
})
