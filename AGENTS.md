# Dotfiles

Personal dotfiles repo managed with symlinks.

## Key paths

- `agents/.agents/` — public base agent package
  - stowed into `~/.agents`
  - can be merged with the private `~/dev/agents/agents/` package via
    `make agents-enable-private`
  - `skills/` — intentionally empty placeholder in the public repo unless a
    stable public skill is promoted back

## Commit messages

Write commit messages so someone reading the log can understand what changed
and why. Use a specific subject that describes the result. For nontrivial
changes, add a body explaining the previous behavior or problem, the change,
and the reason for it. Give important, broad, or surprising changes more
context; a small, obvious change may need only a subject. Explain distinct
changes in a mixed commit without turning the body into a file-by-file list.
Do not invent motivations that the request, code, or tests do not support.
