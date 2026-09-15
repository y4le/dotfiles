# Dotfiles

This is my dotfiles.

There are many like it, but this one is mine.

My dotfiles is my best friend.

It is my life.

I must master it as I must master my life.


## Installation

- clone from git
- navigate into directory
- run `make setup`
- use `make help` to see the other setup and link targets

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

You work for a company, `foo`, and you want to keep their information in a private git server
- create a new `foo/` directory, `stow -t ~ foo` will symlink its contents to `~`
- consider adding `foo/` to `.gitignore` in the public repo to prevent accidental publishing
- anything that hints at company info should be in `foo/`

| company info that would go here   | instead goes here                                   |
|:----------------------------------|:----------------------------------------------------|
| `~/.zshrc`                        | `foo/.config/zsh/sources/foo.zsh`                   |
| `~/.vimrc`                        | `foo/.vim/config/{plugins,maps,settings}.local.vim` |
| `~/.example_foo_config`           | `foo/.example_foo_config`                           |


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
