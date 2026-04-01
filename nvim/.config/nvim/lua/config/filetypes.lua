vim.filetype.add({
  filename = {
    [".tmux.conf"] = "tmux",
  },
  pattern = {
    [".*%.tmux%.conf"] = "tmux",
    [".*%.wiki"] = "markdown",
    [".*%.book"] = "markdown",
  },
})
