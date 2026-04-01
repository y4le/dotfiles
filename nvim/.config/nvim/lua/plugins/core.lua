local lsp = require("config.lsp")

return {
  {
    "tanvirtin/monokai.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("monokai")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      options = {
        component_separators = "",
        globalstatus = true,
        section_separators = "",
        theme = "auto",
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = false,
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        changedelete = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "^" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    opts = {
      auto_install = false,
      highlight = {
        enable = true,
      },
      indent = {
        enable = true,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      lsp.setup()
      lsp.setup_servers()
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      format_on_save = function(bufnr)
        if vim.bo[bufnr].buftype ~= "" then
          return nil
        end

        return {
          lsp_fallback = true,
          timeout_ms = 1000,
        }
      end,
      formatters_by_ft = {
        css = { "prettier" },
        html = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        lua = { "stylua" },
        markdown = { "prettier" },
        python = { "ruff_format" },
        rust = { "rustfmt" },
        toml = { "taplo" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        yaml = { "prettier" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        bash = { "shellcheck" },
        python = { "ruff" },
        sh = { "shellcheck" },
        zsh = { "shellcheck" },
      }

      local group = vim.api.nvim_create_augroup("dotfiles_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = group,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
  {
    "tpope/vim-fugitive",
    cmd = {
      "G",
      "Git",
      "Gdiffsplit",
      "Gvdiffsplit",
      "Ggrep",
      "Gread",
      "Gwrite",
    },
  },
  {
    "christoomey/vim-tmux-navigator",
    keys = {
      { "<C-h>" },
      { "<C-j>" },
      { "<C-k>" },
      { "<C-l>" },
    },
  },
}
