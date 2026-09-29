local function verify()
  local name = assert(vim.env.DOTFILES_TEST_FILE)
  local filetype = assert(vim.env.DOTFILES_TEST_FILETYPE)
  assert(vim.api.nvim_buf_get_name(0) == name, "named file was not opened")
  assert(vim.bo.filetype == filetype, "wrong filetype for named file")

  local plugins = require("lazy.core.config").plugins
  for _, plugin in ipairs({ "nvim-lspconfig", "gitsigns.nvim", "nvim-lint" }) do
    assert(plugins[plugin] and plugins[plugin]._.loaded, plugin .. " did not load for the named file")
  end

  if filetype == "lua" then
    vim.api.nvim_exec_autocmds("InsertEnter", { buffer = 0 })
    assert(plugins["blink.cmp"] and plugins["blink.cmp"]._.loaded, "blink.cmp did not load")
    assert(require("blink.cmp.config").fuzzy.implementation == "lua", "blink.cmp may download a binary")
  elseif filetype == "org" then
    assert(plugins.orgmode and plugins.orgmode._.loaded, "orgmode did not load")
    local info = require("orgmode.utils.treesitter.install").get_version_info()
    assert(info.installed_in_orgmode_dir and not info.version_mismatch, "orgmode parser is missing")
  elseif filetype == "markdown" then
    require("conform").format({ async = false, timeout_ms = 5000 })
    local args = vim.fn.readfile(assert(vim.env.DOTFILES_TEST_FORMATTER_LOG))
    local explicit_parser = false
    local filepath = false
    for index, argument in ipairs(args) do
      if argument == "--parser" and args[index + 1] == "markdown" then explicit_parser = true end
      if argument == "--stdin-filepath" and args[index + 1] == name then filepath = true end
    end
    local extension = vim.fn.fnamemodify(name, ":e")
    assert(explicit_parser == (extension == "wiki" or extension == "book"), "wrong Markdown parser arguments")
    assert(filepath, "Markdown formatting lost its file path")
  end

  assert(vim.v.errmsg == "", "Neovim startup error: " .. vim.v.errmsg)
end

local ok, err = xpcall(verify, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
