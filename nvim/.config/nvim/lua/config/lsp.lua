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
    end,
  })
end

function M.setup_servers()
  local capabilities = M.capabilities()
  local servers = {}
  local tools = M
  for server, command in pairs({
    basedpyright = { "basedpyright-langserver", "--stdio" },
    rust_analyzer = { "rust-analyzer" },
    ts_ls = { "typescript-language-server", "--stdio" },
  }) do
    local resolved = tools.resolve(command[1])
    if resolved then
      command[1] = resolved
      servers[server] = { cmd = command }
    end
  end

  local lua_server = tools.resolve("lua-language-server")
  if lua_server then
    servers.lua_ls = {
      cmd = { lua_server },
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

-- Ordinary commands stay cheap; only mise shims require an offline lookup.
function M.resolve(name)
  local command = vim.fn.exepath(name)
  if command == "" then
    return nil
  end
  local shims = vim.env.MISE_SHIMS_DIR
    or ((vim.env.MISE_DATA_DIR or ((vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")) .. "/mise")) .. "/shims")
  local parent = vim.uv.fs_realpath(vim.fn.fnamemodify(command, ":h"))
  if parent ~= (vim.uv.fs_realpath(shims) or shims) then
    return command
  end
  local resolver = vim.fn.exepath("dotfiles-tool")
  if resolver == "" then
    -- Existing Stow links update on pull before new command links are installed.
    local source = vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))
    local repo = source and source:match("^(.*)/nvim/%.config/nvim/lua/config/lsp%.lua$")
    resolver = repo and (repo .. "/scripts/bin/dotfiles-tool") or ""
    if vim.fn.executable(resolver) ~= 1 then
      return nil
    end
  end
  local result = vim.system({ resolver, name }, { text = true }):wait(1000)
  if result.code ~= 0 then
    return nil
  end
  return (result.stdout:gsub("\n$", ""))
end

function M.formatter(name)
  return {
    condition = function()
      return M.resolve(name) ~= nil
    end,
    command = function()
      return M.resolve(name) or name
    end,
  }
end


return M
