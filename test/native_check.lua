vim.opt.runtimepath:prepend(vim.fn.getcwd());vim.cmd('runtime plugin/codechuman.lua')
local dir=vim.fn.tempname();vim.fn.mkdir(dir..'/.learning','p');vim.fn.writefile({'{}'},dir..'/.learning/manifest.json');vim.fn.writefile({'package main'},dir..'/main.go');vim.cmd('edit '..dir..'/main.go')
local c=require('codechuman');c.setup({cli_path=vim.v.progpath,api_base_url='https://example.org',teacher_sync_main=true})
local calls,checks,prompts=0,0,0
vim.fn.inputsecret=function()prompts=prompts+1;return 'synthetic-secret' end
local callback
vim.system=function(argv,opts,cb)
 calls=calls+1;assert(not table.concat(argv,' '):find('synthetic-secret',1,true));assert(vim.json.decode(opts.stdin).token=='synthetic-secret')
 if argv[2]=='teacher-chat' then vim.schedule(function()cb({code=0,stdout='{"messages":[]}'})end)
 else assert(argv[2]=='check-solution');checks=checks+1;callback=cb end
 return {kill=function()end}
end
vim.cmd('CodechumanTeacher');vim.wait(50);assert(checks==0,'automatic check')
vim.cmd('CodechumanCheck');assert(checks==0,'default-off bypass')
c.config.teacher_checks_enabled=true;vim.cmd('CodechumanCheck');assert(checks==1)
vim.cmd('CodechumanRun');assert(checks==1,'concurrent execution')
callback({code=0,stdout='{"outcome":"ERROR","issues":[{"code":"SOURCE_PROFILE_REJECTED"}],"advisory":true,"stale":false}'});vim.wait(50)
assert(table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('Sandbox check: ERROR',1,true))
assert(calls==2,'check triggered model request');vim.cmd('CodechumanRun');assert(checks==2)
callback({code=0,stdout='{"outcome":"PASS","issues":[],"advisory":true,"stale":true}'});vim.wait(50)
assert(table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('STALE',1,true))
vim.api.nvim_buf_delete(0,{force=true});vim.cmd('edit '..dir..'/main.go');vim.cmd('CodechumanTeacher');assert(prompts==2,'token reused after close')
vim.fn.delete(dir,'rf');print('NATIVE_SANDBOX_CHECK_PASS');vim.cmd('qa!')
