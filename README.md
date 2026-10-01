# Dotfiles

This is my dotfiles.

There are many like it, but this one is mine.

My dotfiles is my best friend.

It is my life.

I must master it as I must master my life.

## Installation

With Git, Make, and GNU Stow 2.3 or newer installed:

```sh
git clone https://github.com/y4le/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
```

The default `full` profile keeps the existing setup. `lite` links the core
shell, Git, Vim, tmux, scripts, and agent configuration, and selects fzf,
ripgrep, bat, delta, and zoxide for installation. To choose a smaller
setup, optionally save `lite` with any add-ons before linking:

```sh
make profile-set PROFILE=lite WITH=yazi
```

Preview the selected configuration, then install the user-space tools, links,
and plugins:

```sh
make plan
make setup-user
```

Review the plan before setup. To apply only the links, run `make link` instead;
that step is offline, and shell and editor config remain usable before optional
plugins are restored. Keep the checkout in place; the links point into it.

[`setup/profiles.yaml`](setup/profiles.yaml) lists each component's Stow
packages and mise tools. `make packs` discovers packs; `make pack NAME=nvim`
describes one payload. `make profile` shows the resolved selection; a saved
choice applies to later Make commands in this checkout.

Profiles select links, tool installs, and plugin steps; they do not change the
native package lists. See the [setup guide](docs/setup.md#choose-a-profile)
for one-command overrides and switching back to `full`.

`make setup-user` needs no sudo; use `make setup` to install native packages too.
Bootstrap downloads (Herdr, mise, Sheldon, vim-plug)
are version-pinned and checksum-verified. Use `DESKTOP=1` only where these
dotfiles should manage the Linux X11/i3 session or macOS Karabiner configuration.
Read the [setup guide](docs/setup.md) for prerequisites, Git identity, and the
Intel Mac workaround.

## Documentation

- [Set up a machine](docs/setup.md): choose a profile, install, configure a
  desktop or Git identity, and remove links.
- [Keep local and private configuration](docs/local-config.md): add machine
  overrides and enable the private agent package.
- [Configuration reference](docs/reference.md): profile packages and targets,
  startup order, local hooks, and file locations.
- [Maintain the dotfiles](docs/maintenance.md): switch profiles, restore
  plugins, update pins, resolve link conflicts, and migrate older installs.
- [Design notes](docs/design.md): why setup is explicit, how local files stay
  local, and where the XDG boundary sits.
- [Update download pins](setup/pins/README.md): review and verify bootstrap
  artifacts and Zsh plugin revisions.

`make help` lists all targets and labels network access and sudo requirements.
