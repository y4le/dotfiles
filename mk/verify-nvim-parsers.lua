local function verify()
  local names = assert(vim.env.DOTFILES_NVIM_PARSERS, "parser list is required")
  local treesitter = assert(
    require("lazy.core.config").plugins["nvim-treesitter"],
    "nvim-treesitter was not restored"
  )
  local missing = {}

  for name in names:gmatch("%S+") do
    local path = treesitter.dir .. "/parser/" .. name .. ".so"
    if not vim.uv.fs_stat(path) then
      missing[#missing + 1] = name
    end
  end

  if #missing > 0 then
    error("missing Neovim Treesitter parsers: " .. table.concat(missing, ", "))
  end
end

local ok, err = xpcall(verify, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
