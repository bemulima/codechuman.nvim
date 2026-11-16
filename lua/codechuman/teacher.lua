-- Dialog is the sole transcript owner. Token lives only in this UI session.
local M = {}
local session
local function workspace()
  local path=vim.api.nvim_buf_get_name(0)
  local dir=vim.fn.fnamemodify(path~='' and path or vim.fn.getcwd(),':p:h')
  for _=1,20 do
    if vim.fn.filereadable(dir..'/.learning/manifest.json')==1 then return dir end
    local parent=vim.fn.fnamemodify(dir,':h');if parent==dir then break end;dir=parent
  end
end
local function draw(s,reply)
 if session~=s or not vim.api.nvim_buf_is_valid(s.buffer) then return end
 local lines={'Codechuman Teacher — current TaskInstance',s.config.teacher_checks_enabled and 's ask  t run/check  r refresh  q close' or 's ask  r refresh  q close',s.config.teacher_sync_main and 'Context: saved main.go via Sandbox; use :write before asking.' or 'Context: server-owned task/step; local code is not synced.',''}
 if s.check then
   local c=s.check
   table.insert(lines,'Sandbox check: '..c.outcome..(c.stale and ' (STALE — save and check again)' or ''))
   table.insert(lines,'Advisory public checks; official progress is unchanged.')
   for _,issue in ipairs(c.issues) do table.insert(lines,'  '..issue.code) end
   table.insert(lines,'')
 end
 for _,message in ipairs(reply.messages or {}) do
   table.insert(lines,message.author_type=='personal_teacher' and 'Teacher:' or 'You:')
   for line in (tostring(message.body or '')..'\n'):gmatch('(.-)\n') do
     -- Plain buffer text only: never execute server text, escape/control sequences.
     table.insert(lines,(line:gsub('[%z\1-\8\11-\31\127]','')))
   end
   table.insert(lines,'')
 end
 if reply.pending then table.insert(lines,'Reply pending; press r to refresh. Do not resend the question.') end
 vim.bo[s.buffer].modifiable=true;vim.api.nvim_buf_set_lines(s.buffer,0,-1,false,lines);vim.bo[s.buffer].modifiable=false
end
local function request(s,body,key)
 if session~=s or s.busy then return end
 s.busy=true
 local argv={s.config.cli_path,'teacher-chat','--api-base',s.config.api_base_url,'--workspace',s.workspace,'--request-stdin'}
 local ok,process=pcall(vim.system,argv,{text=true,stdin=vim.json.encode({token=s.token,body=body or '',idempotency_key=key or '',sync_main=s.config.teacher_sync_main==true}),timeout=115000},function(result)
  vim.schedule(function()
   s.busy=false
   if session~=s or not vim.api.nvim_buf_is_valid(s.buffer) then return end
   if result.code~=0 then vim.notify('Teacher request failed (exit '..tostring(result.code)..'); refresh or sign in again.',vim.log.levels.ERROR);return end
   local valid,reply=pcall(vim.json.decode,result.stdout or '')
   if not valid or type(reply)~='table' or type(reply.messages)~='table' then vim.notify('Invalid Teacher response',vim.log.levels.ERROR);return end
   s.last=reply;draw(s,reply)
  end)
 end)
 if not ok then s.busy=false;vim.notify('Could not start Teacher CLI',vim.log.levels.ERROR) else s.process=process end
end
function M.check()
 local s=session
 if not s then
   M.open();s=session
   if not s then return end
   if not vim.wait(3000,function()return session~=s or not s.busy end,20) or session~=s then return end
 end
 if not s.config.teacher_checks_enabled then vim.notify('Sandbox checks are not enabled in trusted configuration',vim.log.levels.WARN);return end
 if s.busy then vim.notify('Wait for the current Teacher or Sandbox request');return end
 s.busy=true
 vim.notify('Checking saved main.go in Sandbox...')
 local argv={s.config.cli_path,'check-solution','--api-base',s.config.api_base_url,'--workspace',s.workspace,'--request-stdin'}
 local ok,process=pcall(vim.system,argv,{text=true,stdin=vim.json.encode({token=s.token}),timeout=135000},function(result)
  vim.schedule(function()
   s.busy=false
   if session~=s or not vim.api.nvim_buf_is_valid(s.buffer) then return end
   if result.code~=0 then vim.notify('Sandbox check unavailable (exit '..tostring(result.code)..'); no learner verdict.',vim.log.levels.ERROR);return end
   local valid,c=pcall(vim.json.decode,result.stdout or '')
   local outcomes={PASS=true,FAIL=true,ERROR=true,RUNNING=true}
   if not valid or type(c)~='table' or not outcomes[c.outcome] or c.advisory~=true or type(c.stale)~='boolean' or type(c.issues)~='table' or #c.issues>7 then vim.notify('Invalid Sandbox check response',vim.log.levels.ERROR);return end
   for _,issue in ipairs(c.issues) do
    if type(issue)~='table' or type(issue.code)~='string' or #issue.code>128 or not issue.code:match('^[A-Z][A-Z0-9_]*$') then vim.notify('Invalid Sandbox issue',vim.log.levels.ERROR);return end
   end
   s.check=c;draw(s,s.last or {messages={}})
   vim.notify('Sandbox: '..c.outcome..(c.stale and ' (stale)' or '')..'. Press s to ask Teacher.')
  end)
 end)
 if not ok then s.busy=false;vim.notify('Could not start Sandbox CLI',vim.log.levels.ERROR) else s.process=process end
end
function M.ask(body)
 local s=session;if not s then return end
 if s.busy then vim.notify('Teacher is processing the previous request');return end
 local function send(text)
  if type(text)~='string' or text:match('^%s*$') then return end
  if #text>12000 then vim.notify('Message too long',vim.log.levels.WARN);return end
  request(s,text,vim.fn.exists('*rand')==1 and string.format('%08x-%04x-4%03x-8%03x-%012x',vim.fn.rand(),vim.fn.rand()%65536,vim.fn.rand()%4096,vim.fn.rand()%4096,vim.fn.rand()) or '')
 end
 if body then send(body) else vim.ui.input({prompt='Ask Teacher: '},send) end
end
function M.open()
 if session and vim.api.nvim_win_is_valid(session.window) then vim.api.nvim_set_current_win(session.window);return end
 local root=workspace();if not root then vim.notify('Open a Codechuman task file first',vim.log.levels.WARN);return end
 local config=require('codechuman').config
 if type(config.api_base_url)~='string' or not config.api_base_url:match('^https://') or vim.fn.executable(config.cli_path)~=1 then vim.notify('Configure trusted Gateway and CLI first',vim.log.levels.ERROR);return end
 local token=vim.fn.inputsecret('Codechuman Student token (session only): ')
 if type(token)~='string' or token=='' or #token>8192 or token:find('[%s%z]') then return end
 vim.cmd('botright vnew');local s={token=token,config=config,workspace=root,window=vim.api.nvim_get_current_win(),buffer=vim.api.nvim_get_current_buf()};session=s
 vim.bo[s.buffer].buftype='nofile';vim.bo[s.buffer].bufhidden='wipe';vim.bo[s.buffer].swapfile=false;vim.bo[s.buffer].filetype='codechuman-teacher';vim.bo[s.buffer].modifiable=false
 vim.api.nvim_create_autocmd('BufWipeout',{buffer=s.buffer,once=true,callback=function()s.token=nil;if s.process then pcall(s.process.kill,s.process,15) end;if session==s then session=nil end end})
 vim.keymap.set('n','s',function()M.ask()end,{buffer=s.buffer})
 vim.keymap.set('n','t',function()M.check()end,{buffer=s.buffer})
 vim.keymap.set('n','r',function()request(s)end,{buffer=s.buffer})
 vim.keymap.set('n','q',function()vim.api.nvim_buf_delete(s.buffer,{force=true})end,{buffer=s.buffer})
 draw(s,{messages={}});request(s)
end
return M
