vim.opt_local.conceallevel = 2

vim.keymap.set("x", "Sa", ":sort<CR>", {
  buffer = true,
  desc = "Sort selection alphabetically",
  silent = true,
})

vim.keymap.set("x", "Ss", ":'<,'>sort /[^\\[]\\+/<CR>", {
  buffer = true,
  desc = "Sort selection by first tag",
  silent = true,
})
