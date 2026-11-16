vim.opt.runtimepath:prepend(vim.fn.getcwd());vim.cmd('runtime plugin/codechuman.lua')
local dir=vim.fn.tempname();vim.fn.mkdir(dir..'/.learning','p');vim.fn.writefile({'{}'},dir..'/.learning/manifest.json');vim.fn.writefile({'package main'},dir..'/main.go');vim.cmd('edit '..dir..'/main.go')
require('codechuman').setup({cli_path=vim.v.progpath,api_base_url='https://example.org'})
vim.fn.inputsecret=function()return 'synthetic-secret'end
vim.ui.select=function(_,_,callback)callback('MILESTONE')end
local confirm=2;vim.fn.confirm=function()return confirm end
local submissions,key,original=0,nil,nil
vim.system=function(argv,opts,callback)
 local data=vim.json.decode(opts.stdin);assert(not table.concat(argv,' '):find('synthetic-secret',1,true))
 if argv[2]=='teacher-chat' then vim.schedule(function()callback({code=0,stdout='{"messages":[]}'})end)
 else
  assert(argv[2]=='submit-solution');submissions=submissions+1
  if key then assert(data.idempotency_key==key and data.replay==true and data.milestone_id=='33333333-3333-4333-8333-333333333333','replay lost original intent') else key=data.idempotency_key end
  vim.schedule(function()callback({code=0,stdout=vim.json.encode({idempotency_key=key,scope='MILESTONE',milestone_id='33333333-3333-4333-8333-333333333333',uncertain=true})})end)
 end
 return {kill=function()end}
end
vim.cmd('CodechumanTeacher');vim.wait(50);assert(submissions==0,'automatic Submit')
vim.cmd('CodechumanSubmit');assert(submissions==0,'confirmation bypass')
confirm=1;vim.cmd('CodechumanSubmit');vim.wait(50);assert(submissions==1)
vim.cmd('CodechumanSubmit');vim.wait(50);assert(submissions==2)
assert(table.concat(vim.fn.readfile(dir..'/main.go'),'\n')=='package main','user code changed')
vim.fn.delete(dir,'rf');print('NATIVE_OFFICIAL_SUBMIT_CONFIRM_REPLAY_PASS');vim.cmd('qa!')
