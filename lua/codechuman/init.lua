local M = {}

M.config = {
  cli_path = "codechuman",
  workspace_root = vim.fn.expand("~/.codechuman"),
  width = 46,
  keymap = nil, -- User may opt in to e.g. <leader>B.
}

local panel = { window = nil, buffer = nil, previous_window = nil, entries = {}, rows = {} }

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
    "<Enter> code  l lesson  v syntax  t tests  r reload  q close",
    "",
  }
  local rows = {}
  if #panel.entries == 0 then
    table.insert(lines, "No local lessons yet.")
    table.insert(lines, "Use Codechuman CLI checkout to download one.")
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
  vim.system(argv, { text = true, timeout = 15000 }, function(result)
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

function M.lesson_selected()
  local entry = selected_entry()
  if not entry then
    return
  end
  local filename = entry.directory .. "/.learning/lesson.md"
  if vim.fn.filereadable(filename) ~= 1 then
    vim.notify("This lesson has not been cached locally", vim.log.levels.WARN)
    return
  end
  local ok, lines = pcall(vim.fn.readfile, filename)
  if ok then
    local output = { "Lesson", "────────────────────────────────────────", "Press b to return to the course list", "" }
    vim.list_extend(output, lines)
    render(output)
  end
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
