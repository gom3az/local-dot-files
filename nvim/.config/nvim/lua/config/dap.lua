local gh = require('utils').gh

vim.pack.add {
  gh 'mfussenegger/nvim-dap',
  gh 'jay-babu/mason-nvim-dap.nvim',
  gh 'theHamsta/nvim-dap-virtual-text',
  gh 'rcarriga/nvim-dap-ui',
  gh 'nvim-neotest/nvim-nio',
}

require('dapui').setup {}

vim.keymap.set("n", "<leader>dt", "<cmd>DapToggleBreakpoint<CR>", { desc = "[D]ebug [T]oggle breakpoint" })
vim.keymap.set("n", "<leader>dc", "<cmd>DapContinue<CR>", { desc = "[D]ebug [C]ontinue" })
vim.keymap.set("n", "<leader>di", "<cmd>DapStepInto<CR>", { desc = "[D]ebug [I]nto" })
vim.keymap.set("n", "<leader>do", "<cmd>DapStepOver<CR>", { desc = "[D]ebug [O]ver" })
vim.keymap.set("n", "<leader>dO", "<cmd>DapStepOut<CR>", { desc = "[D]ebug Out" })

local dap = require 'dap'
dap.adapters.kotlin = {
  type = 'executable',
  command = 'kotlin-debug-adapter',
  options = { auto_continue_if_many_stopped = false },
}

dap.configurations.kotlin = {
  {
    type = 'kotlin',
    request = 'launch',
    name = 'This file',
    mainClass = function()
      local root = vim.fs.find('src', { path = vim.uv.cwd(), upward = true, stop = vim.env.HOME })[1] or ''
      local fname = vim.api.nvim_buf_get_name(0)
      local function escape_pattern(s) return (s:gsub('[%(%)%.%%%+%-%*%?%[%^%$%]]', '%%%1')) end
      return fname
        :gsub(escape_pattern(root), '')
        :gsub('main/kotlin/', '')
        :gsub('.kt', 'Kt')
        :gsub('/', '.')
        :sub(2, -1)
    end,
    projectRoot = '${workspaceFolder}',
  },
  {
    type = 'kotlin',
    request = 'attach',
    name = 'Attach to debugging session',
    port = 5005,
    args = {},
    projectRoot = vim.fn.getcwd,
    hostName = 'localhost',
    timeout = 2000,
  },
}