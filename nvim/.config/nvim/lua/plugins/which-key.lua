local gh = require("utils").gh

vim.pack.add({ gh("folke/which-key.nvim") })

require("which-key").setup({
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
  spec = {
    { "<leader>c", group = "[C]ode", mode = { "n", "x" } },
    { "<leader>s", group = "[S]earch", mode = { "n", "v" } },
    { "<leader>t", group = "[T]oggle" },
    { "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
    { "gr", group = "LSP Actions", mode = { "n" } },
  },
})
