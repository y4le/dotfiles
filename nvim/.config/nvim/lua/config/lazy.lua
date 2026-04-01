local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not uv.fs_stat(lazypath) then
  vim.schedule(function()
    vim.notify("lazy.nvim not found - run 'make nvim-plugins'", vim.log.levels.WARN)
  end)
  return
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  change_detection = {
    notify = false,
  },
  checker = {
    enabled = false,
  },
  install = {
    colorscheme = { "monokai", "habamax" },
  },
  rocks = {
    enabled = false,
  },
  ui = {
    border = "rounded",
  },
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
})
