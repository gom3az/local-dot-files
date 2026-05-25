local gh = require("utils").gh

vim.pack.add({ gh("folke/todo-comments.nvim") })

require("todo-comments").setup({ signs = false })
