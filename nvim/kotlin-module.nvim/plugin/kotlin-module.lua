if vim.g.loaded_kotlin_module then
  return
end

vim.api.nvim_create_user_command("NewKotlinModule", function()
  require("kotlin-module").new_module()
end, { desc = "Create a new Kotlin/Gradle module (IntelliJ-style wizard)" })