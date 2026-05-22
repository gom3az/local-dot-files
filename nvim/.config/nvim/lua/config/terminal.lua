local state = { job_id = 0, current_command = '' }

vim.keymap.set('n', '<space>to', function()
  vim.cmd.vnew()
  vim.cmd.term()
  vim.cmd.wincmd('J')
  vim.api.nvim_win_set_height(0, 5)
  state.job_id = vim.bo.channel
end, { desc = '[T]erminal [O]pen' })

vim.keymap.set('n', '<space>te', function()
  state.current_command = vim.fn.input 'Command: '
end, { desc = '[T]erminal [E]nter command' })

vim.keymap.set('n', '<space>tr', function()
  if state.current_command == '' then
    state.current_command = vim.fn.input 'Command: '
  end
  vim.fn.chansend(state.job_id, { state.current_command .. '\r\n' })
end, { desc = '[T]erminal [R]un command' })