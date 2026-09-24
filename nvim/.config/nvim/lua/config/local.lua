local local_init = vim.fn.stdpath("config") .. "/lua/local/init.lua"
local uv = vim.uv

if uv.fs_stat(local_init) then
  dofile(local_init)
end
