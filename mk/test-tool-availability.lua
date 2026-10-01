local repo = assert(vim.env.DOTFILES_REPO)
vim.opt.rtp:prepend(repo .. "/nvim/.config/nvim")
local tools = require("config.lsp")
local original_path = vim.env.PATH
vim.env.PATH = vim.env.DOTFILES_TEST_SHIMS .. ":" .. vim.env.DOTFILES_TEST_SYSTEM .. ":/usr/bin:/bin"
assert(vim.fn.exepath("dotfiles-tool") == "", "pull-gap fixture still has the helper link")
assert(tools.resolve("typescript-language-server") == nil, "repository fallback accepted a stale shim")
vim.env.PATH = original_path
assert(tools.resolve("typescript-language-server") == nil, "stale TS server shim is usable")
assert(tools.resolve("ruff") == nil, "stale Ruff shim is usable")
assert(not tools.formatter("ruff").condition(), "stale formatter shim was enabled")
assert(not tools.formatter("rustfmt").condition(), "stale rustfmt shim was enabled")

local original_config, original_enable = vim.lsp.config, vim.lsp.enable
local servers = {}
vim.lsp.config = function(name, opts) servers[name] = opts end
vim.lsp.enable = function() end
require("config.lsp").setup_servers()
assert(servers.ts_ls == nil, "stale TS server was enabled")

local system = assert(vim.env.DOTFILES_TEST_SYSTEM)
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, system .. "/typescript-language-server")
vim.fn.setfperm(system .. "/typescript-language-server", "rwx------")
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, system .. "/ruff")
vim.fn.setfperm(system .. "/ruff", "rwx------")
assert(tools.resolve("typescript-language-server") == system .. "/typescript-language-server", "system server hidden by stale shim")
assert(tools.formatter("ruff").condition(), "usable system formatter was skipped")
assert(tools.formatter("ruff").command() == system .. "/ruff", "formatter would still execute the stale shim")
require("config.lsp").setup_servers()
assert(servers.ts_ls.cmd[1] == system .. "/typescript-language-server", "LSP would still execute the stale shim")
assert(servers.ts_ls.cmd[2] == "--stdio", "LSP protocol arguments were lost")
vim.lsp.config, vim.lsp.enable = original_config, original_enable

local lint_spec
for _, spec in ipairs(dofile(repo .. "/nvim/.config/nvim/lua/plugins/core.lua")) do
  if spec[1] == "mfussenegger/nvim-lint" then lint_spec = spec end
end
local called
package.loaded.lint = {
  linters_by_ft = {},
  linters = { ruff = {} },
  try_lint = function(names) called = names end,
}
vim.bo.filetype = "python"
assert(lint_spec).config()
vim.api.nvim_exec_autocmds("BufEnter", { buffer = 0 })
assert(called and called[1] == "ruff", "usable linter was skipped")
assert(package.loaded.lint.linters.ruff.cmd == system .. "/ruff", "linter would still execute the stale shim")
vim.fn.delete(system .. "/ruff")
called = nil
vim.api.nvim_exec_autocmds("BufEnter", { buffer = 0 })
assert(called == nil, "stale linter still ran")
print("check-tool-availability: Neovim passed")
