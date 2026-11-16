vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/codechuman.lua")
assert(vim.fn.exists(":CodechumanOpenTask") == 2, "missing authenticated lesson command")

local prompts = 0
vim.fn.inputsecret = function(_)
  prompts = prompts + 1
  return "nvim-smoke-token"
end
local messages = {}
vim.notify = function(message, _)
  table.insert(messages, tostring(message))
end

local api = require("codechuman")
api.setup({
  cli_path = assert(os.getenv("CODECHUMAN_NVIM_TEST_CLI")),
  workspace_root = assert(os.getenv("CODECHUMAN_NVIM_TEST_ROOT")),
  api_base_url = "https://example.org",
})

local id = "22222222-2222-4222-8222-222222222222"
vim.cmd("CodechumanOpenTask " .. id)
vim.cmd("CodechumanOpenTask invalid")
assert(prompts == 1, "invalid task identity must be rejected before token prompt")
local opened = vim.wait(10000, function()
  return vim.api.nvim_buf_get_name(0):match("/materials/aaaaaaaa%-aaaa%-4aaa%-8aaa%-aaaaaaaaaaaa/lesson%.md$") ~= nil
end, 20)
assert(opened, "authorized lesson was not opened in a Neovim buffer")
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "# Authorized Neovim lesson", "unexpected lesson contents")
local lessonPath = vim.api.nvim_buf_get_name(0)
local appPath = lessonPath:gsub("/%.learning/materials/aaaaaaaa%-aaaa%-4aaa%-8aaa%-aaaaaaaaaaaa/lesson%.md$", "/app.js")
assert(vim.fn.filereadable(appPath) == 1, "starter code was not preserved beside the lesson")
for _, message in ipairs(messages) do
  assert(not message:find("nvim-smoke-token", 1, true), "a notification leaked a token")
end
vim.api.nvim_out_write("NATIVE_NVIM_OPEN_TASK_PASS\n")
