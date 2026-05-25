local gh = require("utils").gh

vim.pack.add({ gh("NeogitOrg/neogit") })
vim.pack.add({ gh("sindrets/diffview.nvim") })

require("neogit").setup({})
require("diffview").setup({})

vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "[G]it [G]it (Neogit)" })
vim.keymap.set("n", "<leader>gdc", "<cmd>DiffviewOpen<CR>", { desc = "[G]it [D]iff [C]urrent file" })
vim.keymap.set("n", "<leader>gdh", "<cmd>DiffviewFileHistory<CR>", { desc = "[G]it [D]iff [H]istory" })
