local M = {}

local sidebar_width = 30
local sidebar_var = "dotfiles_file_sidebar"

local function require_oil()
  local ok, oil = pcall(require, "oil")
  if ok then
    return oil
  end

  vim.notify("oil.nvim is not available", vim.log.levels.ERROR)
end

local function is_sidebar_window(win)
  local ok, value = pcall(vim.api.nvim_win_get_var, win, sidebar_var)
  return ok and value == true
end

local function find_sidebar_windows()
  local wins = {}

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_sidebar_window(win) then
      table.insert(wins, win)
    end
  end

  return wins
end

local function close_sidebar()
  local wins = find_sidebar_windows()

  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  return #wins > 0
end

local function current_root()
  if vim.bo.filetype == "oil" then
    local oil = require_oil()
    if oil then
      return oil.get_current_dir() or vim.fn.getcwd()
    end
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return vim.fn.getcwd()
  end

  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.isdirectory(path) == 1 then
    return path
  end

  return vim.fn.fnamemodify(path, ":h")
end

local function current_file_target()
  if vim.bo.filetype == "oil" or vim.bo.buftype ~= "" then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.fn.isdirectory(path) == 1 then
    return nil
  end

  return vim.fn.fnamemodify(path, ":t")
end

local function configure_sidebar_window()
  vim.w[sidebar_var] = true
  vim.wo.winfixwidth = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.api.nvim_win_set_width(0, sidebar_width)
end

local function focus_entry(name)
  if not name or name == "" then
    return
  end

  local oil = require_oil()
  if not oil then
    return
  end

  for lnum = 1, vim.api.nvim_buf_line_count(0) do
    local entry = oil.get_entry_on_line(0, lnum)
    if entry and entry.name == name then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      return
    end
  end

  vim.notify("could not locate current file in sidebar", vim.log.levels.WARN)
end

local function open_sidebar(root, target)
  local oil = require_oil()
  if not oil then
    return
  end

  vim.cmd("topleft vertical " .. sidebar_width .. "new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buflisted = false
  configure_sidebar_window()
  oil.open(root, nil, function()
    configure_sidebar_window()
    focus_entry(target)
  end)
end

local function is_target_window(win)
  if not vim.api.nvim_win_is_valid(win) or is_sidebar_window(win) then
    return false
  end

  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == ""
end

local function target_window(skip)
  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  if previous ~= 0 and previous ~= skip and is_target_window(previous) then
    return previous
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= skip and is_target_window(win) then
      return win
    end
  end
end

local function ensure_target_window(sidebar_win)
  local win = target_window(sidebar_win)
  if win then
    return win
  end

  vim.cmd("rightbelow vertical new")
  vim.bo.bufhidden = "wipe"
  vim.bo.buflisted = false
  win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(sidebar_win)
  return win
end

function M.opts()
  return {
    default_file_explorer = true,
    cleanup_delay_ms = false,
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["<CR>"] = {
        callback = M.select_entry,
        desc = "Open entry",
        mode = "n",
      },
      ["q"] = {
        callback = M.close,
        desc = "Close oil",
        mode = "n",
      },
    },
  }
end

function M.toggle_sidebar()
  if close_sidebar() then
    return
  end

  open_sidebar(current_root())
end

function M.reveal_in_sidebar()
  local root = current_root()
  local target = current_file_target()

  close_sidebar()
  open_sidebar(root, target)
end

function M.select_entry()
  local oil = require_oil()
  if not oil then
    return
  end

  if not vim.w[sidebar_var] then
    oil.select()
    return
  end

  local entry = oil.get_cursor_entry()
  if entry and entry.type == "directory" then
    oil.select()
    return
  end

  local sidebar_win = vim.api.nvim_get_current_win()
  local win = ensure_target_window(sidebar_win)
  oil.select({
    handle_buffer_callback = function(bufnr)
      if not vim.api.nvim_win_is_valid(win) then
        win = ensure_target_window(sidebar_win)
      end

      vim.api.nvim_win_set_buf(win, bufnr)
      vim.api.nvim_set_current_win(win)
    end,
  })
end

function M.close()
  if vim.w[sidebar_var] then
    vim.api.nvim_win_close(0, true)
    return
  end

  local oil = require_oil()
  if oil then
    oil.close({ exit_if_last_buf = true })
  end
end

return M
