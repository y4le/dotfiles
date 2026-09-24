# Set up a machine

Run the commands from the dotfiles checkout. The native package targets cover
Debian/Ubuntu (`apt-get`), Arch (`pacman`), and macOS (Homebrew).

## Prerequisites

Linking requires Git, Make, and GNU Stow 2.3 or newer. `make setup-user` also
assumes curl, tar with gzip support, a SHA-256 tool (`sha256sum`, `shasum`, or
`openssl`), Vim, and tmux 3.1 or newer are available. Native packages supply
Zsh and tmux; user-space tools include Neovim.

If native prerequisites are missing, run `make system-packages` first; it uses
sudo on Linux. On macOS it needs Homebrew (see the next section). On a managed
machine, use the prerequisites supplied by IT.

Keep `XDG_CONFIG_HOME` unset or set to `~/.config`; linking always uses that
directory. See the [path reference](reference.md#configuration-and-state-paths)
for the current layout.

## Set up macOS prerequisites

The repo finds an existing Homebrew installation; it does not install Homebrew.
Keep an IT-managed installation if one is already present.

On a clean Apple Silicon Mac:

1. Install Apple's Command Line Tools with `xcode-select --install`; confirm
   `xcode-select -p` succeeds.
2. Review a [Homebrew release](https://github.com/Homebrew/brew/releases) and
   install its signed `Homebrew.pkg` as below.
3. Run `make system-packages` to install Stow and the other native prerequisites.
4. Run `make setup-user` (`make setup` runs steps 3 and 4 together).

Replace the example version with the release you reviewed. Download the package
and compare the computed SHA-256 with GitHub's asset digest. The digest lookup
below uses the GitHub CLI (`gh`):

```sh
version=7.0.2
curl -fL -o Homebrew.pkg \
  "https://github.com/Homebrew/brew/releases/download/$version/Homebrew.pkg"
shasum -a 256 Homebrew.pkg
gh api "repos/Homebrew/brew/releases/tags/$version" \
  --jq '.assets[] | select(.name == "Homebrew.pkg") | .digest' | \
  sed 's/^sha256://'
pkgutil --check-signature Homebrew.pkg
spctl --assess --type install -vv Homebrew.pkg
```

Once the hashes match and macOS reports an accepted, notarized Developer ID
Installer signature:

```sh
sudo installer -pkg Homebrew.pkg -target /
```

### Intel Macs

The package installer supports Apple Silicon only. Keep a working
`/usr/local/bin/brew` supplied by IT or follow
[Homebrew's installation guidance](https://docs.brew.sh/Installation), including
its current platform requirements.

For an Intel Mac, the checked-in Sheldon pins have no matching binary. Run
`make system-packages` first if the native prerequisites are missing. Install a
trusted Sheldon at `~/.local/bin/sheldon`, then preview the links with
`make link-plan` and run `make mise-tools link plugins`. Do not use `make setup`
or `make setup-user` on this path because both try to install the checked-in
Sheldon binary. The
[pin documentation](../setup/pins/README.md#updating-sheldon) covers that path
and corporate network constraints.

## Link the configuration

```sh
make link-plan
make link
```

The plan changes nothing. It prints the selected packages, links, and conflicts;
[resolve conflicts](maintenance.md#resolve-link-conflicts) before linking.
After linking, `~/.zshrc` and `~/.vimrc` point into the checkout, and directories
such as `~/.config/zsh/` remain real directories.

On macOS, linking preserves an existing `~/.zprofile` as
`~/.zprofile.local` and sources it from the managed profile. The plan reports
this move without changing files. If both profile paths already exist, merge
them yourself before linking.

## Install tools and plugins

```sh
make setup-user
```

This installs user-space tools, links configuration, and restores shell, Vim,
and Neovim plugins. It uses the network but not sudo. Start a new Zsh shell
after it finishes. Herdr is installed from its checksum-pinned release binary.
Use `make herdr` when you only need to install or repair Herdr; the targeted
command also validates the tracked Herdr config.

Herdr's agent integrations write hook files and settings into each agent's own
configuration directory, so they remain an explicit follow-up step. On a host
that uses the default Claude, Codex, and Antigravity CLI integrations, run:

```sh
make herdr-integrations
```

Override the list for a host that uses a subset or another supported target:

```sh
make herdr-integrations HERDR_INTEGRATIONS="claude codex"
```

Rerun the target after updating Herdr so its managed hook versions stay current.

On a machine where native package installation is permitted, use `make setup`
to run `system-packages` followed by `setup-user`.

## Include desktop configuration

On a personal desktop:

```sh
make DESKTOP=1 setup
```

For an existing installation, preview and link with `make DESKTOP=1 link-plan`
and `make DESKTOP=1 link`. This adds Linux X11/i3 files or macOS Karabiner
configuration; it does not install i3 or Karabiner itself.

Pass `DESKTOP=1` when relinking or removing a desktop installation.

## Configure Git identity

After linking:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Portable behavior lives in `~/.config/git/config`, which links into this repo;
identity belongs in the user-owned `~/.gitconfig`. `make link` creates that file
when it is missing and preserves existing local or corporate-managed files.

That local file keeps identity out of the repo. When it is absent, Git writes
`--global` settings into `~/.config/git/config` instead. If `~/.gitconfig` has
been removed, rerun `make link` before setting identity. Git will not guess an
identity; commits fail until an applicable config supplies one.

## Remove the links

```sh
make clean
```

Use `make DESKTOP=1 clean` for a desktop installation. This unstows links from
the selected public and local packages; their source files, installed tools,
downloaded plugins, and runtime data remain. Remove private agent links separately with
`make agents-disable-private` while the private checkout is still available.
