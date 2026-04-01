# Neovim Migration

## Status

Implemented on 2026-03-31.

The Neovim baseline is now native Lua, bootstrapped through `make`, and no
longer depends on `source ~/.vimrc`. A few follow-ups remain intentionally
deferred so the first migration pass stays small and stable.

## Outcome

The repo now has a Neovim-first config under `nvim/.config/nvim/` with:

- `init.lua` as the entrypoint
- `lua/config/*.lua` for options, keymaps, commands, clipboard, LSP, search,
  sessions, and local overrides
- `lua/plugins/*.lua` for grouped lazy.nvim plugin specs
- `lazy-lock.json` checked in for reproducible plugin state

Plain `vim` still uses the existing `vim/.vim/` config. This migration did
not try to collapse both editors into one shared config again.

## What Shipped

### Native Lua baseline

- ported core options, keymaps, filetype rules, and autocmds from Vimscript
- ported session save/load/delete helpers
- ported custom clipboard operators that shell out to `cpy` / `pst`
- kept local override support via `lua/local/init.lua`

### Plugin baseline

- `lazy.nvim` for plugin management
- `monokai.nvim` for a monokai-adjacent theme
- `lualine.nvim`, `which-key.nvim`, `gitsigns.nvim`
- `nvim-treesitter`
- `nvim-lspconfig`, `conform.nvim`, `nvim-lint`
- `telescope.nvim` + `telescope-fzf-native.nvim` + `plenary.nvim`
- `mini.comment` and `mini.misc`
- `blink.cmp` + `friendly-snippets`
- `lazydev.nvim` for Lua config editing
- `nvim-orgmode`
- bridge plugins kept intentionally: `vim-fugitive`, `vim-tmux-navigator`

### Bootstrap integration

- `make setup` now includes Neovim plugin bootstrap
- `make nvim-plugins` installs and syncs lazy.nvim-managed plugins
- first launch does not self-bootstrap missing plugins; the config warns and
  points back to `make nvim-plugins`

## Workflow Coverage

The migration preserved the highest-value existing workflows first:

- project, working-directory, and local-directory file pickers
- working-directory, local-directory, and docs grep commands
- buffer, recent-file, keymap, quickfix, and session pickers
- quickfix toggle and navigation
- split, tab, diff, and search-centering keymaps
- zoom, commenting, and LSP-backed completion

## Bridge Decisions

### Kept in the Neovim baseline

- `vim-fugitive`
- `vim-tmux-navigator`

These still earn their place and did not justify replacement during the first
pass.

### Explicitly not part of v1

- no NERDTree replacement yet
- no Goyo replacement yet
- no pager migration yet

The Neovim baseline is intentionally editor-first. Optional or ambiguous
workflows stay out until they prove they are worth carrying forward.

### Wiki migration scope

`nvim-orgmode` is now available, but existing `*.wiki` files are not mass
converted. Incremental content migration remains the safer path.

## Remaining Follow-Ups

- decide the long-term pager path:
  `nvimpager`, a plain `nvim` pager/man workflow, or keeping the current
  pager flow outside Neovim
- convert active wiki content from `vimwiki` markup to org files as needed
- re-evaluate optional add-backs only if missed in practice:
  `oil.nvim`, `mini.surround`, `mini.ai`, a distraction-free writing mode

## Non-Goals

This migration did not:

- rewrite the remaining plain Vim config
- remove the legacy Vim plugin inventory
- force an immediate pager replacement
- chase feature parity for every old Vim-era plugin
