-- This is a native editor smoke, not just a Lua syntax parser.
-- Its deterministic fake token never leaves the temporary test process.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/codechuman.lua")
assert(vim.fn.exists(":CodechumanCheckout") == 2, "missing user command")

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
vim.cmd("CodechumanCheckout " .. id)
vim.cmd("CodechumanCheckout " .. id)
assert(prompts == 1, "duplicate checkout should not ask for another credential")

local completed = vim.wait(10000, function()
  for _, message in ipairs(messages) do
    if message:find("checkout ready", 1, true) then
      return true
    end
  end
  return false
end, 20)
assert(completed, "CLI result was not accepted by Neovim")
vim.cmd("CodechumanCheckout invalid")
assert(prompts == 1, "invalid UUID must be rejected before token prompt")
for _, message in ipairs(messages) do
  assert(not message:find("nvim-smoke-token", 1, true), "a notification leaked a token")
end
vim.api.nvim_out_write("NATIVE_NVIM_CHECKOUT_PASS\n")
