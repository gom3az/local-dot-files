local gh = require("utils").gh

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
