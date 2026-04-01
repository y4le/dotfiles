local M = {}

M.dir = vim.fn.stdpath("state") .. "/sessions"

vim.fn.mkdir(M.dir, "p")

local function with_extension(name)
  if name:sub(-4) == ".vim" then
    return name
  end

  return name .. ".vim"
end

function M.default_name()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  if cwd == "" then
    return "session"
  end

  return cwd
end

function M.path(name)
  return M.dir .. "/" .. with_extension(name)
end

function M.save(name)
  vim.cmd(("mksession! %s"):format(vim.fn.fnameescape(M.path(name))))
end

function M.load(name)
  local path = M.path(name)
  if vim.uv.fs_stat(path) == nil then
    vim.notify(("session not found: %s"):format(name), vim.log.levels.ERROR)
    return
  end

  vim.cmd(("source %s"):format(vim.fn.fnameescape(path)))
end

function M.delete(name)
  local path = M.path(name)
  if vim.uv.fs_stat(path) == nil then
    vim.notify(("session not found: %s"):format(name), vim.log.levels.ERROR)
    return
  end

  vim.fn.delete(path)
end

function M.list()
  local sessions = {}
  local handle = vim.uv.fs_scandir(M.dir)
  if handle == nil then
    return sessions
  end

  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if name == nil then
      break
    end

    if entry_type == "file" and name:sub(-4) == ".vim" then
      table.insert(sessions, name:sub(1, -5))
    end
  end

  table.sort(sessions)
  return sessions
end

return M
