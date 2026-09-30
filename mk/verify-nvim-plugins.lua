local function verify()
  local snapshot = assert(vim.env.DOTFILES_NVIM_LOCK_SNAPSHOT, "lock snapshot is required")
  local lock = vim.json.decode(table.concat(vim.fn.readfile(snapshot), "\n"))
  local config = require("lazy.core.config")
  local git = require("lazy.manage.git")
  local failed = false

  for name, plugin in pairs(config.plugins) do
    local ignored = config.spec.disabled[name] or config.spec.ignore_installed[name]
    if not plugin._.is_local and not ignored then
      local expected = lock[name] and lock[name].commit
      local info = git.info(plugin.dir)
      local actual = info and info.commit
      if not expected or actual ~= expected then
        io.stderr:write(
          ("Neovim plugin %s mismatch: expected %s, got %s"):format(
            name,
            expected or "missing lock entry",
            actual or "missing"
          ) .. "\n"
        )
        failed = true
      end
    end
  end

  return not failed
end

local ok, verified = xpcall(verify, debug.traceback)
if not ok then
  io.stderr:write(verified .. "\n")
end
if not ok or not verified then
  vim.cmd("cquit 1")
end
