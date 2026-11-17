vim.opt.runtimepath:prepend(vim.fn.getcwd());vim.cmd('runtime plugin/codechuman.lua')
local dir=vim.fn.tempname();vim.fn.mkdir(dir..'/.learning','p');vim.fn.writefile({'{"task_instance_id":"22222222-2222-4222-8222-222222222222"}'},dir..'/.learning/manifest.json');vim.fn.writefile({'package main'},dir..'/main.go');dir=vim.uv.fs_realpath(dir);vim.cmd('edit '..dir..'/main.go')
require('codechuman').setup({cli_path=vim.v.progpath,api_base_url='https://example.org'})
local sync=require('codechuman.sync');local calls,initialized,drift=0,false,false
vim.fn.inputsecret=function()return 'sync-test-secret'end;vim.notify=function()end
vim.system=function(argv,opts,callback)
 assert(not table.concat(argv,' '):find('sync-test-secret',1,true));assert(argv[2]=='sync-saved');local data=vim.json.decode(opts.stdin);assert(data.token=='sync-test-secret');calls=calls+1
 if not initialized then assert(data.initialize==true and data.expected_fence_epoch==nil);initialized=true else assert(data.initialize==false and data.expected_fence_epoch==7)end
 vim.defer_fn(function()callback({code=drift and 1 or 0,stdout=vim.json.encode({schema='codechuman.saved-sync.v1',task_instance_id='22222222-2222-4222-8222-222222222222',fence_epoch=7,main_digest='sha256:'..string.rep('a',64)})})end,20)
 return {kill=function()end}
end
sync.enable();vim.cmd('write');vim.wait(1100);assert(calls==0,'automatic writes activated without manual ACK')
sync.manual();assert(vim.wait(500,function()return calls==1 and not sync.blocks(dir)end,10));sync.enable();assert(sync.blocks(dir))
for n=1,3 do vim.api.nvim_buf_set_lines(0,0,-1,false,{'package main','//save '..n});vim.cmd('write');vim.wait(50)end
assert(vim.wait(1500,function()return calls==2 end,10),'saves were not coalesced');vim.wait(60);assert(calls==2)
drift=true;vim.cmd('write');assert(vim.wait(1500,function()return calls==3 and not sync.blocks(dir)end,10),'remote drift did not halt sync');vim.cmd('write');vim.wait(1100);assert(calls==3,'halted sync retried without review')
assert(vim.fn.readfile(dir..'/main.go')[2]=='//save 3','local changes lost');sync.disable();vim.fn.delete(dir,'rf');vim.api.nvim_out_write('NATIVE_SAVED_SYNC_COALESCE_FENCE_PASS\n')
