-- Opt-in saved-main synchronization. Every automatic write compares the last
-- server ACK. Credentials and ACKs live only in this Neovim process.
local M = {}
local states = {}
local function current()
 local name=vim.api.nvim_buf_get_name(0)
 if vim.fn.fnamemodify(name,':t')~='main.go' then return end
 local dir=vim.uv.fs_realpath(vim.fn.fnamemodify(name,':h'))
 if dir and vim.fn.filereadable(dir..'/.learning/manifest.json')==1 then return dir end
end
local function key()
 return string.format('%08x-%04x-4%03x-8%03x-%012x',vim.fn.rand(),vim.fn.rand()%65536,vim.fn.rand()%4096,vim.fn.rand()%4096,vim.fn.rand())
end
local function halt(s,message)
 s.enabled=false;s.pending=false;s.token=nil;s.ack=nil
 if s.timer then s.timer:stop();s.timer:close();s.timer=nil end
 if message then vim.notify(message,vim.log.levels.WARN) end
end
local flush
local function schedule(s)
 if s.timer then s.timer:stop();s.timer:close() end
 local timer=vim.uv.new_timer();s.timer=timer;timer:start(1000,0,vim.schedule_wrap(function()
  if s.timer~=timer then return end
  timer:close();s.timer=nil
  if not s.enabled or not s.pending then return end
  if s.busy then return end
  flush(s,false)
 end))
end
flush=function(s,initialize)
 if s.busy then return end
 local config=require('codechuman').config
 if s.origin~=config.api_base_url or s.cli~=config.cli_path then halt(s,'Codechuman configuration changed; sync stopped');return end
 if not initialize and (not s.enabled or not s.ack) then return end
 s.pending=false;s.busy=true
 local input={token=s.token,idempotency_key=key(),initialize=initialize,expected_fence_epoch=not initialize and s.ack or nil}
 local ok,process=pcall(vim.system,{s.cli,'sync-saved','--api-base',s.origin,'--workspace',s.directory,'--request-stdin'},{text=true,stdin=vim.json.encode(input),timeout=35000},function(result)
  vim.schedule(function()
   s.busy=false;s.process=nil
   if states[s.directory]~=s or not s.token then return end
   if result.code~=0 then halt(s,'Codechuman sync stopped: connection, authorization or remote fence changed. Local code preserved; use manual SyncSaved after review.');return end
   local valid,r=pcall(vim.json.decode,result.stdout or '')
   if not valid or type(r)~='table' or r.schema~='codechuman.saved-sync.v1' or r.task_instance_id~=s.task or type(r.fence_epoch)~='number' or r.fence_epoch<1 or r.fence_epoch>9007199254740991 or r.fence_epoch%1~=0 or (s.ack and r.fence_epoch<s.ack) or type(r.main_digest)~='string' or not r.main_digest:match('^sha256:[a-f0-9]+$') or #r.main_digest~=71 then halt(s,'Invalid atomic sync ACK; automatic sync stopped');return end
   s.ack=r.fence_epoch
   if initialize then vim.notify('Saved main.go acknowledged by Sandbox. Auto sync remains OFF; use CodechumanAutoSyncEnable to opt in.') end
   if s.enabled and s.pending then schedule(s) end
  end)
 end)
 if ok then s.process=process else s.busy=false;halt(s,'Could not start Codechuman sync CLI') end
end
function M.manual()
 local dir=current();if not dir then vim.notify('Open the task main.go first',vim.log.levels.WARN);return end
 local old=states[dir];if old and old.busy then vim.notify('Wait for the current sync');return end
 if old then halt(old) end
 local stat=vim.uv.fs_lstat(dir..'/.learning/manifest.json');if not stat or stat.type~='file' or stat.size>16384 then return end
 local ok,manifest=pcall(function()return vim.json.decode(table.concat(vim.fn.readfile(dir..'/.learning/manifest.json'),'\n'))end)
 if not ok or type(manifest)~='table' or type(manifest.task_instance_id)~='string' then return end
 local token=vim.fn.inputsecret('Codechuman access token (memory only): ');if token=='' then return end
 local config=require('codechuman').config
 local s={directory=dir,task=manifest.task_instance_id,origin=config.api_base_url,cli=config.cli_path,token=token,enabled=false,busy=false,pending=false}
 states[dir]=s;flush(s,true)
end
function M.enable()
 local dir=current();local s=dir and states[dir]
 if not s or not s.ack or s.busy then vim.notify('Run CodechumanSyncSaved and wait for an atomic ACK first',vim.log.levels.WARN);return end
 s.enabled=true;vim.notify('Saved main.go auto sync enabled (1s debounce); remote drift stops it. Disable before Run/Teacher/Submit.')
end
function M.disable()
 for _,s in pairs(states)do halt(s);if s.process then s.process:kill(15) end end
 states={}
end
function M.blocks(directory)
 local canonical=directory and vim.uv.fs_realpath(directory);local s=states[canonical or directory];return s~=nil and (s.enabled or s.busy)
end
local group=vim.api.nvim_create_augroup('CodechumanSavedSync',{clear=true})
vim.api.nvim_create_autocmd('BufWritePost',{group=group,pattern='main.go',callback=function(event)
 local name=vim.api.nvim_buf_get_name(event.buf);local dir=vim.uv.fs_realpath(vim.fn.fnamemodify(name,':h'));local s=dir and states[dir]
 if not s or not s.enabled or vim.uv.fs_realpath(name)~=dir..'/main.go' then return end
 s.pending=true;schedule(s)
end})
vim.api.nvim_create_autocmd('VimLeavePre',{group=group,callback=M.disable})
return M
