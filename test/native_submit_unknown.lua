vim.opt.runtimepath:prepend(vim.fn.getcwd());vim.cmd('runtime plugin/codechuman.lua')
local dir=vim.fn.tempname();vim.fn.mkdir(dir..'/.learning','p');vim.fn.writefile({'{}'},dir..'/.learning/manifest.json');vim.fn.writefile({'package main'},dir..'/main.go');vim.cmd('edit '..dir..'/main.go')
require('codechuman').setup({cli_path=vim.v.progpath,api_base_url='https://example.org'})
vim.fn.inputsecret=function()return 'synthetic-secret'end;vim.ui.select=function(_,_,cb)cb('FINAL')end;vim.fn.confirm=function()return 1 end;vim.notify=function()end
local submits=0
vim.system=function(args,opts,cb)if args[2]=='teacher-chat' then vim.schedule(function()cb({code=0,stdout='{"messages":[]}'})end) else submits=submits+1;vim.schedule(function()cb({code=1,stdout=''})end)end;return {kill=function()end}end
local teacher=require('codechuman.teacher');teacher.open();vim.wait(100);teacher.submit();vim.wait(100);assert(submits==1);teacher.submit();vim.wait(100);assert(submits==1,'unconfirmed process failure was replayed without a confirmed upload')
vim.fn.delete(dir,'rf');vim.api.nvim_out_write('NATIVE_SUBMIT_UNKNOWN_FAIL_CLOSED_PASS\n')
