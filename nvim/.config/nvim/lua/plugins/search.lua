local telescope = require("config.telescope")

return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = { "Docs", "Fl", "Fw", "Sessions", "Telescope" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
            and (vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1 or vim.fn.executable("clang") == 1)
        end,
      },
    },
    keys = {
      { "<leader>f", telescope.project_files, desc = "Project files" },
      { "<leader>m", telescope.recent_files, desc = "Recent files" },
      { "<leader>j", telescope.buffers, desc = "Buffers" },
      { "<leader>J", telescope.all_buffers, desc = "All buffers" },
      { "<leader>c", telescope.keymaps, desc = "Keymaps" },
      { "<leader>qm", telescope.quickfix, desc = "Quickfix list" },
      { "<leader>Ff", telescope.project_files, desc = "Project files" },
      { "<leader>Fw", telescope.working_dir_files, desc = "Working directory files" },
      { "<leader>Fl", telescope.local_dir_files, desc = "Local directory files" },
      { "<leader>Fg", telescope.git_files, desc = "Git files" },
      { "<leader>Fm", telescope.recent_files, desc = "Recent files" },
      { "<leader>Fb", telescope.buffers, desc = "Buffers" },
      { "<leader>FB", telescope.all_buffers, desc = "All buffers" },
      { "<leader>Fs", telescope.session_picker, desc = "Sessions" },
    },
    config = function()
      telescope.setup()
    end,
  },
}
