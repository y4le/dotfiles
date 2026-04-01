return {
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
