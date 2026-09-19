# Design notes

## Why links and setup are separate

The same dotfiles serve personal desktops, servers, and managed machines.
Portable configuration is useful on all three; permission to install native
packages or manage a desktop session is not.

Each is its own step: `make link` for configuration, `setup-user` for tools and
plugins, `setup` for native packages, `DESKTOP=1` for desktop files, and
`agents-enable-private` for private skills. The command decides what a machine
gets.

Startup uses installed plugins. Zsh sources a prebuilt cache, Neovim leaves
missing plugins alone, and tmux runs TPM only if it is present. Opening a
terminal should not become a package installation.

## File ownership and information isolation

Stow uses `--no-folding`: managed files are symlinks, while containing
directories remain real. A new file under `~/.config/zsh/sources/` therefore
stays on the machine instead of being created inside the public repo. Editing
an existing managed symlink still edits its repository target.

This is also why the link targets reject untracked and ignored files inside
public packages. Git ignoring a file does not stop Stow from linking it.
The ignored `local/` package is the explicit exception; it holds files intended
for this machine. A private repo provides version history for private files
shared across machines.

These layers merge directories, not file contents. A local or private package
cannot replace an existing managed path; configuration hooks provide the places
where application-level overrides belong.

## XDG boundary

The layout stays mixed on purpose. New configuration uses an application's XDG
path when supported; an existing path moves only for a concrete benefit and
with a migration plan.

Neovim, Atuin, mise, and Sheldon use XDG configuration paths. Zsh history uses
XDG state, and user-level npm packages use XDG data. Git is split:
portable behavior under `~/.config/git/`, identity in `~/.gitconfig` so global
writes stay out of the checkout while that local file exists. Tmux uses its XDG
entry point, stores plugins under XDG data, and stores saved layouts under XDG
state. Zsh, Vim, Bash, scripts, and agents keep home-directory entry points by
choice; their generated state can still use XDG paths. The [path
reference](reference.md#configuration-and-state-paths) records where files
actually live.

Stow mirrors package paths literally, so `~/.config` is the supported
configuration root; tools that honor XDG variables for data, state, or cache
do not make the package layout relocatable.

## What pins guarantee

Bootstrap pins verify downloaded bytes and installed payloads for mise,
Sheldon, and vim-plug. Tool versions live in the mise config. Zsh and tmux
plugins have commit pins; Neovim plugins have a checked-in lock. These make
restores reviewable, but they do not make the entire machine reproducible. Vim
plugin branches and native packages still move upstream.

Homebrew remains an explicit prerequisite because its installer can install
Apple tools and fetch additional mutable state. Pinning just that installer
would not pin what it installs. The package phase disables automatic Homebrew
self-update; formula versions remain unpinned.
