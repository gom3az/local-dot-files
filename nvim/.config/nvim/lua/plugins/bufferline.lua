local gh = require("utils").gh

vim.pack.add({ gh("akinsho/bufferline.nvim") })

require("bufferline").setup({})

vim.keymap.set("n", "<leader>bn", "<cmd>BufferLineCycleNext<CR>", { desc = "[B]uffer [N]ext" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", { desc = "[B]uffer [P]rev" })
vim.keymap.set("n", "<leader>bd", "<cmd>BufferLineCloseOthers<CR>", { desc = "[B]uffer [D]elete others" })
vim.keymap.set("n", "<leader>bb", "<cmd>BufferLinePick<CR>", { desc = "[B]uffer [P]ick" })
vim.keymap.set("n", "<leader>bll", "<cmd>BufferLineMoveNext<CR>", { desc = "[B]uffer Move [L]eft" })
vim.keymap.set("n", "<leader>bhh", "<cmd>BufferLineMovePrev<CR>", { desc = "[B]uffer Move [H]left" })
