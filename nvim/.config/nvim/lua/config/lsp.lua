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
      map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
      map("n", "<leader>lf", function()
        vim.lsp.buf.format({ async = true })
      end, "Format buffer")
      map("n", "<leader>e", vim.diagnostic.open_float, "Show diagnostics")
    end,
  })
end

function M.setup_servers()
  local capabilities = M.capabilities()
  local servers = {}
  for server, command in pairs({
    basedpyright = "basedpyright-langserver",
    rust_analyzer = "rust-analyzer",
    ts_ls = "typescript-language-server",
  }) do
    if vim.fn.executable(command) == 1 then
      servers[server] = {}
    end
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
    vim.lsp.config(server_name, vim.tbl_deep_extend("force", opts, {
      capabilities = capabilities,
    }))
    vim.lsp.enable(server_name)
  end
end

return M
