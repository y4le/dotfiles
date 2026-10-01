# Dotfiles cleanup TODO

## Status

Active remaining-work list, updated against the repo state on 2026-09-24.

The [local/private configuration guide](../local-config.md) and
[XDG policy](../design.md#xdg-boundary) cover the former documentation tasks.

## Guardrails

- keep `stow`
- keep `make` as the command surface
- keep `mise` for pinned runtimes and tools
- keep new optional features out of default bootstrap unless explicitly
  enabled; `full` includes every profile component, so use explicit targets or
  flags (such as `herdr-integrations` or `DESKTOP`) for new opt-in features
- prefer small, reviewable changes
- smoke-test bootstrap-affecting changes on a clean machine, container, or VM

The [retirement inventory](retirement-candidates.md) records potential future
removals, their configured use, and checks needed before making a decision.

## Optional follow-ups

Only do these if they prove valuable in practice:

- migrate active wiki content from `vimwiki` markup to org files as needed
- re-evaluate optional Neovim add-backs only if missed in practice:
  `oil.nvim`, `mini.surround`, `mini.ai`, distraction-free writing mode
