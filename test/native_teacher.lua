vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/codechuman.lua')
local dir=vim.fn.tempname();vim.fn.mkdir(dir..'/.learning','p');vim.fn.writefile({'{}'},dir..'/.learning/manifest.json');vim.fn.writefile({'package main'},dir..'/main.go');vim.cmd('edit '..dir..'/main.go')
require('codechuman').setup({cli_path=vim.v.progpath,api_base_url='https://example.org'})
local prompts,calls=0,0
vim.fn.inputsecret=function()prompts=prompts+1;return 'synthetic-secret' end
local original=vim.system
vim.system=function(argv,opts,callback)
 calls=calls+1;assert(not table.concat(argv,' '):find('synthetic-secret',1,true),'token in argv');local data=vim.json.decode(opts.stdin);assert(data.token=='synthetic-secret');assert(argv[2]=='teacher-chat')
 if data.body~='' then assert(data.idempotency_key:match('^[0-9a-f]+%-[0-9a-f]+%-4[0-9a-f]+%-8[0-9a-f]+%-[0-9a-f]+$'),'invalid key') end
 vim.schedule(function()callback({code=0,stdout=vim.json.encode({messages={{author_type='personal_teacher',body='Question\27[31m'}}})})end)
 return {kill=function()end}
end
vim.cmd('CodechumanTeacher');assert(vim.wait(2000,function()return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('Question',1,true)~=nil end,10))
assert(not table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('\27',1,true),'control sequence rendered')
vim.cmd('CodechumanAsk Explain routing');assert(vim.wait(2000,function()return calls==2 end,10));vim.wait(30)
vim.api.nvim_buf_delete(0,{force=true});vim.cmd('edit '..dir..'/main.go');vim.cmd('CodechumanTeacher');assert(prompts==2,'closed token reused')
vim.system=original;vim.fn.delete(dir,'rf');print('NATIVE_TEACHER_SESSION_SECURITY_PASS');vim.cmd('qa!')
