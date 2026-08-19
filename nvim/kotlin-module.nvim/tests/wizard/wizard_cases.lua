local wizard = require("kotlin-module.wizard")

local select_queue = {}
local input_queue = {}
local notify_messages = {}

local function make_ui()
  local calls = {}
  local ui = {}
  ui.calls = calls
  ui.select = function(items, opts, cb)
    table.insert(calls, { kind = "select", items = items, prompt = opts and opts.prompt, default = opts and opts.default })
    local choice = table.remove(select_queue, 1)
    return cb(choice, choice)
  end
  ui.input = function(opts, cb)
    table.insert(calls, { kind = "input", prompt = opts and opts.prompt, default = opts and opts.default })
    local value = table.remove(input_queue, 1)
    return cb(value)
  end
  return ui
end

local function test_notify(msg, level)
  table.insert(notify_messages, { msg = msg, level = level })
end

local function reset(selects, inputs)
  select_queue = {}
  for _, v in ipairs(selects or {}) do
    select_queue[#select_queue + 1] = v
  end
  input_queue = {}
  for _, v in ipairs(inputs or {}) do
    input_queue[#input_queue + 1] = v
  end
  notify_messages = {}
end

local function run_state(params)
  params = params or {}
  local state = {
    ui = make_ui(),
    notify = test_notify,
    inline = params.inline,
    defaults = params.defaults,
  }
  local result, cancel
  wizard.run(state, function(r, c)
    result = r
    cancel = c
  end)
  return result, cancel
end

local function report(ok, result, cancel)
  if not ok then
    return "FAIL: " .. tostring(result)
  end
  return string.format("result type=%s module=%s pkg=%s dsl=%s kotlin=%s boot=%s cancel=%s",
    tostring(result and result.type_id), tostring(result and result.module),
    tostring(result and result.pkg), tostring(result and result.dsl),
    tostring(result and result.kotlin_version), tostring(result and result.spring_boot_version),
    tostring(cancel))
end

local TYPE_JVM = { id = "jvm-lib", label = "Kotlin JVM Library" }
local TYPE_BOOT = { id = "spring-boot", label = "Spring Boot" }

local cases = {}

cases.happy_path = function()
  reset({ TYPE_BOOT, "kotlin" }, { "order-service", "com.acme" })
  local result, cancel = run_state({ inline = false })
  local ok = result ~= nil and cancel == nil
    and result.type_id == "spring-boot" and result.module == "order-service"
    and result.pkg == "com.acme" and result.dsl == "kotlin"
  if not ok then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.inline_versions = function()
  reset({ TYPE_JVM, "kotlin" }, { "lib", "com.acme", "2.5.10" })
  local result, cancel = run_state({ inline = true })
  local ok = result ~= nil and cancel == nil
    and result.type_id == "jvm-lib" and result.kotlin_version == "2.5.10"
  if not ok then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.inline_spring_versions = function()
  reset({ TYPE_BOOT, "kotlin" }, { "svc", "com.acme", "2.5.10", "3.4.1" })
  local result, cancel = run_state({ inline = true })
  local ok = result ~= nil and cancel == nil
    and result.kotlin_version == "2.5.10" and result.spring_boot_version == "3.4.1"
  if not ok then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.cancel_at_type = function()
  reset({})
  local result, cancel = run_state({ inline = false })
  if result ~= nil or cancel ~= "cancel" then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.cancel_at_name = function()
  reset({ TYPE_JVM }, {})
  local result, cancel = run_state({ inline = false })
  if result ~= nil or cancel ~= "cancel" then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.invalid_name_reprompts = function()
  reset({ TYPE_JVM, "kotlin" }, { "bad/name", "lib", "com.acme" })
  local result, cancel = run_state({ inline = false })
  local reprompted = false
  for _, m in ipairs(notify_messages) do
    if m.msg:find("not a valid Gradle path segment") then
      reprompted = true
    end
  end
  local ok = result ~= nil and result.module == "lib" and reprompted
  if not ok then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.groovy_aborts = function()
  reset({ TYPE_JVM, "groovy" }, { "lib", "com.acme" })
  local result, cancel = run_state({ inline = false })
  local warned = false
  for _, m in ipairs(notify_messages) do
    if m.msg:find("not supported") then
      warned = true
    end
  end
  if result ~= nil or cancel ~= "groovy-unsupported" or not warned then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.invalid_package_reprompts = function()
  reset({ TYPE_JVM, "kotlin" }, { "lib", "1bad", "com.acme" })
  local result, cancel = run_state({ inline = false })
  local reprompted = false
  for _, m in ipairs(notify_messages) do
    if m.msg:find("invalid") then
      reprompted = true
    end
  end
  local ok = result ~= nil and result.pkg == "com.acme" and reprompted
  if not ok then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

cases.inherited_defaults = function()
  reset({ TYPE_JVM, "kotlin" }, { "lib", "com.acme.team", "2.5.10" })
  local result, cancel = run_state({
    inline = true,
    defaults = { pkg = "com.acme.team", kotlin = "2.5.10", dsl = "kotlin" },
  })
  local ok = result ~= nil and cancel == nil
    and result.pkg == "com.acme.team" and result.kotlin_version == "2.5.10"
  if not ok then
    return report(false, result, cancel)
  end
  return report(true, result, cancel)
end

local order = {
  "happy_path",
  "inline_versions",
  "inline_spring_versions",
  "cancel_at_type",
  "cancel_at_name",
  "invalid_name_reprompts",
  "groovy_aborts",
  "invalid_package_reprompts",
  "inherited_defaults",
}
local failed = 0
for _, name in ipairs(order) do
  local fn = cases[name]
  local out = fn()
  if out:match("^result ") then
    print("[PASS] " .. name)
  else
    failed = failed + 1
    print("[FAIL] " .. name .. ": " .. out)
  end
end
print(string.format("%d/%d wizard cases passed", #order - failed, #order))
if failed > 0 then
  os.exit(1)
end
os.exit(0)