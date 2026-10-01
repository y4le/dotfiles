local function check()
  local repo = assert(vim.env.DOTFILES_REPO)
  vim.opt.rtp:prepend(repo .. "/nvim/.config/nvim")
  vim.g.mapleader = " "
  require("config.options")
  assert(not vim.o.swapfile, "Neovim enabled swap files")
  assert(vim.fn.isdirectory(vim.fn.stdpath("state") .. "/swap") == 0, "Neovim created unused swap state")
  require("config.keymaps")
  require("config.autocmds")
  require("config.commands")

  local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), "xt", false)
  end

  vim.opt.wrap = true
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { string.rep("wrapped ", 100), "two", "three", "four", "five", "six" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  keys("j")
  assert(vim.fn.line(".") == 1, "plain j stopped following display lines")
  keys("k")
  assert(vim.fn.col(".") == 1, "plain k stopped following display lines")
  keys("5j")
  assert(vim.fn.line(".") == 6, "counted j followed display lines")
  keys("5k")
  assert(vim.fn.line(".") == 1, "counted k followed display lines")

  local formatted
  package.loaded.conform = { format = function(options) formatted = options end }
  assert(vim.fn.maparg("<Space>lf", "n", false, true).buffer == 0, "format mapping is not global")
  assert(vim.fn.maparg("<Space>e", "n", false, true).buffer == 0, "diagnostics mapping is not global")
  keys("<Space>lf")
  assert(formatted and formatted.lsp_format == "fallback", "format mapping bypassed conform")
  package.loaded.conform = nil
  local lsp_format = vim.lsp.buf.format
  local fallback = false
  vim.lsp.buf.format = function() fallback = true end
  keys("<Space>lf")
  vim.lsp.buf.format = lsp_format
  assert(fallback, "missing conform did not use LSP formatting")

  local file = vim.fn.stdpath("cache") .. "/trim.lua"
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  vim.api.nvim_buf_set_name(0, file)
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x = 1   " })
  vim.fn.setreg("/", "keep-this-search")
  vim.fn.histadd("search", "keep-this-search")
  local history = vim.fn.histnr("search")
  assert(history > 0, "search-history fixture is empty")
  vim.cmd.write()
  assert(vim.api.nvim_get_current_line() == "local x = 1", "save did not trim whitespace")
  assert(vim.fn.getreg("/") == "keep-this-search", "save replaced the search pattern")
  assert(vim.fn.histnr("search") == history, "save added to search history")

  local sessions = require("config.sessions")
  local previous = vim.o.sessionoptions
  vim.g.SessionFixture = 7
  vim.cmd("SessionSaveMin minimal")
  assert(vim.o.sessionoptions == previous, "minimal save changed sessionoptions")
  vim.cmd("SessionSaveMax maximal")
  assert(vim.o.sessionoptions == previous, "maximal save changed sessionoptions")
  local minimum = table.concat(vim.fn.readfile(sessions.path("minimal")), "\n")
  local maximum = table.concat(vim.fn.readfile(sessions.path("maximal")), "\n")
  assert(not minimum:find("SessionFixture", 1, true), "minimal save included globals")
  assert(maximum:find("SessionFixture", 1, true), "maximal save omitted globals")
  for _, command in ipairs({ "SessionSave", "SessionLoad", "SessionDelete", "SessionSaveMin", "SessionSaveMax" }) do
    local completions = vim.fn.getcompletion(command .. " ma", "cmdline")
    assert(vim.deep_equal(completions, { "maximal" }), command .. " did not complete session names")
  end
  local outside = vim.fn.fnamemodify(sessions.dir, ":h") .. "/outside.vim"
  vim.fn.writefile({ "keep" }, outside)
  for _, action in ipairs({ sessions.save, sessions.load, sessions.delete }) do
    for _, name in ipairs({ "../outside", "nested/name", "nested\\name", ".vim", ".." }) do
      assert(not pcall(action, name), "session command accepted " .. name)
    end
  end
  assert(vim.fn.readfile(outside)[1] == "keep", "session command changed a file outside its directory")
  local original_dir = sessions.dir
  sessions.dir = original_dir .. "/missing"
  assert(not pcall(sessions.save, "fail", { "buffers" }), "save succeeded without its directory")
  sessions.dir = original_dir
  assert(vim.o.sessionoptions == previous, "failed save changed sessionoptions")
  vim.cmd("SessionDelete minimal")
  assert(vim.fn.filereadable(sessions.path("minimal")) == 0, "session delete did not remove a session")
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
