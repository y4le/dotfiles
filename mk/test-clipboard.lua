vim.g.mapleader = " "
vim.g.clipboard = {
  name = "test",
  copy = { ["+"] = { "cpy" }, ["*"] = { "cpy" } },
  paste = { ["+"] = { "pst" }, ["*"] = { "pst" } },
}
vim.opt.clipboard = "unnamed,unnamedplus"
package.path = os.getenv("DOTFILES_REPO") .. "/nvim/.config/nvim/lua/?.lua;" .. package.path
vim.opt.rtp:prepend(os.getenv("DOTFILES_REPO") .. "/nvim/.config/nvim")
dofile(os.getenv("DOTFILES_REPO") .. "/nvim/.config/nvim/lua/config/keymaps.lua")

local function keys(input)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(input, true, false, true), "xt", false)
end

local function set_line(text, col)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
  vim.api.nvim_win_set_cursor(0, { 1, col or 0 })
end

local function expect(label, text)
  local actual = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "|")
  assert(actual == text, ("%s: expected %q, got %q"):format(label, text, actual))
end

set_line("éx one", 1)
keys("v<Space>y")
assert(vim.fn.getreg("+") == "é", "first visual selection copied the wrong text")

set_line("Qx one")
keys("v<Space>p")
expect("visual paste", "éx one")
assert(vim.fn.getreg("+") == "é", "visual paste changed the clipboard")

set_line("one two three", 4)
keys("<Space>piw")
expect("motion paste", "one é three")
assert(vim.fn.getreg("+") == "é", "motion paste changed the clipboard")

set_line("one two three", 4)
keys("<Space>pp")
expect("line paste", "é")

set_line("one two", 4)
keys("<Space>piw")
expect("last word paste", "one é")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "middle", "last" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
keys("<Space>pp")
expect("middle line paste", "first|é|last")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "last" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
keys("<Space>pp")
expect("last line paste", "first|é")

vim.env.DOTFILES_TEST_FAIL_PASTE = "1"
set_line("one two three", 4)
keys("<Space>piw")
expect("failed motion paste", "one two three")
keys("viw<Space>p")
expect("failed visual paste", "one two three")
vim.env.DOTFILES_TEST_FAIL_PASTE = nil

set_line("éx one", 0)
keys("v<Space>y")
assert(vim.fn.getreg("+") == "é", "UTF-8 character was truncated")
