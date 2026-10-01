local repo = assert(vim.env.DOTFILES_REPO)
vim.opt.rtp:prepend(repo .. "/nvim/.config/nvim")
vim.g.mapleader = " "
require("config.commands")
require("config.keymaps")
local api = vim.api

local function toggle()
  vim.cmd.Zoom()
end

local function layout()
  local sizes = {}
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    sizes[win] = { api.nvim_win_get_width(win), api.nvim_win_get_height(win) }
  end
  return { tree = vim.fn.winlayout(), sizes = sizes }
end

assert(vim.fn.maparg("<Space>z", "n") == "<Cmd>Zoom<CR>", "zoom mapping missing")
toggle()
assert(#api.nvim_list_tabpages() == 1, "single-window zoom created a redundant tab")
vim.cmd.vsplit()
vim.cmd.split()
local origin = api.nvim_get_current_tabpage()
local source = api.nvim_get_current_win()
local before = layout()
local buffer = api.nvim_get_current_buf()
local lines = {}
for i = 1, 100 do
  lines[i] = "line " .. i
end
api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
vim.wo.number = true
vim.wo.wrap = true
vim.wo.foldmethod = "manual"
vim.cmd("10,20fold")
api.nvim_win_set_cursor(source, { 30, 2 })
toggle()
local zoom_tab = api.nvim_get_current_tabpage()
assert(zoom_tab ~= origin and #api.nvim_tabpage_list_wins(zoom_tab) == 1, "zoom did not isolate the window")
assert(api.nvim_get_current_buf() == buffer and vim.bo.modified, "zoom lost the unsaved buffer")
assert(vim.wo.number and vim.wo.wrap and vim.fn.foldclosed(10) == 10, "zoom lost window settings or folds")
assert(api.nvim_win_get_cursor(0)[1] == 30, "zoom lost the cursor")
api.nvim_win_set_cursor(0, { 50, 3 })
api.nvim_buf_set_lines(buffer, 0, 1, false, { "edited while zoomed" })
toggle()
assert(api.nvim_get_current_win() == source, "zoom did not restore source focus")
assert(vim.deep_equal(layout(), before), "zoom changed the original split layout or sizes")
assert(api.nvim_win_get_cursor(source)[1] == 50, "zoom did not return the cursor")
assert(api.nvim_buf_get_lines(buffer, 0, 1, false)[1] == "edited while zoomed", "zoom lost edits")

-- Switching buffers while zoomed should return the selected buffer and view.
toggle()
local replacement = api.nvim_create_buf(true, false)
api.nvim_set_current_buf(replacement)
api.nvim_buf_set_lines(replacement, 0, -1, false, { "new", "unsaved" })
api.nvim_win_set_cursor(0, { 2, 1 })
toggle()
assert(api.nvim_win_get_buf(source) == replacement and vim.bo.modified, "zoom lost the replacement buffer")
assert(api.nvim_win_get_cursor(source)[1] == 2, "zoom lost replacement cursor")
assert(api.nvim_buf_is_valid(buffer) and vim.bo[buffer].modified, "zoom discarded the original unsaved buffer")

-- Stable tab handles survive reordering; toggling from the origin also returns.
toggle()
vim.cmd("tabmove 0")
api.nvim_set_current_tabpage(origin)
toggle()
assert(#api.nvim_list_tabpages() == 1 and api.nvim_get_current_win() == source, "zoom tracked tab numbers")

-- Different layouts can be zoomed independently without closing the other one.
toggle()
local first_zoom = api.nvim_get_current_tabpage()
vim.cmd.tabnew()
local second_origin = api.nvim_get_current_tabpage()
vim.cmd.vsplit()
toggle()
toggle()
assert(api.nvim_get_current_tabpage() == second_origin and api.nvim_tabpage_is_valid(first_zoom), "zoom crossed tabs")
api.nvim_set_current_tabpage(first_zoom)
toggle()
assert(api.nvim_get_current_tabpage() == origin, "zoom returned to another origin")

-- Manual closing cleans state; added splits and changed terminal size are safe.
toggle()
vim.cmd.tabclose()
api.nvim_set_current_tabpage(origin)
toggle()
assert(api.nvim_get_current_tabpage() ~= origin, "manual close left stale zoom state")
vim.cmd.vsplit()
local sidebar = api.nvim_create_buf(false, true)
api.nvim_set_current_buf(sidebar)
vim.o.columns = 100
vim.o.lines = 35
api.nvim_exec_autocmds("VimResized", {})
toggle()
assert(api.nvim_get_current_win() == source and #api.nvim_tabpage_list_wins(origin) == 3, "resize or added split broke return")
assert(api.nvim_win_get_buf(source) == replacement, "zoom returned an added sidebar instead of the main buffer")

-- Respect native close safeguards for another modified buffer with hidden off.
toggle()
vim.cmd.vsplit()
local extra = api.nvim_create_buf(true, false)
api.nvim_set_current_buf(extra)
api.nvim_buf_set_lines(extra, 0, -1, false, { "keep this unsaved" })
vim.opt.hidden = false
api.nvim_set_current_win(api.nvim_tabpage_list_wins(0)[2])
local guarded_tab = api.nvim_get_current_tabpage()
assert(not pcall(toggle), "zoom forced closure of an unrelated unsaved buffer")
assert(api.nvim_tabpage_is_valid(guarded_tab) and vim.bo[extra].modified, "failed return lost a buffer")
vim.opt.hidden = true
toggle()

-- Closing the original window/tab keeps the remaining zoomed work intact.
toggle()
local orphan = api.nvim_get_current_tabpage()
api.nvim_win_close(source, true)
toggle()
assert(api.nvim_get_current_tabpage() == orphan and api.nvim_tabpage_is_valid(orphan), "orphan zoom was closed")
toggle()
assert(api.nvim_get_current_tabpage() == orphan, "orphan retained stale zoom state")

-- A plugin float is never promoted to a zoom tab.
local float = api.nvim_open_win(0, true, { relative = "editor", row = 0, col = 0, width = 10, height = 3 })
local count = #api.nvim_list_tabpages()
toggle()
assert(#api.nvim_list_tabpages() == count and api.nvim_get_current_win() == float, "zoom captured a plugin float")
api.nvim_win_close(float, true)
vim.cmd("qa!")
