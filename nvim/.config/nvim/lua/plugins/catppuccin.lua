local gh = require("utils").gh

vim.pack.add({ gh("catppuccin/nvim") })

local theme_ok, theme = pcall(require, "theme")
if not theme_ok then theme = nil end

require("catppuccin").setup({
  flavour = "mocha",
  background = { dark = "mocha" },
  transparent_background = true,
  dim_inactive = { enabled = false },
  custom_highlights = function(colors)
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
