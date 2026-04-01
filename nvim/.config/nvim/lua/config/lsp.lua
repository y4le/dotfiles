local M = {}

function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, "blink.cmp")
  if ok and blink.get_lsp_capabilities then
    capabilities = blink.get_lsp_capabilities(capabilities)
  end

  return capabilities
end

function M.setup()
  vim.diagnostic.config({
    severity_sort = true,
    underline = true,
    update_in_insert = false,
    virtual_text = false,
    float = {
      border = "rounded",
      source = "if_many",
    },
  })

  local group = vim.api.nvim_create_augroup("dotfiles_lsp_attach", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
      end

      map("n", "gd", vim.lsp.buf.definition, "LSP definition")
      map("n", "gD", vim.lsp.buf.declaration, "LSP declaration")
      map("n", "gr", vim.lsp.buf.references, "LSP references")
      map("n", "gi", vim.lsp.buf.implementation, "LSP implementation")
      map("n", "K", vim.lsp.buf.hover, "LSP hover")
      map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
      map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
      map("n", "<leader>lf", function()
        vim.lsp.buf.format({ async = true })
      end, "Format buffer")
      map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
      map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
      map("n", "<leader>e", vim.diagnostic.open_float, "Show diagnostics")
    end,
  })
end

function M.setup_servers()
  local lspconfig = require("lspconfig")
  local capabilities = M.capabilities()
  local servers = {
    basedpyright = {},
    rust_analyzer = {},
  }

  if lspconfig.ts_ls then
    servers.ts_ls = {}
  elseif lspconfig.tsserver then
    servers.tsserver = {}
  end

  if vim.fn.executable("lua-language-server") == 1 then
    servers.lua_ls = {
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          telemetry = {
            enable = false,
          },
          workspace = {
            checkThirdParty = false,
          },
        },
      },
    }
  end

  for server_name, opts in pairs(servers) do
    opts.capabilities = capabilities
    lspconfig[server_name].setup(opts)
  end
end

return M
