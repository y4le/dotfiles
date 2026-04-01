local local_init = vim.fn.stdpath("config") .. "/lua/local/init.lua"

if vim.uv.fs_stat(local_init) then
  dofile(local_init)
end
