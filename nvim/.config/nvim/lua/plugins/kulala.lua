local gh = require('utils').gh

vim.pack.add { gh 'mistweaverco/kulala.nvim' }

require('kulala').setup {
  global_keymaps = false,
  lsp = {
    formatter = false,
  },
}

vim.keymap.set("n", "<leader>rs", '<cmd>lua require("kulala").run()<CR>', { desc = "[R]est [S]end request" })
vim.keymap.set("n", "<leader>ra", '<cmd>lua require("kulala").run_all()<CR>', { desc = "[R]est [A]ll requests" })
vim.keymap.set("n", "<leader>rr", '<cmd>lua require("kulala").replay()<CR>', { desc = "[R]est [R]eplay" })
vim.keymap.set("n", "<leader>rf", '<cmd>lua require("kulala").search()<CR>', { desc = "[R]est [F]ind request" })
