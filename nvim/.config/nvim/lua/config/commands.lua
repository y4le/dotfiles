local sessions = require("config.sessions")

local function command(name, action, description)
  vim.api.nvim_create_user_command(name, function(opts)
    action(opts.args ~= "" and opts.args or sessions.default_name())
  end, {
    nargs = "?",
    complete = sessions.complete,
    desc = description,
  })
end

command("SessionSave", sessions.save, "Save the current session")
command("SessionLoad", sessions.load, "Load a saved session")
command("SessionDelete", sessions.delete, "Delete a saved session")
command("SessionSaveMin", function(name)
  sessions.save(name, { "buffers", "tabpages" })
end, "Save minimal session state")
command("SessionSaveMax", function(name)
  sessions.save(name, {
    "blank",
    "buffers",
    "curdir",
    "folds",
    "globals",
    "help",
    "options",
    "tabpages",
    "winsize",
  })
end, "Save maximal session state")
