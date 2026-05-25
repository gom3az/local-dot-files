local gh = require("utils").gh

vim.pack.add({ gh("nvim-neo-tree/neo-tree.nvim") })
vim.pack.add({ gh("nvim-tree/nvim-web-devicons") })

require("neo-tree").setup({
  close_if_last_window = false,
  enable_diagnostics = true,
  use_icons = true,
  default_component_configs = {
    indent = { with_expander = false },
    icon = {
      folder_closed = "",
      folder_open = "",
      folder_empty = "󰜌",
    },
  },
  window = {
    position = "left",
    width = 40,
  },
  filesystem = {
    follow_current_file = {
      enabled = true,
    },
    group_empty_dirs = true,
  },
})

vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "[E]xplorer" })
