local M = {}

M.dir = vim.fn.stdpath("state") .. "/sessions"

vim.fn.mkdir(M.dir, "p", 448)

local function with_extension(name)
  if name:sub(-4) == ".vim" then
    return name
  end

  return name .. ".vim"
end

function M.default_name()
  local cwd = vim.fn.getcwd()
  local basename = vim.fn.fnamemodify(cwd, ":t")
  if basename == "" then
    basename = "session"
  end
  return basename .. "-" .. vim.fn.sha256(cwd):sub(1, 10)
end

function M.path(name)
  local stem = name:gsub("%.vim$", "")
  assert(stem ~= "" and stem ~= "." and stem ~= ".."
    and not name:find("/", 1, true) and not name:find("\\", 1, true),
    "session name must be a filename without directory separators")
  return M.dir .. "/" .. with_extension(name)
end

function M.save(name, options)
  local path = M.path(name)
  local previous = vim.o.sessionoptions
  if options then
    vim.opt.sessionoptions = options
  end
  local ok, err = pcall(vim.cmd, ("mksession! %s"):format(vim.fn.fnameescape(path)))
  vim.o.sessionoptions = previous
  if not ok then
    error(err)
  end
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

function M.complete(lead)
  return vim.tbl_filter(function(name)
    return name:sub(1, #lead) == lead
  end, M.list())
end

return M
