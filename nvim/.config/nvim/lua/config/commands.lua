local sessions = require("config.sessions")

vim.api.nvim_create_user_command("SessionSave", function(opts)
  sessions.save(opts.args ~= "" and opts.args or sessions.default_name())
end, {
  nargs = "?",
  complete = "dir",
  desc = "Save the current session",
})

vim.api.nvim_create_user_command("SessionLoad", function(opts)
  sessions.load(opts.args ~= "" and opts.args or sessions.default_name())
end, {
  nargs = "?",
  desc = "Load a saved session",
})

vim.api.nvim_create_user_command("SessionDelete", function(opts)
  sessions.delete(opts.args ~= "" and opts.args or sessions.default_name())
end, {
  nargs = "?",
  desc = "Delete a saved session",
})

vim.api.nvim_create_user_command("SessionSaveMin", function()
  vim.opt.sessionoptions = { "buffers", "tabpages" }
end, {
  desc = "Save minimal session state",
})

vim.api.nvim_create_user_command("SessionSaveMax", function()
  vim.opt.sessionoptions = {
    "blank",
    "buffers",
    "curdir",
    "folds",
    "globals",
    "help",
    "options",
    "tabpages",
    "winsize",
  }
end, {
  desc = "Save maximal session state",
})
