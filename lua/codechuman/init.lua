local M = {}

M.config = {
  cli_path = "codechuman",
  workspace_root = vim.fn.expand("~/.codechuman"),
  api_base_url = "", -- User-configured HTTPS Gateway origin; never loaded from a project.
  width = 46,
  keymap = nil, -- User may opt in to e.g. <leader>B.
}

local panel = { window = nil, buffer = nil, previous_window = nil, entries = {}, rows = {} }
local checkout_busy = false

local function is_open()
  return panel.window ~= nil and vim.api.nvim_win_is_valid(panel.window)
end

local function render(lines, row_links)
  if not is_open() or not vim.api.nvim_buf_is_valid(panel.buffer) then
    return
  end
  panel.rows = row_links or {}
  vim.bo[panel.buffer].modifiable = true
  vim.api.nvim_buf_set_lines(panel.buffer, 0, -1, false, lines)
  vim.bo[panel.buffer].modifiable = false
end

local function render_entries()
  local lines = {
    "Codechuman",
    "────────────────────────────────────────",
    "<Enter> code  l lesson  a task  z quiz  e examples",
    "v syntax  t public tests  r reload  b back  q close",
    "",
  }
  local rows = {}
  if #panel.entries == 0 then
    table.insert(lines, "No local lessons yet.")
    table.insert(lines, "Use :CodechumanCheckout <TaskInstance UUID> to download one.")
  else
    for _, entry in ipairs(panel.entries) do
      local manifest = entry.manifest
      if type(manifest) == "table" and type(entry.directory) == "string" then
        local label = string.format("%s / %02d", tostring(manifest.course_slug or "Course"), tonumber(manifest.lesson_number) or 0)
        table.insert(lines, label)
        rows[#lines] = entry
      end
    end
  end
  table.insert(lines, "")
  table.insert(lines, "Local tests never award Mastery.")
  render(lines, rows)
end

local function selected_entry()
  if not is_open() then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(panel.window)[1]
  return panel.rows[row]
end

local function run_cli(args, callback)
  if vim.fn.executable(M.config.cli_path) ~= 1 then
    callback(nil, "codechuman-cli was not found; install it from GitHub Releases")
    return
  end
  local argv = { M.config.cli_path }
  vim.list_extend(argv, args)
  vim.system(argv, { text = true, timeout = 30000 }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "Codechuman CLI command failed")
        return
      end
      local ok, output = pcall(vim.json.decode, result.stdout or "")
      if ok then
        callback(output, nil)
      else
        callback(nil, "Invalid JSON reply from Codechuman CLI")
      end
    end)
  end)
end

local function canonical_uuid(value)
  return type(value) == "string" and #value == 36
    and value:match("^[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+%-[0-9a-f]+$") ~= nil
    and value:sub(9, 9) == "-" and value:sub(14, 14) == "-"
    and value:sub(19, 19) == "-" and value:sub(24, 24) == "-"
end

-- Preview bridge to the authenticated CLI path. No token is saved or passed
-- via argv, environment variables, shell commands or Neovim history.
-- Native sign-in/refresh remains a separate future owner-approved slice.
function M.checkout_remote(task_instance_id)
  if not canonical_uuid(task_instance_id) then
    vim.notify("Expected a canonical lowercase TaskInstance UUID", vim.log.levels.WARN)
    return
  end
  if checkout_busy then
    vim.notify("A Codechuman checkout is already running", vim.log.levels.WARN)
    return
  end
  if type(M.config.api_base_url) ~= "string" or not M.config.api_base_url:match("^https://") then
    vim.notify("Configure api_base_url with the Codechuman HTTPS Gateway origin", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable(M.config.cli_path) ~= 1 then
    vim.notify("Install codechuman-cli and configure cli_path", vim.log.levels.WARN)
    return
  end

  local token = vim.fn.inputsecret("Codechuman access token (not saved): ")
  if type(token) ~= "string" or token == "" then
    return
  end
  if #token > 8192 or token:find("[%s%z]") then
    token = nil
    vim.notify("Invalid access token format", vim.log.levels.WARN)
    return
  end

  local argv = {
    M.config.cli_path, "checkout-remote",
    "--api-base", M.config.api_base_url,
    "--task-instance", task_instance_id,
    "--root", M.config.workspace_root,
    "--token-stdin",
  }
  checkout_busy = true
  local started, process = pcall(vim.system, argv, { text = true, stdin = true, timeout = 150000 }, function(result)
    vim.schedule(function()
      checkout_busy = false
      if result.code ~= 0 then
        -- Do not forward subprocess stderr; it could contain credential material.
        vim.notify("Codechuman checkout failed (exit " .. tostring(result.code) .. ")", vim.log.levels.ERROR)
        return
      end
      local valid, reply = pcall(vim.json.decode, result.stdout or "")
      if not valid or type(reply) ~= "table" or type(reply.directory) ~= "string" then
        vim.notify("Codechuman CLI returned an invalid checkout result", vim.log.levels.ERROR)
        return
      end
      vim.notify("Codechuman checkout ready: " .. reply.directory, vim.log.levels.INFO)
      M.refresh()
    end)
  end)
  if not started then
    token = nil
    checkout_busy = false
    vim.notify("Could not start Codechuman CLI", vim.log.levels.ERROR)
    return
  end

  local written = pcall(function()
    process:write(token)
    process:write(nil)
  end)
  token = nil
  if not written then
    process:kill("sigterm")
    checkout_busy = false
    vim.notify("Could not pass token securely to Codechuman CLI", vim.log.levels.ERROR)
  end
end

function M.refresh()
  if not is_open() then
    return
  end
  render({ "Codechuman", "", "Loading local courses..." })
  run_cli({ "list", "--root", M.config.workspace_root }, function(entries, err)
    if err then
      render({ "Codechuman", "", err, "", "Press r to retry" })
      return
    end
    panel.entries = type(entries) == "table" and entries or {}
    render_entries()
  end)
end

function M.close()
  if is_open() then
    vim.api.nvim_win_close(panel.window, true)
  end
  panel.window, panel.buffer, panel.previous_window = nil, nil, nil
end

function M.edit_selected()
  local entry = selected_entry()
  if not entry then
    return
  end
  local filename = entry.directory .. "/app.js"
  if vim.fn.filereadable(filename) ~= 1 then
    vim.notify("Default app.js was not found in this checkout", vim.log.levels.WARN)
    return
  end
  if panel.previous_window and vim.api.nvim_win_is_valid(panel.previous_window) then
    vim.api.nvim_set_current_win(panel.previous_window)
  else
    vim.cmd("wincmd p")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(filename))
end

local function show_cached_material(material, heading)
  local entry = selected_entry()
  if not entry then
    return
  end
  local filename = entry.directory .. "/.learning/" .. material
  local stat = vim.uv.fs_lstat(filename)
  if not stat or stat.type ~= "file" or stat.size > 512 * 1024 then
    vim.notify("This material is missing, unsafe or too large", vim.log.levels.WARN)
    return
  end
  local ok, lines = pcall(vim.fn.readfile, filename)
  if ok then
    local output = { heading, "────────────────────────────────────────", "Press b to return to the course list", "" }
    vim.list_extend(output, lines)
    render(output)
  end
end

function M.lesson_selected()
  show_cached_material("lesson.md", "Lesson")
end

function M.task_selected()
  show_cached_material("task.md", "Task")
end

function M.quiz_selected()
  show_cached_material("quiz.json", "Quiz (saved JSON, read-only)")
end

function M.examples_selected()
  local entry = selected_entry()
  if not entry then
    return
  end
  local example_root = entry.directory .. "/.learning/examples"
  local files = {}
  local function scan(dir, prefix, depth)
    if depth > 5 or #files >= 100 then
      return
    end
    local iterator = vim.uv.fs_scandir(dir)
    if not iterator then
      return
    end
    while true do
      local name, kind = vim.uv.fs_scandir_next(iterator)
      if not name then
        break
      end
      if name:match("^[a-zA-Z0-9][a-zA-Z0-9._-]*$") and name ~= "." and name ~= ".." then
        local filename = dir .. "/" .. name
        if kind == "directory" then
          scan(filename, prefix .. name .. "/", depth + 1)
        elseif kind == "file" then
          local stat = vim.uv.fs_lstat(filename)
          if stat and stat.type == "file" and stat.size <= 512 * 1024 then
            table.insert(files, { filename = filename, label = prefix .. name })
          end
        end
      end
      if #files >= 100 then
        break
      end
    end
  end
  scan(example_root, "", 1)
  table.sort(files, function(left, right)
    return left.label < right.label
  end)
  local lines = { "Examples", "────────────────────────────────────────", "Press b to return to the course list", "" }
  if #files == 0 then
    table.insert(lines, "No cached examples for this lesson.")
  end
  for _, file in ipairs(files) do
    table.insert(lines, "▶ " .. file.label)
    local ok, content = pcall(vim.fn.readfile, file.filename, "", 80)
    if ok then
      vim.list_extend(lines, content)
    else
      table.insert(lines, "[cannot read example]")
    end
    table.insert(lines, "")
    if #lines >= 1000 then
      table.insert(lines, "[remaining examples truncated]")
      break
    end
  end
  render(lines)
end

local function validate_selected(command, title)
  local entry = selected_entry()
  if not entry then
    return
  end
  render({ "Codechuman", "", "Running " .. title .. "..." })
  local args = { command, "--workspace", entry.directory }
  if command == "validate-js" then
    vim.list_extend(args, { "--file", "app.js" })
  end
  run_cli(args, function(result, err)
    if err then
      render({ "Codechuman", "", err, "", "Press b to return" })
      return
    end
    local lines = { "Codechuman · Local validation", "────────────────────────────────────────", "Status: " .. tostring(result.status), "" }
    if result.details and result.details ~= "" then
      vim.list_extend(lines, vim.split(result.details, "\n", { plain = true }))
    end
    table.insert(lines, "")
    table.insert(lines, "Local PASS does not grant official Mastery.")
    table.insert(lines, "Press b to return")
    render(lines)
  end)
end

function M.validate_selected()
  validate_selected("validate-js", "JavaScript syntax check")
end

function M.public_tests_selected()
  validate_selected("validate-public-js", "public tests")
end

function M.open()
  if is_open() then
    vim.api.nvim_set_current_win(panel.window)
    return
  end
  panel.previous_window = vim.api.nvim_get_current_win()
  vim.cmd("botright vnew")
  panel.window = vim.api.nvim_get_current_win()
  panel.buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_width(panel.window, M.config.width)
  vim.bo[panel.buffer].buftype = "nofile"
  vim.bo[panel.buffer].bufhidden = "wipe"
  vim.bo[panel.buffer].swapfile = false
  vim.bo[panel.buffer].filetype = "codechuman"
  vim.bo[panel.buffer].modifiable = false
  local keys = {
    q = M.close,
    r = M.refresh,
    b = render_entries,
    l = M.lesson_selected,
    a = M.task_selected,
    z = M.quiz_selected,
    e = M.examples_selected,
    v = M.validate_selected,
    t = M.public_tests_selected,
    ["<CR>"] = M.edit_selected,
  }
  for key, fn in pairs(keys) do
    vim.keymap.set("n", key, fn, { buffer = panel.buffer, silent = true, nowait = true })
  end
  M.refresh()
end

function M.setup(options)
  M.config = vim.tbl_deep_extend("force", M.config, options or {})
  M.config.workspace_root = vim.fn.expand(M.config.workspace_root)
  if M.config.keymap then
    vim.keymap.set("n", M.config.keymap, M.open, { desc = "Codechuman", silent = true })
  end
end

return M
