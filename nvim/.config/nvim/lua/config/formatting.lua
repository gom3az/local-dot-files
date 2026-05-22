local gh = require('utils').gh

vim.pack.add { gh 'stevearc/conform.nvim' }
require('conform').setup {
  notify_on_error = true,
  format_on_save = {
    timeout_ms = 2000,
    lsp_format = 'fallback',
  },
  formatters_by_ft = {
    java = { "google-java-format" },
    kotlin = {},
    lua = { "stylua" },
    json = { "jq" },
    markdown = { "prettierd" },
    yaml = { "prettierd" },
  },
}

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  require("conform").format({ async = true })
end, { desc = "[C]onform [F]ormat" })

vim.keymap.set({ "n", "x" }, "<leader>cJ", "<cmd>%!jq .<CR>", { desc = "[C]ode [J]SON format" })