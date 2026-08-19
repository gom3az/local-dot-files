local M = {}

local validate = require("kotlin-module.validate")

M.TYPES = {
  { id = "jvm-lib", label = "Kotlin JVM Library" },
  { id = "spring-boot", label = "Spring Boot" },
}

local function notify(state, msg, level)
  local fn = state.notify or vim.notify
  fn(msg, level or vim.log.levels.INFO)
end

M.run = function(state, on_done)
  state.ui = state.ui or vim.ui
  state.notify = state.notify or vim.notify
  local defaults = state.defaults or {}
  local inline = state.inline
  local result = {}

  local function select_prompt(items, prompt, format_item, default, next)
    local opts = { prompt = prompt }
    if format_item then
      opts.format_item = format_item
    end
    if default then
      opts.default = default
    end
    state.ui.select(items, opts, next)
  end

  local function input_prompt(prompt, default, next)
    state.ui.input({ prompt = prompt, default = default or "" }, next)
  end

  local ask_type, ask_name, ask_pkg, ask_dsl, ask_kotlin_version, ask_spring_version

  ask_type = function()
    select_prompt(M.TYPES, "kotlin-module: module type",
      function(item) return item.label end, 1,
      function(choice)
        if not choice then
          on_done(nil, "cancel")
          return
        end
        result.type_id = choice.id
        ask_name()
      end)
  end

  ask_name = function()
    input_prompt("kotlin-module: module name [enter to confirm, <Esc> to cancel]", nil,
      function(module)
        if module == nil then
          on_done(nil, "cancel")
          return
        end
        local err = validate.validate_module_name(module)
        if err then
          notify(state, err, vim.log.levels.WARN)
          ask_name()
          return
        end
        result.module = module
        ask_pkg()
      end)
  end

  ask_pkg = function()
    input_prompt("kotlin-module: base package [enter to confirm, <Esc> to cancel]", defaults.pkg or "com.example",
      function(pkg)
        if pkg == nil then
          on_done(nil, "cancel")
          return
        end
        local err = validate.validate_package(pkg)
        if err then
          notify(state, err, vim.log.levels.WARN)
          ask_pkg()
          return
        end
        result.pkg = pkg
        ask_dsl()
      end)
  end

  ask_dsl = function()
    select_prompt({ "kotlin", "groovy" }, "kotlin-module: build-script DSL",
      nil, defaults.dsl == "groovy" and 2 or 1,
      function(dsl)
        if not dsl then
          on_done(nil, "cancel")
          return
        end
        if dsl == "groovy" then
          notify(state, "Groovy `build.gradle` generation is not supported in MVP", vim.log.levels.WARN)
          on_done(nil, "groovy-unsupported")
          return
        end
        result.dsl = dsl
        if inline then
          ask_kotlin_version()
        else
          on_done(result, nil)
        end
      end)
  end

  ask_kotlin_version = function()
    input_prompt("kotlin-module: Kotlin version", defaults.kotlin or "2.4.10",
      function(version)
        if version == nil then
          on_done(nil, "cancel")
          return
        end
        if version == "" then
          notify(state, "Kotlin version must not be empty", vim.log.levels.WARN)
          ask_kotlin_version()
          return
        end
        result.kotlin_version = version
        if result.type_id == "spring-boot" then
          ask_spring_version()
        else
          on_done(result, nil)
        end
      end)
  end

  ask_spring_version = function()
    input_prompt("kotlin-module: Spring Boot version", defaults.spring_boot or "3.5.0",
      function(version)
        if version == nil then
          on_done(nil, "cancel")
          return
        end
        if version == "" then
          notify(state, "Spring Boot version must not be empty", vim.log.levels.WARN)
          ask_spring_version()
          return
        end
        result.spring_boot_version = version
        on_done(result, nil)
      end)
  end

  ask_type()
end

M.confirm = function(state, summary, on_done)
  state = state or {}
  state.ui = state.ui or vim.ui
  state.ui.select({ "create", "cancel" }, { prompt = summary }, on_done)
end

return M