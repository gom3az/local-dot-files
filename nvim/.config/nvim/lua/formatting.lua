local FORMATTERS = {
  json = { cmd = { "jq", "." } },
  kotlin = { cmd = { "ktlint", "--stdin", "--format", "--log-level=none" }, stdin_path = true },
}

local function notify_truncated(msg, limit)
  local lines = vim.split(msg, "\n", { plain = true })
  if #lines > limit then
    table.insert(lines, limit + 1, "…")
    msg = table.concat(vim.list_slice(lines, 1, limit + 1), "\n")
      .. string.format(" (%d more lines)", #lines - limit)
  end
  vim.notify(msg, vim.log.levels.ERROR)
end

local function run_formatter(cmd, input)
  local done, result = false
  vim.system(cmd, { text = true, stdin = input }, function(res)
    result = res
    done = true
  end)
  if not vim.wait(10000, function() return done end) then
    return nil
  end
  return result
end

local function apply_stdout(bufnr, out)
  local has_eol = out:sub(-1) == "\n"
  local new_lines = vim.split(out, "\n", { plain = true })
  if new_lines[#new_lines] == "" then new_lines[#new_lines] = nil end
  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  vim.bo[bufnr].eol = has_eol
  vim.fn.winrestview(view)
end

-- kotlin-lsp removes unused imports via the `source.organizeImports` code
-- action, not through formatting. nvim aggregates actions across clients
-- and, with `apply = true`, applies the action directly when exactly one
-- matches (kotlin-lsp always returns exactly one for .kt files).
local function organize_imports(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local supports_code_action = vim.iter(clients):any(function(client)
    return client:supports_method('textDocument/codeAction', bufnr)
  end)
  if not supports_code_action then return end
  vim.lsp.buf.code_action({
    bufnr = bufnr,
    context = {
      only = { "source.organizeImports" },
      diagnostics = {},
    },
    apply = true,
  })
end

local function format_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].modifiable then return end

  local formatter = FORMATTERS[vim.bo[bufnr].filetype]
  if formatter and vim.fn.executable(formatter.cmd[1]) == 1 then
    local cmd = formatter.cmd
    if formatter.stdin_path then
      cmd = vim.list_extend(vim.deepcopy(cmd), { "--stdin-path=" .. vim.api.nvim_buf_get_name(bufnr) })
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local input = table.concat(lines, "\n") .. "\n"
    local result = run_formatter(cmd, input)
    if not result then
      notify_truncated(("Formatting timed out (%s)"):format(cmd[1]), 10)
      return
    end
    -- Failure: no output while the buffer had content (e.g. parse error).
    -- Never touch the buffer on failure -- otherwise the error report replaces the file.
    -- A nonzero exit with non-empty stdout (ktlint lint errors) still yields the
    -- formatted file on stdout, so it is applied.
    if result.stdout == "" and #lines > 0 then
      notify_truncated(("Formatting failed (%s): %s"):format(cmd[1], result.stderr ~= "" and result.stderr or result.stdout), 10)
      return
    end
    apply_stdout(bufnr, result.stdout)
    return
  end

  organize_imports(bufnr)
  vim.lsp.buf.format({ bufnr = bufnr, async = false })
end

vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Format buffer on save",
  callback = function(args)
    format_buffer(args.buf)
  end,
})

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  format_buffer(0)
end, { desc = "[C]ode [F]ormat buffer" })
vim.keymap.set({ "n", "x" }, "<leader>cJ", function()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].modifiable then return end
  local formatter = { "jq", "." }
  if vim.fn.executable("jq") ~= 1 then return end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local input = table.concat(lines, "\n") .. "\n"
  local result = run_formatter(formatter, input)
  if not result then
    notify_truncated("Formatting timed out (jq)", 10)
    return
  end
  if result.code ~= 0 or (result.stdout == "" and #lines > 0) then
    notify_truncated(("Formatting failed (jq): %s"):format(result.stderr ~= "" and result.stderr or result.stdout), 10)
    return
  end
  apply_stdout(bufnr, result.stdout)
end, { desc = "[C]ode [J]SON format" })

return { format = format_buffer }