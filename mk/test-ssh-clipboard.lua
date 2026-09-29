local repo = assert(vim.env.DOTFILES_REPO)
vim.opt.rtp:prepend(repo .. "/nvim/.config/nvim")

local copies = {}
package.loaded["vim.ui.clipboard.osc52"] = {
  copy = function(reg)
    return function(lines)
      copies[#copies + 1] = { reg = reg, text = table.concat(lines, "\n") }
    end
  end,
  paste = function()
    error("SSH paste queried the terminal")
  end,
}

local clipboard = require("config.clipboard")
assert(clipboard.ssh_provider({}) == nil, "local session selected OSC 52")
assert(clipboard.ssh_provider({ SSH_TTY = "/dev/pts/1", TMUX = "1" }) == nil, "tmux provider was replaced")
assert(clipboard.ssh_provider({ SSH_TTY = "/dev/pts/1", DISPLAY = ":0" }) == nil, "X11 provider was replaced")
assert(
  clipboard.ssh_provider({ SSH_CONNECTION = "remote", WAYLAND_DISPLAY = "wayland-0" }) == nil,
  "Wayland provider was replaced"
)

vim.env.SSH_TTY = "/dev/pts/1"
vim.env.SSH_CONNECTION = nil
vim.env.TMUX = nil
vim.env.DISPLAY = nil
vim.env.WAYLAND_DISPLAY = nil
dofile(repo .. "/nvim/.config/nvim/lua/config/options.lua")

local provider = vim.g.clipboard
assert(provider.name == "OSC 52 copy over SSH", "SSH did not select the OSC 52 provider")
assert(provider.paste["+"]() == 0, "an empty remote clipboard did not fail quickly")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("yy", "xt", false)
assert(#copies > 0 and copies[1].text == "first\n", "yank did not copy with OSC 52")
local lines, regtype = provider.paste["+"]()
assert(lines[1] == "first" and regtype == "V", "remote paste did not use the internal cache")
vim.api.nvim_feedkeys("p", "xt", false)
local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(#buffer == 2 and buffer[1] == "first" and buffer[2] == "first", "remote paste changed the yank")
