local M = {}

local docs_dir = vim.fs.normalize(vim.fn.expand("~/.documentation"))
local root_markers = { ".git", "Makefile", "package.json", "Cargo.toml", "pyproject.toml", "go.mod" }

local function builtin()
  return require("telescope.builtin")
end

local function file_picker_opts(cwd)
  local opts = {
    cwd = cwd,
    follow = true,
    hidden = true,
  }

  if vim.fn.executable("rg") == 1 then
    opts.find_command = { "rg", "--files", "--hidden", "-g", "!.git" }
  end

  return opts
end

function M.project_root()
  return vim.fs.root(0, root_markers) or vim.uv.cwd()
end

function M.current_dir()
  local name = vim.api.nvim_buf_get_name(0)
  return (name ~= "" and vim.fs.dirname(name)) or vim.uv.cwd()
end

function M.project_files()
  builtin().find_files(file_picker_opts(M.project_root()))
end

function M.working_dir_files()
  builtin().find_files(file_picker_opts(vim.uv.cwd()))
end

function M.local_dir_files()
  builtin().find_files(file_picker_opts(M.current_dir()))
end

function M.git_files()
  local ok = pcall(builtin().git_files, {
    cwd = M.project_root(),
    show_untracked = true,
  })

  if not ok then
    vim.notify("git files unavailable outside a git worktree", vim.log.levels.WARN)
  end
end

function M.recent_files()
  builtin().oldfiles({
    cwd_only = true,
  })
end

function M.buffers()
  builtin().buffers({
    ignore_current_buffer = true,
    sort_lastused = true,
  })
end

function M.all_buffers()
  builtin().buffers({
    ignore_current_buffer = false,
    sort_lastused = false,
  })
end

function M.keymaps()
  builtin().keymaps({
    default_text = "<leader>",
  })
end

function M.quickfix()
  builtin().quickfix()
end

local function live_grep(cwd, query)
  builtin().live_grep({
    additional_args = function()
      return { "--hidden", "--glob", "!.git" }
    end,
    cwd = cwd,
    default_text = query ~= "" and query or nil,
  })
end

function M.live_grep_working_dir(query)
  live_grep(vim.uv.cwd(), query)
end

function M.live_grep_local_dir(query)
  live_grep(M.current_dir(), query)
end

function M.live_grep_docs(query)
  if vim.uv.fs_stat(docs_dir) == nil then
    vim.notify(("docs directory not found: %s"):format(docs_dir), vim.log.levels.WARN)
    return
  end

  live_grep(docs_dir, query)
end

function M.session_picker()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local sessions = require("config.sessions")
  local items = sessions.list()

  if vim.tbl_isempty(items) then
    vim.notify("no saved sessions", vim.log.levels.INFO)
    return
  end

  pickers.new({}, {
    prompt_title = "Sessions",
    finder = finders.new_table({
      results = items,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          sessions.load(entry.value)
        end
      end)
      return true
    end,
  }):find()
end

function M.setup()
  local telescope = require("telescope")
  local actions = require("telescope.actions")

  telescope.setup({
    defaults = {
      layout_config = {
        prompt_position = "top",
      },
      mappings = {
        i = {
          ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
        },
      },
      sorting_strategy = "ascending",
    },
    pickers = {
      find_files = {
        hidden = true,
      },
    },
  })

  pcall(telescope.load_extension, "fzf")

  vim.api.nvim_create_user_command("Fw", function(opts)
    M.live_grep_working_dir(opts.args)
  end, {
    nargs = "*",
    desc = "Live grep the working directory",
  })

  vim.api.nvim_create_user_command("Fl", function(opts)
    M.live_grep_local_dir(opts.args)
  end, {
    nargs = "*",
    desc = "Live grep the current file directory",
  })

  vim.api.nvim_create_user_command("Docs", function(opts)
    M.live_grep_docs(opts.args)
  end, {
    nargs = "*",
    desc = "Live grep ~/.documentation",
  })

  vim.api.nvim_create_user_command("Sessions", function()
    M.session_picker()
  end, {
    desc = "Pick a saved session",
  })
end

return M
