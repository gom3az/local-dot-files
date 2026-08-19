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
    gitsigns = true,
    mason = true,
    mini = true,
    neotree = true,
    telescope = true,
    which_key = true,
  },
})
vim.cmd.colorscheme("catppuccin")
