# Dotfiles Cleanup Plan

## Status

Active plan, updated against the repo state on 2026-03-31.

Already completed and intentionally excluded from this plan:

- Google Drive sync is implemented via `make gdrive*`, `scripts/bin/gdrive-sync`, and the `gdrive/` stow package
- Vim bootstrap is explicit via `make vim-plugins`, and `make setup` already runs it
- Phase 1 core validation is complete locally: `make check`, `check-shell`, `check-stow`, and `check-make` now exist
- Phase 2 Vim cleanup is complete: moved plugin repos were updated, dead settings and stale language plugins were removed, `resize_mode.vim` was deleted, and pager changes were deferred to the Neovim migration plan

## Problem

The repo is in a much better place than it was before the setup migration:
`stow`, `make`, `mise`, and explicit opt-in features are all the right core
shape.

The remaining issues are mostly maintainability problems:

- validation exists locally but is not yet enforced in CI or backed by a disposable bootstrap smoke test
- the root `Makefile` mixes bootstrap, editor setup, and optional features
- opt-in features have the right idea but not yet a formal repo-wide pattern
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

1. Extend validation into CI and bootstrap smoke tests
2. Split the `Makefile` by concern
3. Standardize the optional-feature pattern
4. Document and tighten local override behavior
5. Decide and document the XDG boundary
6. Plan the future Neovim migration intentionally

## Phase 1: Validation and CI

### Why first

This gives every later cleanup a cheap safety net. Right now validation is done
manually and inconsistently.

### Planned changes

- Keep `make check` as the main local entrypoint
- Keep `make check-shell`
- Keep `make check-make`
- Optionally add `make check-optional`

### Checks to include

- `git diff --check`
- `sh -n` for POSIX shell scripts
- `bash -n` for bash scripts
- `zsh -n` for zsh entrypoints
- `stow -n` / `xstow -n` for package dry-runs
- `shellcheck` where available
- `shfmt -d` where available
- `make -n setup`
- `make -n link-linux`
- `make -n link-macos`
- `make help`

### Policy decisions to make up front

- local `make check` should warn-and-skip when optional linters such as
  `shellcheck` or `shfmt` are missing
- CI should install the full toolchain and fail if any check cannot run
- `make -n` targets should be documented as graph/syntax validation only, not
  proof that bootstrap is functionally correct

### Nice-to-have follow-up

- Add lightweight CI that runs `make check` on Linux
- Add a disposable bootstrap smoke test for `make setup`

### Success criteria

- one command validates the repo’s core behavior
- contributors no longer have to remember the manual check sequence

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

Future editor and pager work now lives in `docs/planning/nvim_migration.md`.

## Phase 3: Makefile Modularization

### Why after validation

Splitting the `Makefile` is worthwhile, but it should happen with checks in
place so the refactor stays safe.

### Planned changes

- Keep the root `Makefile` as the entrypoint
- Use GNU Make `include` with explicit relative paths from the repo root
- Enumerate current targets before moving anything
- Move implementation into included fragments, for example:
  - `mk/bootstrap.mk`
  - `mk/editors.mk`
  - `mk/optional/gdrive.mk`
  - `mk/helpers.mk`

### Shared helpers to extract

- command-availability guards
- package-list loading
- systemd helper patterns
- repeated `curl`-install logic

### Precondition

Before extracting optional-feature fragments, write down the minimal
optional-feature contract so `mk/optional/*.mk` has a known target shape.

### Migration strategy

- move one fragment at a time
- run `make check` after each extraction
- keep `make help` output stable throughout the refactor
- do not extract shared helpers until at least two call sites actually need the
  same abstraction

### Design rule

The top-level `Makefile` should read like a command index, not an implementation
dump.

### Success criteria

- optional features are not interleaved with bootstrap internals
- related logic lives together
- adding a new optional feature does not further bloat the root file

## Phase 4: Optional Feature Contract

### Why

`gdrive` is the right direction, but the repo should make optional subsystems
feel uniform.

### Standard pattern

For an opt-in feature:

- helper script in `scripts/bin/`
- stow package only if the feature needs tracked files in `$HOME`
- local config under `~/.config/<feature>/`
- explicit `make` targets only
- never part of default `make setup`

### Minimal target surface

Not every optional feature needs every target. The minimal contract is:

- `<feature>` or `<feature>-status` if the feature has a meaningful runtime
  action or state check
- `<feature>-enable` and `<feature>-disable` only if the feature manages a
  service or linked files
- `<feature>-auth` only if the feature has a one-time auth flow
- `<feature>-install` only if the binary is intentionally outside default
  bootstrap

### Discovery and templates

- Add a short template for creating new optional features
- Decide how optional features are discovered by checks and docs:
  - naming convention only
  - or a small manifest/registry if the feature set grows

The initial version should prefer naming convention over a registry unless the
repo actually needs the extra indirection.

### Candidate adopters

- `gdrive` as the reference implementation
- future `syncthing` work should follow the same contract

### Success criteria

- new optional features look structurally familiar
- local-only state and tracked repo state are clearly separated

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

1. Add lightweight CI for `make check`
2. Add a disposable bootstrap smoke test for `make setup`
3. Write down the optional-feature contract that Makefile fragments should
   conform to
4. Split the `Makefile`
5. Normalize optional-feature conventions in code and docs
6. Document local override policy
7. Decide and document the XDG boundary

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
