local dir = vim.fs.normalize(vim.uv.fs_realpath(vim.fn.stdpath("config")) .. "/../../kotlin-module.nvim")
vim.opt.rtp:append(dir)

vim.keymap.set("n", "<leader>km", "<cmd>NewKotlinModule<cr>", { desc = "New Kotlin module" })

require("kotlin-module").setup({
  kotlin_version = "2.3.21",
  spring_boot_version = "4.1.0",
  dependency_management_version = "1.1.7",
})

