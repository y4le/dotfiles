# Dotfiles

This is my dotfiles.

There are many like it, but this one is mine.

My dotfiles is my best friend.

It is my life.

I must master it as I must master my life.


## Installation

- clone from git
- navigate into directory
- run `make link` first; it is offline and only links portable configuration
- run `make setup-user` to install user-space tools and plugins without sudo
- run `make setup` when the machine also permits native package installation
- use `make DESKTOP=1 setup` only on a personal desktop where the repository
  should manage the Linux X11/i3 session or macOS Karabiner configuration
- use `make help` to see the other setup and link targets

`make help` labels targets that require network access or sudo. Shell and tmux
remain usable after the link-only step; missing plugins are restored only by
the explicit networked plugin targets.

The offline link step requires GNU Stow 2.3 or newer. `setup-user` assumes Git,
curl, tar with gzip support, a SHA-256 tool (`sha256sum`, `shasum`, or `openssl`),
Vim, and Stow are already available; `setup` installs native prerequisites before
running the same user-space phases. The mise and Sheldon bootstrap archives are
version-pinned and checksum-verified before installation.

`make tools` converges its managed binaries to the reviewed pins. If a managed
binary has been self-updated, the next run reports and replaces that drift.
`make plugins` expects `make tools` to have completed; it never installs missing
tool binaries implicitly.

Sheldon 0.8 does not publish an Intel macOS binary. On those machines, follow the
documented workaround in `setup/pins/README.md` before running `make plugins`.

The desktop choice is also used by `link`, `link-linux`, `link-macos`, and
`clean`. Pass the same `DESKTOP=1` setting when removing a desktop install.
Existing installs from before the core/desktop split should run
`make DESKTOP=1 link` once to migrate their managed desktop links.

### Git identity

Portable Git behavior lives in `~/.config/git/config`. `make link` creates a
separate, user-owned `~/.gitconfig` when one does not already exist, so identity
does not live in or write through to this repository while that local file is
present. Rerun `make link` if it is removed. Configure each machine after
linking:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Git will not infer an identity; commits fail until one is configured in an
applicable config. Existing local or corporate-managed `~/.gitconfig` files are
preserved. A legacy link to this repo's old `git/.gitconfig` is replaced with an
empty local file, so its identity must be configured again. Keep
`XDG_CONFIG_HOME` unset or set to `~/.config` so Git reads the portable config.


## Information Isolation

Machine- or company-specific files belong in the ignored top-level `local/`
Stow package or directly in the real directories under `~`. When `local/`
exists, the Make targets include it automatically. Run `make link-plan` before
linking; the public packages reject ignored or untracked runtime files so they
cannot be linked into `HOME` accidentally.

Because linking uses no-folding mode, files created directly under directories
such as `~/.config/zsh/sources/` remain local instead of being written through
into this repository. Anything that hints at company information should stay
outside the public packages.

| company info that would go here   | instead goes here                                   |
|:----------------------------------|:----------------------------------------------------|
| `~/.zshrc`                        | `local/.config/zsh/sources/corp.zsh`                 |
| `~/.vimrc`                        | `local/.vim/config/{plugins,maps,settings}.local.vim` |
| `~/.example_corp_config`          | `local/.example_corp_config`                         |


## Agents

- the public repo now keeps a minimal base package in `agents/.agents/`
- an optional private repo can live at `~/dev/agents`
- the private repo should expose its own `agents/.agents/skills/` package
- active skills like `parley` now live in the private repo
- preview the private layer with `make agents-plan-private`
- enable the private layer with `make agents-enable-private`
- disable the private layer with `make agents-disable-private`
- both repos use Stow's multi-directory support to share the same target path:
  `~/.agents/skills/`


## Vim
  - `~/.vimrc` calls into 3 subfiles in `~/.vim/config/`
    - plugins (load and install plugins, do plugin config)
    - settings (configure built in settings)
    - maps (set up user defined maps)
  - local modifications
    - changes to plugins/settings/maps should go in e.g. `~/.vim/config/plugins.local.vim`
    - functions should go in `~/.vim/autoload/` - sourced on first use
    - self contained chunks can go in `~/.vim/plugin/` - always sourced
    - filetype specific plugin lives in `~/.vim/ftplugin/language.vim`
  - VimWiki defaults to `~/vimwiki`; set `VIMWIKI_ROOT` for a machine-specific
    absolute location, or set `g:vimwiki_root` before plugins load to override
    it in Vim


## Zsh
  - order of operations
    - `~/.zshenv`
      - runs in _all_ shells, even background
      - has cheap stuff we always want e.g. $EDITOR $PAGER $PATH
    - `~/.zshenv.local`
      - local version of `~/.zshenv`
    - `~/.pre_profile`
      - local modifications to `~/.zshrc` that run before
    - `~/.zshrc`
      - runs in interactive shells
      - has most config that should apply to all machines
    - `~/.config/zsh/sources/*`
      - all files in this dir are sourced within zshrc
    - `~/.post_profile`
      - local modifications to `~/.zshrc` that run after
  - local modifications
    - prefered method is to add new file in `~/.config/zsh/sources/`
    - `~/.pre_profile`/`~/.post_profile`/`~/.zshenv.local` are available if
      necessary
