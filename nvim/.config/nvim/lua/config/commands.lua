local sessions_dir = vim.fn.stdpath("state") .. "/sessions"

local function session_path(name)
  return sessions_dir .. "/" .. name .. ".vim"
end

local function default_session_name()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  if cwd == "" then
    return "session"
  end

  return cwd
end

local function save_session(name)
  vim.cmd(("mksession! %s"):format(vim.fn.fnameescape(session_path(name))))
end

local function load_session(name)
  local path = session_path(name)
  if vim.uv.fs_stat(path) == nil then
    vim.notify(("session not found: %s"):format(name), vim.log.levels.ERROR)
    return
  end

  vim.cmd(("source %s"):format(vim.fn.fnameescape(path)))
end

local function delete_session(name)
  local path = session_path(name)
  if vim.uv.fs_stat(path) == nil then
    vim.notify(("session not found: %s"):format(name), vim.log.levels.ERROR)
    return
  end

  vim.fn.delete(path)
end

vim.api.nvim_create_user_command("SessionSave", function(opts)
  save_session(opts.args ~= "" and opts.args or default_session_name())
end, {
  nargs = "?",
  complete = "dir",
  desc = "Save the current session",
})

vim.api.nvim_create_user_command("SessionLoad", function(opts)
  load_session(opts.args ~= "" and opts.args or default_session_name())
end, {
  nargs = "?",
  desc = "Load a saved session",
})

vim.api.nvim_create_user_command("SessionDelete", function(opts)
  delete_session(opts.args ~= "" and opts.args or default_session_name())
end, {
  nargs = "?",
  desc = "Delete a saved session",
})

vim.api.nvim_create_user_command("SessionSaveMin", function()
  vim.opt.sessionoptions = { "buffers", "tabpages" }
end, {
  desc = "Save minimal session state",
})

vim.api.nvim_create_user_command("SessionSaveMax", function()
  vim.opt.sessionoptions = {
    "blank",
    "buffers",
    "curdir",
    "folds",
    "globals",
    "help",
    "options",
    "tabpages",
    "winsize",
  }
end, {
  desc = "Save maximal session state",
})
