local gh = require("utils").gh

-- Load dynamic wallpaper theme colors if available
local theme_ok, theme = pcall(require, "theme")
if not theme_ok then theme = nil end

vim.pack.add({ gh("catppuccin/nvim") })
require("catppuccin").setup({
  flavour = "mocha",
  background = { dark = "mocha" },
  transparent_background = true,
  dim_inactive = { enabled = false },
  custom_highlights = function(colors)
    -- Override Catppuccin palette with extracted wallpaper colors
    if theme then theme.override(colors) end
    return {
      Normal = { bg = "NONE" },
      NormalFloat = { bg = "NONE" },
      FloatBorder = { bg = "NONE", fg = colors.surface0 },
      NeoTreeNormal = { bg = "NONE" },
      NeoTreeNormalNC = { bg = "NONE" },
      OilNormal = { bg = "NONE" },
      OilDir = { fg = colors.blue, bg = "NONE" },
      OilFile = { fg = colors.text, bg = "NONE" },
      OilLink = { fg = colors.subtext1, bg = "NONE" },
      OilLinkTarget = { fg = colors.subtext1, bg = "NONE" },
      OilPermission = { fg = colors.subtext1, bg = "NONE" },
      OilIndicator = { fg = colors.subtext1, bg = "NONE" },
      OilPaneBorder = { fg = colors.surface0, bg = "NONE" },
      OilCursorLine = { bg = colors.surface0 },
      OilSelect = { bg = colors.surface0 },
      NvimTreeNormal = { bg = "NONE" },
      NvimTreeNormalNC = { bg = "NONE" },
    }
  end,
  lsp_styles = {
    underlines = {
      errors = { "undercurl" },
      hints = { "undercurl" },
      warnings = { "underline" },
      information = { "underline" },
    },
  },
  integrations = {
    aerial = true,
    alpha = true,
    dashboard = false,
    flash = true,
    fzf = true,
    gitsigns = true,
    headlines = true,
    illuminate = true,
    indent_blankline = { enabled = true },
    lsp_trouble = true,
    mason = true,
    mini = true,
    navic = { enabled = true, custom_bg = "lualine" },
    neotest = true,
    neotree = true,
    noice = true,
    notify = true,
    telescope = true,
    treesitter_context = true,
    which_key = true,
  },
})
vim.cmd.colorscheme("catppuccin")

vim.pack.add({ gh("echasnovski/mini.nvim") })
require("mini.pairs").setup()
require("mini.ai").setup({
  mappings = {
    around_next = "aa",
    inside_next = "ii",
  },
  n_lines = 500,
})
vim.pack.add({ gh("MunifTanjim/nui.nvim") })
vim.pack.add({ gh("nvim-lua/plenary.nvim") })
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

vim.pack.add({ gh("akinsho/bufferline.nvim") })
require("bufferline").setup({})

vim.keymap.set("n", "<leader>bn", "<cmd>BufferLineCycleNext<CR>", { desc = "[B]uffer [N]ext" })
vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", { desc = "[B]uffer [P]rev" })
vim.keymap.set("n", "<leader>bd", "<cmd>BufferLineCloseOthers<CR>", { desc = "[B]uffer [D]elete others" })
vim.keymap.set("n", "<leader>bb", "<cmd>BufferLinePick<CR>", { desc = "[B]uffer [P]ick" })
vim.keymap.set("n", "<leader>bll", "<cmd>BufferLineMoveNext<CR>", { desc = "[B]uffer Move [L]eft" })
vim.keymap.set("n", "<leader>bhh", "<cmd>BufferLineMovePrev<CR>", { desc = "[B]uffer Move [H]left" })

vim.pack.add({ gh("lewis6991/gitsigns.nvim") })
require("gitsigns").setup({
  signs = {
    add = { text = "+" },
    change = { text = "~" },
    delete = { text = "_" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
  },
})

vim.pack.add({ gh("NeogitOrg/neogit") })
require("neogit").setup({})

vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "[G]it [G]it (Neogit)" })
vim.keymap.set("n", "<leader>gdc", "<cmd>DiffviewOpen<CR>", { desc = "[G]it [D]iff [C]urrent file" })
vim.keymap.set("n", "<leader>gdh", "<cmd>DiffviewFileHistory<CR>", { desc = "[G]it [D]iff [H]istory" })

vim.pack.add({ gh("sindrets/diffview.nvim") })
require("diffview").setup({})

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

vim.pack.add({ gh("folke/todo-comments.nvim") })
require("todo-comments").setup({ signs = false })

vim.pack.add({ gh("folke/noice.nvim") })
require("noice").setup({})

vim.pack.add({ gh("j-hui/fidget.nvim") })
require("fidget").setup({})

vim.pack.add({ gh("nvim-lualine/lualine.nvim") })
require("lualine").setup({
  options = {
    theme = "catppuccin-mocha",
    component_separators = "|",
    section_separators = "",
  },
  sections = {
    lualine_c = {
      {
        function()
          local rec = vim.fn.reg_recording()
          if rec ~= "" then
            return "📍 recording @" .. rec
          end
          return ""
        end,
      },
    },
  },
})
