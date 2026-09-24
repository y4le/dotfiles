local M = {}

function M.can_paste()
  local ok, info = pcall(vim.fn.getreginfo, "+")
  if not ok or not info.regcontents or #info.regcontents == 0 then
    vim.notify("system clipboard is unavailable or empty", vim.log.levels.ERROR)
    return false
  end
  return true
end

-- g@ supplies the motion's bounds in '[ and ']. Let Neovim select and replace
-- the text so it handles UTF-8, tabs, and blockwise selections itself.
function M.paste_operator(kind)
  if not M.can_paste() then
    return
  end
  local selection
  if kind == "line" then
    selection = "'[V']"
  elseif kind == "block" then
    selection = "`[\22`]"
  else
    selection = "`[v`]"
  end
  vim.cmd.normal({ selection .. '"+P', bang = true })
end

return M
