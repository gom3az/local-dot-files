local gh = require('utils').gh

vim.pack.add {
  gh 'mfussenegger/nvim-dap',
  gh 'jay-babu/mason-nvim-dap.nvim',
  gh 'theHamsta/nvim-dap-virtual-text',
  gh 'rcarriga/nvim-dap-ui',
}

require('dapui').setup {}

local dapui = require('dapui')
local dap = require 'dap'
dap.listeners.before.attach.dapui_config = function()
  dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

vim.keymap.set("n", "<leader>dt", "<cmd>DapToggleBreakpoint<CR>", { desc = "[D]ebug [T]oggle breakpoint" })
vim.keymap.set("n", "<leader>dc", "<cmd>DapContinue<CR>", { desc = "[D]ebug [C]ontinue" })
vim.keymap.set("n", "<leader>di", "<cmd>DapStepInto<CR>", { desc = "[D]ebug [I]nto" })
vim.keymap.set("n", "<leader>do", "<cmd>DapStepOver<CR>", { desc = "[D]ebug [O]ver" })
vim.keymap.set("n", "<leader>dO", "<cmd>DapStepOut<CR>", { desc = "[D]ebug Out" })
vim.keymap.set("n", "<leader>du", "<cmd>lua require('dapui').toggle()<CR>", { desc = "[D]ebug toggle [U]I" })

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

dap.configurations.java = dap.configurations.java or {}
table.insert(dap.configurations.java, {
  type = 'java',
  request = 'attach',
  name = 'Attach to Spring Boot (5005)',
  hostName = '127.0.0.1',
  port = 5005,
  timeout = 20000,
})
