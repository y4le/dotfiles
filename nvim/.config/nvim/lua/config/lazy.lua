local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"

if not uv.fs_stat(lazypath) then
  vim.schedule(function()
    vim.notify("lazy.nvim not found - run 'make nvim-plugins'", vim.log.levels.WARN)
  end)
  return
end

vim.opt.rtp:prepend(lazypath)

if not vim.env.DOTFILES_NVIM_BOOTSTRAP then
  local installed = false
  local ok, lock = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
  end)
  if ok then
    for name, _ in pairs(lock) do
      if name ~= "lazy.nvim" and uv.fs_stat(vim.fn.stdpath("data") .. "/lazy/" .. name) then
        installed = true
        break
      end
    end
  end

  if not installed then
    vim.schedule(function()
      vim.notify("Neovim plugins not restored; run 'make plugins'", vim.log.levels.WARN)
    end)
    return
  end
end

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
    missing = false,
    colorscheme = { "monokai", "habamax" },
  },
  rocks = {
    enabled = false,
  },
  ui = {
    border = "rounded",
  },
  lockfile = lockfile,
})
