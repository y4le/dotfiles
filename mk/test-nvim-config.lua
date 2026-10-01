local repo = os.getenv("DOTFILES_REPO")
vim.opt.rtp:prepend(repo .. "/nvim/.config/nvim")
vim.g.mapleader = " "

local sessions = require("config.sessions")
local original = vim.fn.getcwd()
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/one/app", "p")
vim.fn.mkdir(root .. "/two/app", "p")
root = assert(vim.uv.fs_realpath(root))
vim.fn.chdir(root .. "/one/app")
local first = sessions.default_name()
vim.fn.chdir(root .. "/two/app")
local second = sessions.default_name()
vim.fn.chdir(original)
vim.fn.delete(root, "rf")
assert(first ~= second, "same-basename checkouts share a session name")
assert(first:match("^app%-") and second:match("^app%-"), "session name lost basename")

dofile(repo .. "/nvim/.config/nvim/lua/config/keymaps.lua")
vim.fn.setqflist({})
vim.v.errmsg = ""
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space>qq", true, false, true), "xt", false)
assert(vim.fn.getqflist({ winid = 0 }).winid ~= 0, "quickfix toggle did not open")
assert(vim.v.errmsg == "", "opening an empty quickfix list raised " .. vim.v.errmsg)

local target = vim.fn.tempname()
vim.fn.writefile({ "match" }, target)
target = assert(vim.uv.fs_realpath(target))
vim.fn.setqflist({}, "r", { items = { { filename = target, lnum = 1, text = "match" } } })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space>qq", true, false, true), "xt", false)
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space>qq", true, false, true), "xt", false)
assert(vim.fn.expand("%:p") == target, "nonempty quickfix did not jump to its current entry")
vim.fn.delete(target)

local lint_spec
for _, spec in ipairs(dofile(repo .. "/nvim/.config/nvim/lua/plugins/core.lua")) do
  if spec[1] == "mfussenegger/nvim-lint" then
    lint_spec = spec
    break
  end
end
assert(lint_spec, "nvim-lint configuration is missing")
local lint_calls = {}
package.loaded.lint = {
  linters = { shellcheck = {}, ruff = {} },
  linters_by_ft = {},
  try_lint = function(names)
    lint_calls[#lint_calls + 1] = names
  end,
}
local lint_buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(lint_buffer)
vim.bo[lint_buffer].filetype = "sh"
lint_spec.config()
local original_path = vim.env.PATH
local lint_root = vim.fn.tempname()
vim.fn.mkdir(lint_root .. "/bin", "p")
vim.env.PATH = lint_root .. "/bin"
vim.api.nvim_exec_autocmds("BufEnter", { buffer = lint_buffer })
assert(#lint_calls == 0, "missing shellcheck still triggered nvim-lint")
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, lint_root .. "/bin/shellcheck")
vim.fn.setfperm(lint_root .. "/bin/shellcheck", "rwx------")
vim.api.nvim_exec_autocmds("BufEnter", { buffer = lint_buffer })
assert(#lint_calls == 1 and lint_calls[1][1] == "shellcheck", "available shellcheck was skipped")
vim.env.PATH = original_path
vim.fn.delete(lint_root, "rf")
