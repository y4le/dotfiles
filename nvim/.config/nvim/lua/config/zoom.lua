local M = {}
local zooms = {}

local function forget(state)
  zooms[state.origin] = nil
  zooms[state.tab] = nil
end

local group = vim.api.nvim_create_augroup("DotfilesZoom", { clear = true })
vim.api.nvim_create_autocmd("TabClosed", {
  group = group,
  callback = function()
    for _, state in pairs(zooms) do
      if not vim.api.nvim_tabpage_is_valid(state.tab) then
        forget(state)
      end
    end
  end,
})

function M.toggle()
  local tab = vim.api.nvim_get_current_tabpage()
  local state = zooms[tab]
  if state then
    -- If the original layout was closed, keep the zoom tab as an ordinary tab.
    if not vim.api.nvim_win_is_valid(state.source) or not vim.api.nvim_win_is_valid(state.window) then
      forget(state)
      return
    end
    local win = state.window
    local buffer = vim.api.nvim_win_get_buf(win)
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    if vim.api.nvim_win_get_buf(state.source) ~= buffer then
      vim.api.nvim_win_set_buf(state.source, buffer)
    end
    -- No bang: ordinary close safeguards still apply to any added windows.
    vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(state.tab))
    forget(state)
    vim.api.nvim_set_current_win(state.source)
    vim.fn.winrestview(view)
    return
  end

  local source = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(source).relative ~= "" then
    return
  end
  local splits = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      splits = splits + 1
    end
  end
  if splits < 2 then
    return
  end
  -- Native splitting copies window options and folds without rebuilding layout.
  vim.cmd("tab split")
  state = {
    origin = tab,
    tab = vim.api.nvim_get_current_tabpage(),
    source = source,
    window = vim.api.nvim_get_current_win(),
  }
  zooms[state.origin] = state
  zooms[state.tab] = state
end

return M
