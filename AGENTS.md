# Dotfiles

Personal dotfiles repo managed with symlinks.

## Key paths

- `agents/.agents/` — public base agent package
  - stowed into `~/.agents`
  - can be merged with the private `~/dev/agents/agents/` package via
    `make agents-enable-private`
  - `skills/` — intentionally empty placeholder in the public repo unless a
    stable public skill is promoted back
