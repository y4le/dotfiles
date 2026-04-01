local M = {}

local function notify_failure(action, result)
  local stderr = result and result.stderr or ""
  local message = stderr ~= "" and stderr:gsub("%s+$", "") or "command failed"
  vim.notify(("clipboard %s failed: %s"):format(action, message), vim.log.levels.ERROR)
end

local function run_command(args, opts)
  local result = vim.system(args, opts or {}):wait()
  if result.code ~= 0 then
    return nil, result
  end

  return result
end

local function copy_text(text)
  local _, result = run_command({ "cpy" }, { stdin = text })
  if result then
    notify_failure("copy", result)
    return false
  end

  return true
end

local function paste_text()
  local result, err = run_command({ "pst" })
  if err then
    notify_failure("paste", err)
    return nil
  end

  return (result.stdout or ""):gsub("\n$", "")
end

local function normalize_kind(kind)
  if kind == "v" or kind == "char" then
    return "char"
  end

  if kind == "V" or kind == "line" then
    return "line"
  end

  if kind == "\22" or kind == "block" then
    return "block"
  end

  return "char"
end

local function get_range(start_mark, end_mark, kind)
  local start_pos = vim.api.nvim_buf_get_mark(0, start_mark)
  local end_pos = vim.api.nvim_buf_get_mark(0, end_mark)
  local start_row = start_pos[1] - 1
  local start_col = start_pos[2]
  local end_row = end_pos[1] - 1
  local end_col = end_pos[2]

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  return {
    kind = normalize_kind(kind),
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

local function split_lines(text)
  return vim.split(text, "\n", { plain = true })
end

local function get_text(range)
  if range.kind == "line" then
    return table.concat(vim.api.nvim_buf_get_lines(0, range.start_row, range.end_row + 1, false), "\n")
  end

  if range.kind == "block" then
    local lines = vim.api.nvim_buf_get_lines(0, range.start_row, range.end_row + 1, false)
    local left = math.min(range.start_col, range.end_col)
    local right = math.max(range.start_col, range.end_col)
    for index, line in ipairs(lines) do
      lines[index] = line:sub(left + 1, right + 1)
    end
    return table.concat(lines, "\n")
  end

  return table.concat(
    vim.api.nvim_buf_get_text(0, range.start_row, range.start_col, range.end_row, range.end_col + 1, {}),
    "\n"
  )
end

local function replace_text(range, replacement)
  if range.kind == "line" then
    vim.api.nvim_buf_set_lines(0, range.start_row, range.end_row + 1, false, split_lines(replacement))
    return
  end

  if range.kind == "block" then
    vim.notify("blockwise clipboard replace is not supported yet", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_buf_set_text(
    0,
    range.start_row,
    range.start_col,
    range.end_row,
    range.end_col + 1,
    split_lines(replacement)
  )
end

function M.copy_operator(kind)
  local range = get_range("[", "]", kind)
  copy_text(get_text(range))
end

function M.copy_visual(kind)
  local range = get_range("<", ">", kind or vim.fn.visualmode())
  copy_text(get_text(range))
end

function M.paste_operator(kind)
  local replacement = paste_text()
  if replacement == nil then
    return
  end

  local range = get_range("[", "]", kind)
  replace_text(range, replacement)
end

function M.paste_visual(kind)
  local replacement = paste_text()
  if replacement == nil then
    return
  end

  local range = get_range("<", ">", kind or vim.fn.visualmode())
  replace_text(range, replacement)
end

function M.copy_motion()
  vim.go.operatorfunc = "v:lua.require'config.clipboard'.copy_operator"
  return "g@"
end

function M.paste_motion()
  vim.go.operatorfunc = "v:lua.require'config.clipboard'.paste_operator"
  return "g@"
end

return M
