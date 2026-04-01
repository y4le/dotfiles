local api = vim.api

local checktime_group = api.nvim_create_augroup("dotfiles_checktime", { clear = true })
api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = checktime_group,
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd.checktime()
    end
  end,
})

local cursor_group = api.nvim_create_augroup("dotfiles_restore_cursor", { clear = true })
api.nvim_create_autocmd("BufReadPost", {
  group = cursor_group,
  callback = function(args)
    if vim.bo[args.buf].filetype == "gitcommit" then
      return
    end

    local line = vim.api.nvim_buf_get_mark(args.buf, '"')[1]
    if line > 0 and line <= vim.api.nvim_buf_line_count(args.buf) then
      vim.cmd.normal({ args = { 'g`"' }, bang = true })
    end
  end,
})

local trim_group = api.nvim_create_augroup("dotfiles_trim_whitespace", { clear = true })
api.nvim_create_autocmd("BufWritePre", {
  group = trim_group,
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" or not vim.bo[args.buf].modifiable then
      return
    end

    local skipped = {
      diff = true,
      gitcommit = true,
      markdown = true,
      org = true,
      qf = true,
      text = true,
    }

    if skipped[vim.bo[args.buf].filetype] then
      return
    end

    local view = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

local notes_group = api.nvim_create_augroup("dotfiles_notes", { clear = true })
api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = notes_group,
  pattern = "*.wiki",
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
    vim.opt_local.foldmethod = "manual"
    vim.opt_local.wrap = false
    vim.opt_local.formatoptions:remove("t")
  end,
})

api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = notes_group,
  pattern = "*.book",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = "nc"
  end,
})
