return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    opts = {
      default_file_explorer = true,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ["q"] = { "actions.close", mode = "n" },
      },
    },
  },
  {
    "preservim/nerdtree",
    cmd = {
      "NERDTree",
      "NERDTreeClose",
      "NERDTreeFind",
      "NERDTreeFocus",
      "NERDTreeRefreshRoot",
      "NERDTreeToggle",
    },
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
    event = "VeryLazy",
    keys = {
      { "<C-g>", "<Cmd>Yazi<CR>", mode = "n", desc = "Open Yazi" },
    },
    opts = {
      change_neovim_cwd_on_close = true,
      open_for_directories = false,
    },
  },
  {
    "nvim-mini/mini.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>z",
        function()
          require("mini.misc").zoom()
        end,
        desc = "Zoom window",
      },
    },
    version = false,
    config = function()
      require("mini.comment").setup()
      require("mini.misc").setup()
    end,
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
