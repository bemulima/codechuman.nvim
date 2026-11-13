if vim.g.loaded_codechuman == 1 then
  return
end
vim.g.loaded_codechuman = 1

vim.api.nvim_create_user_command("CodechumanOpen", function()
  require("codechuman").open()
end, { desc = "Open Codechuman sidebar" })

vim.api.nvim_create_user_command("CodechumanRefresh", function()
  require("codechuman").refresh()
end, { desc = "Refresh Codechuman local courses" })
