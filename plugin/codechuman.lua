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

vim.api.nvim_create_user_command("CodechumanCheckout", function(args)
  require("codechuman").checkout_remote(args.args)
end, { nargs = 1, desc = "Fetch an authorized TaskInstance via HTTPS and the Codechuman CLI" })

vim.api.nvim_create_user_command("CodechumanOpenTask", function(args)
  require("codechuman").open_task(args.args)
end, { nargs = 1, desc = "Fetch and open an authorized lesson and starter via HTTPS" })

vim.api.nvim_create_user_command('CodechumanTeacher', function()
  require('codechuman.teacher').open()
end, { desc = 'Open task-scoped Teacher chat through Gateway and Dialog' })
vim.api.nvim_create_user_command('CodechumanAsk', function(args)
  require('codechuman.teacher').ask(args.args ~= '' and args.args or nil)
end, { nargs = '*', desc = 'Ask in the open task Teacher conversation' })

for _,name in ipairs({'CodechumanRun','CodechumanCheck'}) do
 vim.api.nvim_create_user_command(name,function()require('codechuman.teacher').check()end,{desc='Run saved main.go and advisory public checks in Sandbox'})
end

vim.api.nvim_create_user_command('CodechumanSubmit',function()require('codechuman.teacher').submit()end,{desc='Explicit official Practice submission (confirmation required)'})

vim.api.nvim_create_user_command('CodechumanSyncSaved',function()require('codechuman.sync').manual()end,{desc='Explicit saved main.go upload and atomic ACK'})
vim.api.nvim_create_user_command('CodechumanAutoSyncEnable',function()require('codechuman.sync').enable()end,{desc='Opt in to saved main.go debounce after manual ACK'})
vim.api.nvim_create_user_command('CodechumanAutoSyncDisable',function()require('codechuman.sync').disable()end,{desc='Stop all saved-main sync and forget sync credentials'})
