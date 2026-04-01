# Dotfiles Cleanup Plan

## Status

Active plan, updated against the repo state on 2026-03-31.

Already completed and intentionally excluded from this plan:

- Google Drive sync is implemented via `make gdrive*`, `scripts/bin/gdrive-sync`, and the `gdrive/` stow package
- Vim bootstrap is explicit via `make vim-plugins`, and `make setup` already runs it
- Phase 1 validation is in place: `make check`, `check-shell`, `check-stow`, and `check-make` exist locally, GitHub Actions runs `make check` on Linux and macOS, and a Linux `make setup` smoke job validates bootstrap in a clean `HOME`
- Phase 2 Vim cleanup is complete: moved plugin repos were updated, dead settings and stale language plugins were removed, `resize_mode.vim` was deleted, and pager changes were deferred to the Neovim migration plan
- Phase 3 Makefile modularization is complete: the root `Makefile` is now an index with explicit include order and implementation moved into `mk/*.mk`
- Phase 4 optional feature contract is complete: optional features live under `mk/optional/`, stay out of `make setup`, and `gdrive` is the reference implementation

## Problem

The repo is in a much better place than it was before the setup migration:
`stow`, `make`, `mise`, and explicit opt-in features are all the right core
shape.

The remaining issues are mostly maintainability problems:

- local override points exist, but the contract is not documented cleanly
- XDG usage is mixed without a deliberate boundary

None of this calls for a rewrite. The right move is incremental cleanup around
the current architecture.

## Goal

Improve maintainability, reviewability, and change safety without changing the
core model:

- keep `stow`
- keep `make` as the command surface
- keep `mise` for pinned tools/runtimes
- keep optional features out of default bootstrap unless explicitly enabled

## Non-Goals

- replacing `stow` with another dotfiles manager
- migrating fully to Neovim in this pass
- full XDG migration in one change
- redesigning shell/editor workflows from scratch

## Cross-Cutting Constraints

- each phase should be reviewable and revertable on its own
- phases that affect bootstrap should be smoke-tested on a clean machine,
  container, or VM before merge
- default assumption is one PR per phase unless a phase clearly needs to be
  split further
- dry-runs are useful, but they do not prove that a full bootstrap actually
  works

## Priorities

1. Document and tighten local override behavior
2. Decide and document the XDG boundary
3. Normalize optional-feature conventions in docs and future code
4. Revisit remaining editor follow-ups only if they prove valuable in practice

## Phase 1: Validation and CI

### Status

Completed on 2026-03-31.

### Completed work

- `make check` is the main local entrypoint
- `make check` runs in GitHub Actions on Linux and macOS
- the CI smoke job runs `make setup` on Linux in a clean `HOME`
- local `make check` still warns and skips optional linters when they are not installed
- CI installs the full toolchain so checks run in enforced mode

### Notes

- `make -n` targets remain graph and syntax validation, not proof that bootstrap is functionally correct
- bootstrap smoke coverage is currently Linux-only; add macOS smoke later only if the extra runtime is worth it

## Phase 2: Vim Cleanup

### Status

Completed on 2026-03-31.

### Completed work

- updated moved plugin repos for `ale`, `nerdtree`, and `tagbar`
- removed orphaned `gutentags`, YCM, and EasyMotion settings
- removed stale Ruby, CoffeeScript, and Lisp plugin entries
- deleted the dead `vim/.vim/plugin/resize_mode.vim` file
- kept `vimpager` in place and deferred pager migration to the Neovim plan

### Follow-on

Remaining editor follow-ups, including the pager decision, now live in
`docs/planning/nvim_migration.md`.

## Phase 3: Makefile Modularization

### Status

Completed on 2026-03-31.

### Completed work

- the root `Makefile` remains the repo entrypoint
- implementation moved into concern-specific files under `mk/`
- include order is explicit rather than wildcard-based
- validation, bootstrap, tools, editors, overlays, optional features, and
  cleanup no longer share one large file

### Result

The root `Makefile` now reads as a command index and include list rather than
an implementation dump.

## Phase 4: Optional Feature Contract

### Status

Completed on 2026-03-31.

### Completed work

- optional features are grouped under `mk/optional/`
- optional targets stay discoverable through `make help`
- optional features remain outside default `make setup`
- `gdrive` is now the reference optional feature layout

### Current contract

For an opt-in feature:

- keep the feature out of default bootstrap
- give it explicit `make` targets
- keep tracked files in a stow package only if the feature needs files in
  `$HOME`
- place feature-specific target definitions in `mk/optional/<feature>.mk`

## Phase 5: Local Override Contract

### Why

The repo already supports local overlays, but the rules are implicit and spread
across subsystems.

### Current override points

- `~/.zshenv.local`
- `~/.pre_profile`
- `~/.post_profile`
- `vim/.vim/config/plugins.local.vim`

### Planned changes

- Document which file is for what
- Ensure tracked files stay portable and machine-agnostic
- Push machine-specific values into local overlays by default
- Prefer one local override hook per subsystem where possible
- Keep ordering-sensitive hooks such as `~/.pre_profile` and `~/.post_profile`
  separate if the load order is still doing real work

### Documentation target

Add a short doc that explains:

- what belongs in tracked dotfiles
- what belongs in ignored local overlays
- what should never be tracked

### Success criteria

- there is one obvious place for machine-specific shell changes
- future config additions default to portable tracked config

## Phase 6: XDG Boundary

### Why last

This is the largest policy question and the easiest place to create churn for
limited immediate payoff.

### Decision to make

Either:

- keep a deliberate mixed model and document it

or

- start an incremental XDG migration with compatibility shims

### Recommendation

Do not attempt a full migration as part of cleanup. First document the current
boundary and only migrate a subsystem when there is a concrete benefit.

### Deliverable

Create one explicit policy artifact, for example:

- `docs/xdg_policy.md`

That document should list each major subsystem as:

- already XDG-native
- intentionally legacy
- candidate for later migration

### Likely boundary if we keep the mixed model

- modern tools continue to live under `~/.config`
- legacy tools like Vim continue using home-dotfile conventions until there is
  a separate migration plan

### Success criteria

- the repo has an explicit policy instead of an accidental mix

## Recommended Execution Order

1. Normalize optional-feature conventions in docs and future code
2. Document local override policy
3. Decide and document the XDG boundary

## External Review Notes

Claude and Gemini both agreed that the plan is structurally strong and that
validation-first is the right opening move.

The main additions from external review were:

- define the missing-tool policy for `make check`
- add `stow -n` validation and a clean-machine bootstrap smoke test
- make the Vim review items less open-ended by adding explicit criteria
- make the Makefile split more concrete before execution
- keep load-order-sensitive local hooks if they still serve a purpose
- create one explicit XDG policy artifact instead of leaving the decision
  implicit

## Expected Outcome

After this cleanup:

- changes should be easier to validate before commit
- the bootstrap surface should stay readable as new optional features land
- local-machine customization should be less ad hoc
- the remaining “old dotfiles sediment” should be isolated to conscious choices
  instead of drift
