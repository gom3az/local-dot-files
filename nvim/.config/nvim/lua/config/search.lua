local gh = require('utils').gh

local telescope_plugins = {
  gh 'nvim-lua/plenary.nvim',
  gh 'nvim-telescope/telescope.nvim',
  gh 'nvim-telescope/telescope-ui-select.nvim',
}
if vim.fn.executable 'make' == 1 then
  table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim')
end

vim.pack.add(telescope_plugins)

require('telescope').setup {
  extensions = {
    ['ui-select'] = { require('telescope.themes').get_dropdown() },
  },
}

pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')

local function telescope_builtin()
  return require("telescope.builtin")
end

vim.keymap.set("n", "<leader>sh", function()
  telescope_builtin().help_tags()
end, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", function()
  telescope_builtin().keymaps()
end, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sf", function()
  telescope_builtin().find_files()
end, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>ss", function()
  telescope_builtin().builtin()
end, { desc = "[S]earch [S]elect Telescope" })
vim.keymap.set({ "n", "v" }, "<leader>sw", function()
  telescope_builtin().grep_string()
end, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", function()
  telescope_builtin().live_grep()
end, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", function()
  telescope_builtin().diagnostics()
end, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", function()
  telescope_builtin().resume()
end, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>s.", function()
  telescope_builtin().oldfiles()
end, { desc = "[S]earch Recent Files (\".\" for repeat)" })
vim.keymap.set("n", "<leader>sc", function()
  telescope_builtin().commands()
end, { desc = "[S]earch [C]ommands" })
vim.keymap.set("n", "<leader><leader>", function()
  telescope_builtin().find_files()
end, { desc = "[ ] Find files" })
vim.keymap.set("n", "<leader>fb", function()
  telescope_builtin().buffers()
end, { desc = "[F]iles [B]uffers" })
vim.keymap.set("n", "<leader>gb", function()
  telescope_builtin().git_branches()
end, { desc = "[G]it [B]ranches" })

vim.keymap.set("n", "<leader>/", function()
  telescope_builtin().current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
    winblend = 10,
    previewer = false,
  }))
end, { desc = "[/] Fuzzily search in current buffer" })

vim.keymap.set("n", "<leader>s/", function()
  telescope_builtin().live_grep({
    grep_open_files = true,
    prompt_title = "Live Grep in Open Files",
  })
end, { desc = "[S]earch [/] in Open Files" })

vim.keymap.set("n", "<leader>sn", function()
  telescope_builtin().find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files" })

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
  callback = function(event)
    local buf = event.buf
    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })
    vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })
    vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })
    vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })
    vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })
    vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
  end,
})