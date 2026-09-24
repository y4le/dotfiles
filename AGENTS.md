# Dotfiles

Personal dotfiles repo managed with symlinks.

## Key paths

- `agents/.agents/` — public base agent package
  - stowed into `~/.agents`
  - can be merged with the private `~/dev/agents/agents/` package via
    `make agents-enable-private`
  - `skills/` — intentionally empty placeholder in the public repo unless a
    stable public skill is promoted back

## Working on setup

- `setup/profiles.yaml` owns membership for profile-controlled Stow packages
  and mise tools. Assign new packages and tool keys to a component, preserve
  its fixed YAML shape, and update `mk/test-profiles.sh` when full or lite
  membership changes. See [profile maintenance](docs/maintenance.md#add-a-package-tool-or-component).
- Keep native packages, `DESKTOP`, `local/`, and the private agent overlay
  separate from profiles. The ignored `profile.mk` and `local/` are
  machine-local; do not edit them to change public defaults.
- Pass `PROFILE`, `WITH`, and `DESKTOP` as Make arguments, not shell environment
  variables. Preview with `make plan`, keep docs in sync with Make behavior,
  and run `make check` before committing.

## Agent collaboration

For substantial or consequential work, consult another model family. Codex
uses Claude Opus for routine consultation and diff review, and Claude Fable
for the hardest questions. Claude uses Codex Sol and Astra respectively. Have
the opposite-family reviewer inspect the actual nontrivial diff and validation
before committing; a Fable or Astra review counts. One review can cover a
coherent series. Treat reviewer claims as hypotheses and verify consequential
ones. If a model is unavailable, report that limit rather than silently
substituting or calling self-review independent. Record substantive
disagreements in the commit message. The
[collaboration reference](../ref/agents_collaboration.md) has more detail when
that separate checkout is present.

## Commit messages

Write commit messages so someone reading the log can understand what changed
and why. Use a specific subject that describes the result. For nontrivial
changes, add a body explaining the previous behavior or problem, the change,
and the reason for it. Give important, broad, or surprising changes more
context; a small, obvious change may need only a subject. Explain distinct
changes in a mixed commit without turning the body into a file-by-file list.
Do not invent motivations that the request, code, or tests do not support.
