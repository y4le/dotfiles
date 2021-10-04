# [loyale@](https://goto.google.com/who/loyale)'s Dotfiles

This is my dotfiles.

There are many like it, but this one is mine.

My dotfiles is my best friend.

It is my life.

I must master it as I must master my life.


## Installation

- clone from git
- navigate into directory
- run `./setup.sh`


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

