return {
  {
    "preservim/nerdtree",
    lazy = false,
    keys = {
      { "<leader>sn", "<Cmd>NERDTreeToggle<CR>", desc = "Toggle file sidebar" },
      { "<leader>sN", "<Cmd>NERDTreeFind<CR>", desc = "Reveal current file in sidebar" },
      { "<leader>sR", "<Cmd>NERDTreeRefreshRoot<CR>", desc = "Refresh file sidebar" },
    },
    init = function()
      vim.g.NERDTreeShowHidden = 1
      vim.g.NERDTreeWinSize = 30
    end,
  },
  {
    "mikavilpas/yazi.nvim",
    cmd = { "Yazi" },
    keys = {
      { "<C-g>", "<Cmd>Yazi<CR>", mode = "n", desc = "Open Yazi" },
    },
    opts = {
      change_neovim_cwd_on_close = true,
      open_for_directories = false,
    },
  },
  {
    "nvim-orgmode/orgmode",
    ft = { "org" },
    cmd = { "Org", "OrgAgenda", "OrgCapture", "OrgTodo" },
    config = function()
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*",
        org_default_notes_file = "~/org/inbox.org",
      })
    end,
  },
}
