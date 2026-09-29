-- orgmode 1ab7b456 requires tree-sitter-org 2.0.2. Verify the tag's commit
-- before its C source is compiled or its parser is loaded into Neovim.
local grammar_tag = "2.0.2"
local grammar_commit = "43bae3ce47cef48b7744f363a7766a795faa3550"

local function git(args)
  local command = { "git" }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then
    error("orgmode grammar git command failed: " .. vim.trim(result.stderr or ""))
  end
  return vim.trim(result.stdout or "")
end

local function restore()
  local plugin = assert(require("lazy.core.config").plugins.orgmode, "orgmode was not restored")
  vim.opt.rtp:prepend(plugin.dir)
  local installer = require("orgmode.utils.treesitter.install")
  local info = installer.get_version_info()
  assert(info.required_version == grammar_tag, "orgmode grammar version changed; update the tag and commit pin")
  if not info.installed_in_orgmode_dir or info.version_mismatch then
    local source = vim.fn.tempname()
    local ok, err = xpcall(function()
      git({ "clone", "--filter=blob:none", "--depth=1", "--branch=" .. grammar_tag,
        "https://github.com/nvim-orgmode/tree-sitter-org", source })
      local actual = git({ "-C", source, "rev-parse", "HEAD" })
      assert(actual == grammar_commit, "orgmode grammar tag moved: " .. actual)
      local original_get_path = installer.get_path
      installer.get_path = function()
        return require("orgmode.utils.promise").resolve(source)
      end
      local installed, install_err = pcall(installer.run, "install")
      installer.get_path = original_get_path
      if not installed then
        error(install_err)
      end
    end, debug.traceback)
    vim.fn.delete(source, "rf")
    if not ok then
      error(err)
    end
  end

  info = installer.get_version_info()
  if not info.installed_in_orgmode_dir or info.version_mismatch then
    error("orgmode Treesitter parser was not restored under " .. plugin.dir)
  end
end

local ok, err = xpcall(restore, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
