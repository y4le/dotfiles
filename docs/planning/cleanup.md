# Dotfiles Cleanup TODO

## Status

Active remaining-work list, updated against the repo state on 2026-04-05.

Completed migration and review notes were removed so this file only tracks work
that is still open.

## Guardrails

- keep `stow`
- keep `make` as the command surface
- keep `mise` for pinned runtimes and tools
- keep optional features out of default bootstrap unless explicitly enabled
- prefer small, reviewable changes
- smoke-test bootstrap-affecting changes on a clean machine, container, or VM

## Priority Order

1. document the local/private overlay contract
2. document the XDG boundary
3. revisit low-priority editor and desktop follow-ups only if they still matter

## TODO

### Local and Private Overlay Contract

The repo already has override hooks, but the contract is still implicit.

Current hooks:

- `~/.zshenv.local`
- `~/.pre_profile`
- `~/.post_profile`
- `~/.tmux.local.conf`
- `~/.config/nvim/lua/local/init.lua`
- `~/.vim/config/*.local.vim`

Remaining work:

- document which hook is for what
- define what belongs in tracked dotfiles vs a private overlay vs machine-local
  files
- keep tracked config portable and machine-agnostic by default
- preserve ordering-sensitive hooks only where the load order is doing real work

Suggested deliverable:

- one short doc that explains tracked config, private tracked config, and
  machine-local untracked config

Success criteria:

- there is one obvious place for machine-specific shell changes
- future config additions default to portable tracked config

### XDG Boundary

The repo still mixes XDG-native config with legacy home-dotfile layouts.

Remaining work:

- decide whether to keep the mixed model explicitly or start an incremental
  migration with compatibility shims
- write `docs/xdg_policy.md`
- classify each major subsystem as:
  XDG-native, intentionally legacy, or candidate for later migration

Recommendation:

- do not do a full XDG migration as part of cleanup
- document the current boundary first and only migrate a subsystem when there is
  a concrete benefit

Success criteria:

- the repo has an explicit policy instead of an accidental mix

### Optional Follow-Ups

Only do these if they prove valuable in practice:

- migrate active wiki content from `vimwiki` markup to org files as needed
- re-evaluate optional Neovim add-backs only if missed in practice:
  `oil.nvim`, `mini.surround`, `mini.ai`, distraction-free writing mode
- migrate the Linux rofi config to the newer rasi format when that config is
  touched next
