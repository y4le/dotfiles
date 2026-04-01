local map = vim.keymap.set

local function toggle_quickfix(height)
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      vim.cmd.cclose()
      return
    end
  end

  vim.cmd((height or 8) .. "copen")
  vim.cmd.cc()
end

local function edit_cfile(win_cmd)
  local target = vim.fn.expand("<cfile>")
  if target == "" then
    vim.notify("no file under cursor", vim.log.levels.WARN)
    return
  end

  vim.cmd("wincmd " .. win_cmd)
  vim.cmd.edit(vim.fn.fnameescape(target))
  vim.cmd("wincmd p")
end

map("n", "<leader>;", function()
  vim.cmd.normal({ args = { "@:" }, bang = true })
end, { desc = "Repeat last command-line command" })

map("n", "j", "gj", { desc = "Move by display line" })
map("n", "k", "gk", { desc = "Move by display line" })
map("n", "Y", "y$", { desc = "Yank to end of line" })
map("n", "n", "nzz", { desc = "Next search result" })
map("n", "N", "Nzz", { desc = "Previous search result" })
map("n", "*", "*zz", { desc = "Search word under cursor" })
map("n", "#", "#zz", { desc = "Search word under cursor backward" })

map("n", "<leader>%", "<Cmd>vsplit<CR>", { desc = "Vertical split" })
map("n", '<leader>"', "<Cmd>split<CR>", { desc = "Horizontal split" })

map("n", "H", "<Cmd>tabprevious<CR>", { desc = "Previous tab" })
map("n", "L", "<Cmd>tabnext<CR>", { desc = "Next tab" })
map("n", "X", "<Cmd>tabclose<CR>", { desc = "Close tab" })

map("n", "<leader>bp", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bn", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bx", "<Cmd>bprevious | bdelete #<CR>", { desc = "Close buffer and preserve split" })

map("n", "<leader>sr", function()
  vim.wo.relativenumber = not vim.wo.relativenumber
end, { desc = "Toggle relative number" })
map("n", "<leader>sp", "<Cmd>set paste!<CR>", { desc = "Toggle paste mode" })
map("n", "<leader>sc", function()
  vim.opt_local.conceallevel = vim.opt_local.conceallevel:get() == 0 and 2 or 0
end, { desc = "Toggle conceal" })

map("n", "<leader>qq", function()
  toggle_quickfix(8)
end, { desc = "Toggle quickfix" })
map("n", "<leader>qn", "<Cmd>cnext<CR>", { desc = "Quickfix next" })
map("n", "<leader>qp", "<Cmd>cprevious<CR>", { desc = "Quickfix previous" })

map("n", "<leader>/", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

map("n", "<leader>gf", function()
  edit_cfile("p")
end, { desc = "Open file under cursor in previous split" })
map("n", "<leader>gF", function()
  edit_cfile("w")
end, { desc = "Open file under cursor in next split" })
map("n", "g<C-j>", "<C-W>J", { desc = "Move split to bottom" })
map("n", "g<C-k>", "<C-W>K", { desc = "Move split to top" })
map("n", "g<C-h>", "<C-W>H", { desc = "Move split to left" })
map("n", "g<C-l>", "<C-W>L", { desc = "Move split to right" })

map("n", "<leader>Dn", "]c", { desc = "Next diff hunk" })
map("n", "<leader>Dp", "[c", { desc = "Previous diff hunk" })
map("n", "<leader>Dg", ":diffget<CR>", { desc = "Diff get" })
map("n", "<leader>Do", ":diffget other<CR>", { desc = "Diff get other" })
map("n", "<leader>Db", ":diffget base<CR>", { desc = "Diff get base" })
map("n", "<leader>Du", ":diffput<CR>", { desc = "Diff put" })

map("n", "<leader>y", function()
  return require("config.clipboard").copy_motion()
end, { desc = "Copy motion to system clipboard", expr = true })
map("x", "<leader>y", function()
  require("config.clipboard").copy_visual()
end, { desc = "Copy selection to system clipboard" })
map("n", "<leader>yy", function()
  vim.go.operatorfunc = "v:lua.require'config.clipboard'.copy_operator"
  return "g@_"
end, { desc = "Copy line to system clipboard", expr = true })

map("n", "<leader>p", function()
  return require("config.clipboard").paste_motion()
end, { desc = "Paste system clipboard over motion", expr = true })
map("x", "<leader>p", function()
  require("config.clipboard").paste_visual()
end, { desc = "Paste system clipboard over selection" })
map("n", "<leader>pp", function()
  vim.go.operatorfunc = "v:lua.require'config.clipboard'.paste_operator"
  return "g@_"
end, { desc = "Paste system clipboard over line", expr = true })

vim.cmd([[cnoreabbrev <expr> %% expand('%:p:h')]])
