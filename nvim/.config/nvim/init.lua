--[[

=====================================================================
==================== KICKSTART NVIM CONFIG ==========================
=====================================================================
Modified from: https://github.com/nvim-lua/kickstart.nvim

Modular structure - config split into lua/config/
=====================================================================
=====================================================================
--]]

require("config.foundation")
require("config.autocmds")
require("config.plugins")
require("config.ui")
require("config.search")
require("config.lsp")
require("config.formatting")
require("config.cmp")
require("config.treesitter")
require("config.dap")
require("config.java")
require("config.rest")
require("config.testing")
-- require("config.terminal")
