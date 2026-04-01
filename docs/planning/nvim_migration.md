# Neovim Migration Plan

## Status

Proposed. This is a future migration plan, not part of the current Vim cleanup
pass.

## Goal

Move from the current shared Vim/Neovim shim toward an intentional Neovim-first
setup without breaking existing editor or pager workflows during the transition.

## Current State

- `nvim/.config/nvim/init.vim` currently sources `~/.vimrc`
- the active plugin list still lives in `vim/.vim/config/plugins.vim`
- shell pager behavior still includes a conditional `vimpager` override in
  `zsh/.zshenv`
- `vim/.vim/config/plugins.vim` still includes `rkitover/vimpager`

That means Neovim exists as a compatibility entrypoint today, not as a
separate, designed configuration.

## Non-Goals

- migrating everything to Lua in one pass
- replacing every Vim plugin at once
- breaking the current `vim` workflow before `nvim` has feature parity

## Key Migration Questions

1. Should Neovim become the default editor, or remain an alternate entrypoint?
2. Which Vim plugins should be kept as-is during transition, and which should
   move to Neovim-native replacements?
3. What should replace the current `vimpager` workflow?

## Pager Decision

The pager question is intentionally part of the Neovim migration, not the
current Vim cleanup.

### Why defer it

- the current `vimpager` path is stale, but the underlying workflow is still
  valuable
- deciding between "remove pager entirely" and "modernize pager around
  Neovim" is an architecture question, not just dead-code cleanup

### Proposed direction

When Neovim migration starts, replace the current `vimpager` path with one of
these explicit outcomes:

1. `nvimpager` as the dedicated pager
2. a small documented `nvim` pager/man-page workflow if that is sufficient
3. fallback to `less` only if editor-as-pager is no longer desired

### Decision criteria

Prefer a Neovim-based pager if it:

- preserves the current "open pager content in an editor" workflow
- works for `PAGER`, `MANPAGER`, and common diff output
- does not depend on the old zplug-era `~/.zplug/bin/vimpager` path

Prefer removal only if:

- the pager workflow is no longer actually used
- Neovim-based replacement adds more complexity than value

## Proposed Migration Sequence

### Phase 1: Cleanup Before Migration

Completed on 2026-03-31:

- stale plugin repos and dead settings were removed from `vim/.vim/config/plugins.vim`
- clearly dead Vim files and stale language-plugin entries were removed
- the pager question remained deferred on purpose

### Phase 2: Define the Neovim Entry Strategy

- decide whether `nvim` becomes the default `EDITOR`
- decide whether to keep sourcing `~/.vimrc` temporarily or start a dedicated
  `init.lua` / `init.vim`
- identify which current plugins are Vim-compatible enough to carry forward

### Phase 3: Pager Migration

- replace `vimpager` with the chosen Neovim-based path
- update `zsh/.zshenv` accordingly
- remove pager-specific Vim plugin config that no longer applies

### Phase 4: Neovim-Native Cleanup

- consider Neovim-native replacements where there is clear payoff
- examples explicitly deferred until then:
  - NERDTree -> oil.nvim or nvim-tree
  - any Lua-only plugin rewrites

## Expected Outcome

After this migration:

- Neovim has an intentional config story instead of a compatibility shim
- pager behavior is explicit and maintained
- old Vim-era sediment is reduced in a way that supports the new editor model
