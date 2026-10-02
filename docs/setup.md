# Set up a machine

Run the commands from the dotfiles checkout. The native package targets cover
Debian/Ubuntu (`apt-get`), Arch (`pacman`), and macOS (Homebrew).

## Prerequisites

Linking requires Git, Make, and GNU Stow 2.3 or newer. `make setup-user` also
assumes curl, tar with gzip support, a SHA-256 tool (`sha256sum`, `shasum`, or
`openssl`), Vim, and tmux 3.3 or newer are available; tmux 3.4 enables every
configured feature. Neovim parser builds also need a C compiler. The Debian
native packages include one; on macOS, install Apple's Command Line Tools.
Native packages supply Zsh, tmux, `jq` for Herdr, and `shellcheck` for Neovim
shell linting. The `nvim` component installs Neovim in user space.

If native prerequisites are missing, run `make system-packages` first; it uses
sudo on Linux. On macOS it needs Homebrew (see the next section). On a managed
machine, use the prerequisites supplied by IT.
On Debian, install Git, Make, and sudo with administrator access before running
these Make targets; a minimal server install may not include them. After setup,
run `chsh -s /usr/bin/zsh` if SSH logins should use the managed Zsh config.

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
3. Add Homebrew to your shell's `PATH` with
   `eval "$(/opt/homebrew/bin/brew shellenv)"`.
4. Run `make system-packages` to install Stow and the other native prerequisites.
5. Run `make setup-user` (`make setup` runs steps 4 and 5 together after step 3).

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
trusted Sheldon at `~/.local/bin/sheldon`, [choose a profile](#choose-a-profile)
if needed, then preview the links with
`make link-plan`. For `full` or lite with Herdr, run
`make mise-tools herdr link plugins`; for lite without Herdr, run
`make mise-tools link plugins`. Do not use `make setup` or `make setup-user`
on this path because both try to install the checked-in Sheldon binary. The
[pin documentation](../setup/pins/README.md#updating-sheldon) covers that path
and corporate network constraints.

## Choose a profile

The default `full` profile installs the everyday editor and terminal setup. For a smaller setup, save `lite` (core shell, Git, Vim, tmux, scripts,
agents, mise, and five everyday CLI tools), optionally adding components:

```sh
make profile-set PROFILE=lite WITH="yazi nvim"
make profile
```

`make packs` lists available packs and their preset membership.
`make pack NAME=nvim` shows one pack's payload and restore steps. Both commands
work even when a saved selection is stale.

`make profile-set` writes an ignored `profile.mk` in this checkout. `WITH` can
contain `atuin`, `yazi`, `nvim`, `herdr`, `node`, `web-dev`, `python-dev`,
`go-dev`, `rust-dev`, and `dev`; see
[`setup/profiles.yaml`](../setup/profiles.yaml) for their exact packages and
tools. Pass `PROFILE` and `WITH` as Make arguments, such as
`make PROFILE=lite WITH=yazi plan`; setting them in the shell environment is
ignored. A command-line choice applies only to that command. Repeat it for
each command if you do not save a choice: a plain `make setup-user` after that
preview would use the saved or default profile instead. Saving requires both
`PROFILE` and `WITH`; use `WITH=""` to clear saved
add-ons explicitly. The save reports the previous and new selection and dropped
packs. Pass `WITH=` to drop saved add-ons for one command. To return to the
default full setup, run
`make profile-set PROFILE=full WITH=""`, then `make plan` and `make setup-user`.

The default `full` profile contains core, Atuin, Yazi, Neovim with LuaLS,
Herdr, and Node for locally installed CLIs such as npm-installed Codex and
Gemini. Language development runtimes and servers are optional; `dev` restores the
previous broad development tool selection for compatibility. Profiles select
Stow links, mise tools, and plugin steps; `make setup` still installs the same
native package list for the platform. Use `make setup-user` when native
prerequisites are already available. `DESKTOP=1` independently selects the
platform's desktop links; it is not saved by `profile-set`, so pass it each
time you link desktop files. `local/` and private agent links remain separate.

## Enable optional tools

Save the packs you need before linking. `full` already includes the Node
runtime needed by npm-installed Codex, Gemini, and other local CLIs. To add
that runtime to `lite` without web development tools:

```sh
make profile-set PROFILE=lite WITH=node
make plan
make mise-tools
make link
```

`WITH` replaces the complete saved add-on list. For example, use
`PROFILE=full WITH=python-dev` for the everyday setup plus Python development,
or `PROFILE=lite WITH="node python-dev"` for a smaller setup with both runtimes.
Use `WITH=dev` to retain all previous language
tools. On a fresh machine, use `make setup-user` after saving and previewing.

To enable Yazi on a machine that omitted it, run `make profile` to inspect the
current profile and add-ons. Keep that profile and the complete existing
`WITH` list when adding `yazi`. For example, if the output shows `profile: lite`
and `add-ons: node`:

```sh
make profile-set PROFILE=lite WITH="node yazi"
make plan
make setup-user
```

This retains Node, installs Yazi, and activates both. If your selection already
includes Yazi (as `full` does), run `make setup-user` to install the missing
tool. `make WITH=yazi mise-tools` installs selected tools without activating
the pack or saving your selection.

| Pack | Tools and behavior |
| --- | --- |
| `node` | Node runtime for locally installed CLIs, included in `full`; no language server |
| `web-dev` | Node and TypeScript language server; the project supplies its TypeScript dependency |
| `python-dev` | Python, uv, basedpyright, and Ruff; enables Python LSP, linting, and formatting |
| `go-dev` | Go compiler and standard tools; no Go language server is configured |
| `rust-dev` | Rust toolchain with rust-analyzer and rustfmt; enables Rust LSP and formatting |
| `dev` | Compatibility bundle of all the above plus LuaLS |

LuaLS belongs to `nvim` and is included in `full`. Shared tools install once:
selecting both `node` and `web-dev` uses one Node pin, and removing `web-dev`
retains Node while `node` remains selected. JavaScript/TypeScript LSP formatting
requires `web-dev` or an independently configured usable language server.

Versions and options live in `setup/tools.toml`. `make mise-tools` installs the
selected catalog pins; `make link` activates them through
`~/.config/mise/conf.d/dotfiles.toml`. Omitted tools remain installed and can be
activated by project or machine-local configuration. Avoid `mise use -g`: the
global settings file is a symlink into the checkout. Put machine overrides in
`~/.config/mise/config.local.toml` instead. Occasional commands still use local
setup; a Haskell pack waits for a concrete provider and machine need.

## Preview the configuration

```sh
make plan
```

The plan changes nothing. It prints the selected tools, plugin steps, packages,
links, conflicts, missing selected installations, and installed tools outside
the selection; [resolve conflicts](maintenance.md#resolve-link-conflicts)
before applying the configuration. When changing from full to lite, it also
previews removal of managed add-on links. Run `make PLAN_VERBOSE=1 plan` for the
full Stow trace. Use `make link-plan` for a link-only preview.

To apply only the links without installing tools or plugins, run `make link`.
It removes unselected managed add-on links, but leaves installed tools, plugins,
runtime data, and user-owned files alone. A retained mise shim needs a selected,
project, or local pin to work. `make setup-user` in the next section
also links the configuration, so there is no need to run `make link` first.
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

This first checks ownership conflicts for the derived mise file, then installs
selected user-space tools, links configuration, and restores the
selected shell and editor plugins. It uses the network but not sudo. Start a
new Zsh shell after it finishes. When selected, Herdr is installed from its
checksum-pinned release binary. Use `make herdr` when you only need to install
or repair Herdr; the targeted command also validates the tracked Herdr config.

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

On Arch, `system-packages` uses `pacman -Syu --needed`: it refreshes package
databases and performs a full system upgrade while installing prerequisites.
Pacman's confirmation prompt remains enabled. See the
[pacman manual](https://archlinux.org/pacman/pacman.8.html) for these options.

## Include desktop configuration

On a personal desktop:

```sh
make DESKTOP=1 setup
```

For an existing installation, preview and link with `make DESKTOP=1 link-plan`
and `make DESKTOP=1 link`. This adds Linux X11/i3 files or macOS Karabiner
configuration; it does not install i3 or Karabiner itself.

Pass `DESKTOP=1` when relinking a desktop installation.

### Linux desktop dependencies

`DESKTOP=1` selects configuration links. Install the X11 desktop and these
runtime commands separately; profiles and the base native package target do
not install the complete desktop stack.

| Commands | Used by | Provider or dependency |
|---|---|---|
| `i3`, `i3-msg` | Window manager and workspace picker | i3 (typically `i3-wm`) |
| `kitty` | Terminal binding and `TERMINAL` | Kitty |
| `rofi` | Launcher and workspace picker | Rofi 1.6+ (row metadata) |
| `rofimoji`, `xdotool`, `xclip` or `xsel` | Emoji picker, typing, and clipboard actions | Rofimoji plus X11 typing/clipboard backends |
| `pactl` | Volume bindings | Debian/Ubuntu `pulseaudio-utils`; Arch `libpulse`; a running PulseAudio-compatible server, such as PipeWire-Pulse |
| `playerctl` | Media bindings and the configured Spotify blocklet | Playerctl and an MPRIS-capable player |
| `i3blocks` | Status bar | i3blocks plus the [blocklet scripts below](#linux-status-bar-scripts) |
| `xss-lock`, `xsecurelock`, `xset` | Manual, idle, and suspend locking | See [locking setup](reference.md#linux-desktop-locking) |
| `dex` | XDG application autostart | dex |
| `pkill` | Caps/Num Lock indicator updates | Debian/Ubuntu `procps`; Arch `procps-ng` |
| `xsetroot` | Optional background colour in `.xsessionrc` | Debian/Ubuntu `x11-xserver-utils`; Arch `xorg-xsetroot` |
| Bash, POSIX shell, `jq` | Workspace and media helper scripts | Shell packages; jq is supplied by the base native package lists |

Some distributions do not package `rofimoji`, including
[Ubuntu 24.04](https://packages.ubuntu.com/search?keywords=rofimoji&searchon=names&suite=noble&section=all).
Install Python and pipx separately there, then follow the
[upstream PyPI instructions](https://github.com/fdw/rofimoji#installation):

```sh
pipx install rofimoji
```

Keep `~/.local/bin` on the i3 session's PATH, and install an emoji-capable font.
The supplied `.xsessionrc` is read by Debian-style Xsession; other display
managers may need their own session hook. A missing `xsetroot` skips the
optional background change; a failed invocation reports a diagnostic and
allows the rest of the session settings to load.

The enabled Caps Lock block runs at startup and refreshes on Caps/Num Lock
key release in i3's default binding mode. The commented Num Lock block is an
optional additional display; give it `instance=NUM`, `interval=once`, and
`signal=11` when enabling it. Reload i3 and restart i3blocks after changing
these configurations, then check the indicator with the actual keyboard
mapping. See the [locking instructions](reference.md#linux-desktop-locking)
for changes that require logging out and back in.

The media block uses playerctl for the MPRIS player named by `instance`
(default `spotify`). Buttons 1/2/3 select previous/play-pause/next; scrolling
adjusts volume. No player running produces no text; missing playerctl is
visible in the bar. Separate mpc/cmus/rhythmbox adapters are retired.

The workspace script is supplied at `~/bin/i3_switch_workspaces.sh`;
`i3-msg` comes with the window manager. Its `empty (new workspace)` action
creates the first unused number from 1 through 10 and reports exhaustion. Rofi metadata
separates that action from a workspace actually named `empty`; typed text
selects a literal name. Existing names remain intact. Numeric keybindings
reuse workspaces by number, including ones created or renamed by the picker.
Workspace names containing newlines are outside the line-based picker contract.

### Linux status-bar scripts

Install i3blocks separately. Its legacy Debian package includes scripts under
`/usr/share/i3blocks`; the [current Arch package file list](https://archlinux.org/packages/extra/x86_64/i3blocks/files/)
contains no blocklets. The runtime wrapper also checks user/system libexec
directories, `/usr/lib/i3blocks`, and flat or nested
`/usr/share/i3blocks-contrib` layouts. Set `I3BLOCKS_SCRIPT_DIR` in the i3
session environment to use one explicit directory instead.

With i3blocks 1.5 or newer, install the six scripts used by this configuration
from the [official contrib repository](https://github.com/vivien/i3blocks-contrib).
This example checks out a fixed source revision; review it before installation:

```sh
mkdir -p "$HOME/.local/src"
git clone https://github.com/vivien/i3blocks-contrib.git "$HOME/.local/src/i3blocks-contrib"
git -C "$HOME/.local/src/i3blocks-contrib" checkout --detach 9d66d81da8d521941a349da26457f4965fd6fcbd
install -d "$HOME/.local/libexec/i3blocks"
for block in memory disk iface bandwidth cpu_usage keyindicator; do
  install -m 755 "$HOME/.local/src/i3blocks-contrib/$block/$block" \
    "$HOME/.local/libexec/i3blocks/$block"
done
```

These scripts need Bash, Perl, `ip` (iproute2), `bc`, `mpstat` (sysstat), and
`xset` (Debian's x11-xserver-utils or Arch's xorg-xset), in addition to the
usual core utilities. Install those desktop dependencies manually; the base
native package target does not supply them. Existing `instance=swap`, disk
paths, and network interfaces remain supported by the selected contrib
revision. Memory formatting can differ from the legacy scripts. Restart
i3blocks after installing scripts; a missing script displays `[missing name]`
in the bar and reports the dependency on stderr.

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

This unstows links from all known public, desktop, and local packages even if
the current profile differs from the one used to link them. Their source
files, installed tools, downloaded plugins, and runtime data remain. Remove
private agent links separately with `make agents-disable-private` while the
private checkout is still available.
