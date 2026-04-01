# Neovim Migration Plan

## Status

Decisions approved 2026-03-31. Ready for implementation in phases.

## Goal

Move from the current compatibility shim toward a Neovim-first setup that is:

- native Lua by default
- minimal at the start
- built around current Neovim 0.11 features and popular plugins
- respectful of existing muscle memory and high-value workflows

The target is not "zero Vimscript on day one". The target is "remove Vimscript
and Vim plugins wherever there is clear payoff, while avoiding regressions in
the workflows that actually matter".

## Current State

- `nvim/.config/nvim/init.vim` still just forwards Neovim into the Vim config
- plugin inventory still lives in `vim/.vim/config/plugins.vim`
- core options and keymaps still live in Vimscript
- there is no native Lua config layout yet
- there is no Neovim plugin lockfile yet

## Vim Compatibility

The existing `vim/.vim/` config stays as-is for now. Plain `vim` continues
to work unchanged. Stripping down the vim config is deferred to a later pass
— this migration only adds the neovim-native setup alongside it.

## Planning Principles

- Start with a minimal baseline, not a full distro.
- Prefer Neovim built-ins where they are mature.
- Preserve editing/search/navigation muscle memory early.
- Rewrite small custom helpers in Lua instead of keeping them as Vimscript.
- Do not let wiki or pager edge cases block the main migration.
- Allow a small temporary bridge set of legacy plugins when there is no good
  Lua-native replacement yet.

## Proposed Baseline

- `init.lua`
- `lua/config/options.lua`
- `lua/config/keymaps.lua`
- `lua/config/autocmds.lua`
- `lua/plugins/*.lua`
- `lazy.nvim` as the plugin manager

This should be closer to a cleaned-up `kickstart.nvim` style layout than a full
prebuilt distro.

## Approved Decisions

### 1. Search stack: `telescope.nvim`

Telescope has the larger extension ecosystem, a structured Lua API for
custom pickers, and is the standard target for internal company tooling
at large tech companies. If internal neovim extensions exist, they will
almost certainly be telescope plugins.

fzf and ripgrep remain installed and available for shell use. Telescope
uses them as backends (via `telescope-fzf-native.nvim` for sorting and
ripgrep for live grep), so existing tools are not wasted.

### 2. Completion engine: `blink.cmp`

Lighter than nvim-cmp, less config boilerplate, built-in snippet support,
async Rust fuzzy matching. Covers the needed sources (LSP, buffer, path).
The niche nvim-cmp source ecosystem is not needed for this workflow.

### 3. Comment plugin: `mini.comment`

Actively maintained (unlike Comment.nvim which is archived). Part of
mini.nvim, which opens the door to other mini modules later (mini.surround,
mini.ai for textobjects) if we want to consolidate.

### 4. Tool installation: skip mason, use mise/system

LSP servers, formatters, and linters are installed via mise or system
packages — not mason.nvim. This avoids a second tool-management layer
alongside mise, keeps the install story in the Makefile, and matches the
repo's existing approach.

LSP servers needed:
- **Python**: basedpyright (via pipx/mise)
- **Rust**: rust-analyzer (ships with rustup)
- **JS/TS**: typescript-language-server (via npm/mise)
- **Lua** (optional, for editing nvim config): lua-language-server (via mise)

Formatters:
- **Python**: ruff (via mise)
- **JS/TS**: prettier (via npm)
- **Rust**: rustfmt (ships with rustup)

### 5. Wiki: migrate to `nvim-orgmode`

Replace vimwiki with nvim-orgmode. Org format is portable (readable by
Emacs, rendered by GitHub, supported by many tools), the feature set is
the richest (agenda, capture, scheduling, code blocks), and the community
is active. vimwiki's custom markup is a dead end.

Migration path: start with nvim-orgmode as a lazy-loaded plugin, convert
wiki files incrementally. No rush to convert everything at once.

### 6. Theme: monokai-adjacent

Keep a monokai-adjacent theme at first so the migration does not change
both behavior and visuals at the same time.

### 7. No Lua toolchain needed

Neovim 0.11 embeds LuaJIT. No separate Lua install or luarocks is required.
lazy.nvim's optional luarocks support stays disabled.

## Bootstrap Integration

### What `make setup` already handles

- neovim binary (via mise)
- python, node, rust runtimes (via mise)
- fzf, ripgrep, bat, fd (via mise)
- `make link` stows the `nvim` package
- `make vim-plugins` bootstraps vim-plug (for legacy vim config)

### What needs to be added to mise config

```toml
# LSP servers
"pipx:basedpyright" = "latest"
"npm:typescript-language-server" = "latest"

# Formatters / linters
"pipx:ruff" = "latest"
"npm:prettier" = "latest"
```

rust-analyzer and rustfmt ship with `rustup` and need no separate install.

### lazy.nvim bootstrap: explicit via Makefile

Consistent with the sheldon and vim-plug approach: editors should never
download anything on first launch. Instead, a Makefile target handles it.

**`make nvim-plugins`** will:
1. Clone lazy.nvim to `~/.local/share/nvim/lazy/lazy.nvim` if missing
2. Run `nvim --headless "+Lazy! sync" +qa` to install all plugins

**`init.lua` gets a fail-fast guard:**
```lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.notify("lazy.nvim not found — run 'make nvim-plugins'", vim.log.levels.WARN)
  return
end
```

This means:
- `make setup` calls `make nvim-plugins` (after `make link`)
- first `nvim` launch without bootstrap prints a helpful message, no download
- `make nvim-plugins` is idempotent — safe to re-run

**`make vim-plugins`** continues to work for the legacy vim config. No
changes needed there.

## Plugin Plan

### Migrate 1:1 In Lua

- Core options from `vim/.vim/config/settings.vim`
- Leader-space and core ergonomic maps from `vim/.vim/config/maps.vim`
- Split and tab helpers
- Search centering maps
- Custom filetype detection for `*.tmux.conf`, `*.wiki`, and `*.book`
- Diff helpers
- Writing-related local options that are not plugin-specific

### Rewrite As Small Lua Helpers

- `util#SourceIfExists`
- `nav#OpenInPrevSplit` and `nav#OpenInNextSplit`
- `conceal#toggle_conceal`
- quickfix toggle
- session save/load/picker helpers
- trailing-whitespace cleanup on save
- restore-cursor-on-open autocmd
- custom clipboard operators that shell out to `command cpy` / `command pst`

### Replace With Neovim-Native Plugins

| Old | New |
|-----|-----|
| vim-plug | lazy.nvim |
| vim-airline | lualine.nvim |
| vim-signify | gitsigns.nvim |
| ale + ad hoc formatters | nvim-lspconfig + conform.nvim + nvim-lint |
| fzf.vim | telescope.nvim + telescope-fzf-native.nvim |
| tcomment_vim | mini.comment |
| vim-zoom | mini.misc (zoom) |
| vimwiki | nvim-orgmode |
| NERDTree | nothing in v1; oil.nvim as first add-back candidate |

### Keep Temporarily As Bridge Plugins

- `vim-fugitive`
- `vim-tmux-navigator` (unless swapped for a Lua-native tmux integration)

### Drop Or Defer Unless Missed In Real Use

vim-surround, targets.vim, vim-buffergator, taboo.vim, vim-numbertoggle,
gundo.vim, tagbar, vim-better-whitespace, vim-peekaboo, vim-pasta, NrrwRgn,
incsearch.vim, traces.vim, ferret, vim-submode, restore_view.vim, mru,
w3m.vim, ranger.vim

Note: vim-surround and targets.vim are dropped for now. If textobject or
surround gaps are felt in practice, re-add via mini.surround / mini.ai.

### Ambiguous — Revisit After Baseline Exists

goyo.vim, calendar-vim, AnsiEsc, asyncrun.vim, vimpager/pager workflow

## Migration Phases

### Phase 0: Native Lua Skeleton

- create `init.lua`
- port core options
- port core keymaps
- port filetype/autocmd logic
- port clipboard operators and the tiny custom helper functions
- choose a temporary colorscheme

Goal: editing in Neovim should already feel recognizably yours before plugin
work starts.

### Phase 1: Core Plugin Layer

- add `make nvim-plugins` target (clone lazy.nvim + headless sync)
- add fail-fast guard in `init.lua`
- add `nvim-treesitter`
- add `nvim-lspconfig` (basedpyright, rust-analyzer, tsserver)
- add `conform.nvim` (ruff, prettier, rustfmt)
- add `nvim-lint`
- add `gitsigns.nvim`
- add `which-key.nvim`
- add `lualine.nvim`

### Phase 2: Search And Navigation

- add `telescope.nvim` + `telescope-fzf-native.nvim` (uses fzf algorithm
  for sorting, ripgrep for live grep)
- add `plenary.nvim` (telescope dependency)
- recreate project/workdir/local-dir pickers
- recreate buffer and map pickers
- recreate quickfix helpers
- recreate session picker
- evaluate company-internal telescope extensions if available

### Phase 3: Editing Helpers

- add `mini.comment`
- add `mini.misc` (for zoom via `MiniMisc.zoom()`, mapped to `<leader>z`)
- add `nvim-orgmode` (lazy-loaded, replaces vimwiki)
- if surround or textobject gaps are felt, add `mini.surround` / `mini.ai`

### Phase 4: Completion

- add `blink.cmp`
- wire completion into LSP, snippets, buffer, and path sources
- add `lazydev.nvim` if editing the neovim config with LSP support is wanted

### Phase 5: Legacy Bridge Review

- keep only the legacy plugins that still earn their place
- decide whether `goyo` and pager behavior remain part of the long-term
  Neovim setup

## References

### Setup Patterns

- **kickstart.nvim** — best reference for a small understandable starter
- **LazyVim** — good source of modern defaults; too large to adopt wholesale

### Plugin Families

lazy.nvim, nvim-treesitter, nvim-lspconfig, conform.nvim, nvim-lint,
gitsigns.nvim, which-key.nvim, telescope.nvim, lualine.nvim, blink.cmp,
oil.nvim, mini.nvim, snacks.nvim (later adoption candidate)

## Pager Note

Pager behavior still belongs to the Neovim migration but should not block
the first native-Lua editor pass.

Follow-up options:
1. adopt `nvimpager`
2. document a plain `nvim`-based pager/man workflow
3. fall back to `less` if editor-as-pager is no longer valuable

## Expected Outcome

After this migration:

- Neovim no longer depends on `source ~/.vimrc`
- the core setup is readable native Lua
- old Vim-era plugins are either replaced, intentionally bridged, or removed
- the final setup is smaller and more intentional than the current shared
  Vim/Neovim arrangement
- the existing vim config remains unchanged and functional
