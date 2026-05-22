local gh = require('utils').gh

vim.pack.add { gh 'nvim-neotest/neotest' }
vim.pack.add { gh 'nvim-neotest/nvim-nio' }
vim.pack.add { gh 'mfussenegger/nvim-lint' }

require('neotest').setup {
  adapters = {},
}

vim.keymap.set("n", "<leader>tt", '<cmd>lua require("neotest").run.run()<CR>', { desc = "[T]est [T]run current" })
vim.keymap.set(
  "n",
  "<leader>tf",
  '<cmd>lua require("neotest").run.run(vim.fn.expand("%"))<CR>',
  { desc = "[T]est [F]ile" }
)
vim.keymap.set("n", "<leader>ts", '<cmd>lua require("neotest").summary.toggle()<CR>', { desc = "[T]est [S]ummary" })