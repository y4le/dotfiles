local state_dir = vim.fn.stdpath("state")
local swap_dir = state_dir .. "/swap"
local backup_dir = state_dir .. "/backup"
local undo_dir = state_dir .. "/undo"
local view_dir = state_dir .. "/view"

for _, dir in ipairs({ swap_dir, backup_dir, undo_dir, view_dir }) do
  vim.fn.mkdir(dir, "p", 448)
end

vim.opt.termguicolors = true

vim.opt.lazyredraw = true

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
vim.opt.viewoptions = { "cursor", "folds", "slash", "unix" }

vim.opt.undofile = true
vim.opt.undodir = undo_dir .. "//"
vim.opt.directory = swap_dir .. "//"
vim.opt.backupdir = backup_dir .. "//"
vim.opt.backup = true

vim.cmd.syntax("enable")
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.colorcolumn = "80"
vim.opt.cursorline = true
vim.opt.scrolloff = 5
vim.opt.sidescroll = 5
vim.opt.listchars:append({ precedes = "<", extends = ">" })
vim.opt.showmatch = true
vim.opt.matchtime = 2

vim.opt.mouse = "a"
vim.opt.clipboard = "unnamed,unnamedplus"
vim.opt.whichwrap:append("<,>,h,l")

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.grepprg = "rg --vimgrep --no-heading -S"
vim.opt.grepformat = "%f:%l:%c:%m,%f:%l:%m"

vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

vim.cmd.colorscheme("habamax")
