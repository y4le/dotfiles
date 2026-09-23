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
make link-plan
make link
```

Review the plan before linking. This step is offline; shell and editor config
remain usable before optional plugins are restored. Keep the checkout in place;
the links point into it.

Run `make setup-user` to install tools and plugins without sudo, or `make setup`
to install native packages too. Bootstrap downloads (Herdr, mise, Sheldon, vim-plug)
are version-pinned and checksum-verified. Use `DESKTOP=1` only where these
dotfiles should manage the Linux X11/i3 session or macOS Karabiner configuration.
Read the [setup guide](docs/setup.md) for prerequisites, Git identity, and the
Intel Mac workaround.

## Documentation

- [Set up a machine](docs/setup.md): install, choose desktop configuration,
  configure Git identity, or remove links.
- [Keep local and private configuration](docs/local-config.md): add machine
  overrides and enable the private agent package.
- [Configuration reference](docs/reference.md): packages, Make targets, startup
  order, local hooks, and file locations.
- [Maintain the dotfiles](docs/maintenance.md): restore plugins, update
  Neovim pins, resolve link conflicts, and migrate older installs.
- [Design notes](docs/design.md): why setup is explicit, how local files stay
  local, and where the XDG boundary sits.
- [Update download pins](setup/pins/README.md): review and verify bootstrap
  artifacts and Zsh plugin revisions.

`make help` lists all targets and labels network access and sudo requirements.
