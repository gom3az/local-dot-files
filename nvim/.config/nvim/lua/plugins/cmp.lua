local gh = require("utils").gh

vim.pack.add({ gh("saghen/blink.lib"), gh("saghen/blink.cmp") })

require("blink.cmp").setup({
  keymap = { preset = "enter" },
  completion = { documentation = { auto_show = true, auto_show_delay_ms = 500 } },
  fuzzy = { implementation = "lua" },
})
