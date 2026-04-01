local M = {}

function M.opts()
  return {
    appearance = {
      nerd_font_variant = "mono",
    },
    completion = {
      documentation = {
        auto_show = false,
      },
    },
    fuzzy = {
      implementation = "prefer_rust_with_warning",
    },
    keymap = {
      preset = "default",
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      per_filetype = {
        lua = { inherit_defaults = true, "lazydev" },
      },
      providers = {
        lazydev = {
          module = "lazydev.integrations.blink",
          name = "LazyDev",
          score_offset = 100,
        },
      },
    },
  }
end

return M
