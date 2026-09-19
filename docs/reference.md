# Configuration reference

## Packages

Each Stow package mirrors paths under `HOME`. Package selection lives in
[`mk/config.mk`](../mk/config.mk).

| Package set | Contents |
| --- | --- |
| Common | `agents`, `atuin`, `bash`, `git`, `mise`, `nvim`, `scripts`, `tmux`, `vim`, `zsh` |
| Machine-local | `local`, included when present |
| Linux core | Common and machine-local packages |
| macOS core | Common and machine-local packages, plus `osx` |
| Linux desktop (`DESKTOP=1`) | Linux core plus `linux-desktop` (X11/i3) |
| macOS desktop (`DESKTOP=1`) | macOS core plus `osx-desktop` (Karabiner) |

Zsh is the primary shell; `bash` contains fallback Readline configuration.
`scripts` supplies `~/bin` commands and `~/.funcs` shell helpers.

## Make targets

`make` defaults to `make help`. The help output is the complete target list;
these are the main entry points.

| Target | Effect | Access |
| --- | --- | --- |
| `link-plan` | Preview selected links and detect conflicts | Offline |
| `link` | Restow selected packages; ensure a local Git config | Offline |
| `link-linux`, `link-macos` | Link an explicit platform's package set | Offline |
| `setup-user` | Run `tools`, `link`, then `plugins` | Network; no sudo |
| `setup` | Run `system-packages`, then `setup-user` | Network; sudo on Linux |
| `system-packages` | Install the native package list | Network; sudo on Linux |
| `tools` | Install mise, its tools, and Sheldon | Network |
| `plugins` | Restore Zsh, tmux, Vim, and Neovim plugins | Network |
| `sheldon-plugins`, `tmux-plugins`, `vim-plugins`, `nvim-plugins` | Restore one subsystem's plugins | Network |
| `nvim-update` | Update Neovim plugins and the tracked lock | Network |
| `agents-plan-private` | Preview private agent links | Offline |
| `agents-enable-private` | Link the private agent package | Offline |
| `agents-disable-private` | Unstow the private agent package | Offline |
| `clean` | Unstow selected public and local packages | Offline |
| `check` | Run repository validation | Offline |
| `check-actions` | Run actionlint (separate from `check`) | Offline |

`install` is a compatibility target for `system-packages` followed by `tools`;
it does not link configuration or restore plugins. `vim-bootstrap` and
`nvim-bootstrap` alias their respective plugin targets. `mise-tools` installs
mise and its configured tools; `nvim-lazy` restores only lazy.nvim.

`DESKTOP` accepts `0` (default) or `1`. It affects package selection for linking
and cleanup, not the native package lists. `DESKTOP=0` leaves previously linked
desktop files in place. `link-linux` and `link-macos` force only the Stow package
set, not the host's package manager.

## Zsh startup

These are the repo's startup stages; system-wide Zsh files are separate.

1. `~/.zshenv` runs in all shells. It first sources `~/.zshenv.local`, then sets
   editor, pager, and path defaults.
2. `~/.zshrc` runs in interactive shells. It first sources `~/.pre_profile`,
   then initializes available tools and loads the Sheldon cache (or fallback
   prompt).
3. `~/.funcs` and `~/.config/zsh/sources` are sourced recursively, in that
   directory order.
4. The rest of `.zshrc` sets terminal options, history, key bindings, and fzf
   options.
5. `~/.post_profile` runs last.

The Sheldon startup cache is
`${XDG_CACHE_HOME:-~/.cache}/dotfiles/sheldon.zsh`. Startup reads it without
running Sheldon or downloading plugins; `make sheldon-plugins` creates it.

## Local hooks

| Hook | When it loads | Use |
| --- | --- | --- |
| `~/.zshenv.local` | First inside `.zshenv`, including noninteractive shells | Cheap environment setup; later defaults can overwrite values |
| `~/.pre_profile` | First inside `.zshrc` | Setup needed before interactive tool initialization |
| `~/.config/zsh/sources/*` | After tool initialization, before remaining shell options | Usual place for machine aliases and environment |
| `~/.post_profile` | Last inside `.zshrc` | Final interactive overrides |
| `~/.vim/config/plugins.local.vim` | Before `plug#end()` when vim-plug is available | Additional plugin declarations |
| `~/.vim/config/settings.local.vim` | End of `settings.vim` | Built-in settings |
| `~/.vim/config/maps.local.vim` | End of `maps.vim` | Mappings |
| `~/.vimrc.local` | After plugins, settings, and maps | Final vimrc overrides |
| `~/.config/nvim/lua/local/init.lua` | After core config, before lazy.nvim | Neovim settings and mappings |
| `~/.tmux.local.conf` | Before navigation, status bar, and plugin includes | Local settings and extra `@plugin` lines; later includes can override them |
| `~/.gitconfig` | User-owned global Git config | Identity and machine-specific Git settings |

## Editors and tmux

Vim sources `plugins.vim`, `settings.vim`, and `maps.vim` from `~/.vim/config/`,
in that order. VimWiki's root is `g:vimwiki_root`, then `VIMWIKI_ROOT`, then
`~/vimwiki`; work and personal wikis live below it.

Neovim loads `lua/config/`, the local hook, then lazy.nvim with specs from
`lua/plugins/`. `lazy-lock.json` pins plugin commits; startup does not install
missing plugins or check for updates.

Tmux uses `Ctrl-B`; prefix `R` reloads the config and prefix `r` enters resize
mode. `make tmux-plugins` restores only the pinned list; extra plugins declared
in local config need separate installation.

## Configuration and state paths

These are default locations. The link targets always place configuration under
`HOME`, including literal `~/.config` paths; setting `XDG_CONFIG_HOME` elsewhere
does not relocate them.

| Subsystem | Configuration | Data, cache, or state |
| --- | --- | --- |
| Zsh | `~/.zshenv`, `~/.zshrc`, `~/.config/zsh/` | History under `~/.local/state/zsh/`; fallback at `~/.history` |
| Sheldon | `~/.config/sheldon/plugins.toml` | `~/.local/share/sheldon/`; startup cache under `~/.cache/dotfiles/` |
| mise | `~/.config/mise/config.toml` | `~/.local/share/mise/`; bootstrap binary in `~/.local/bin/` |
| Git | `~/.config/git/config`, local `~/.gitconfig` | Per-repository state |
| Vim | `~/.vimrc`, `~/.vim/` | Plugins under `~/.local/share/vim/plugged/`; generated state under `~/.local/state/vim/` |
| Neovim | `~/.config/nvim/` | Plugins under `~/.local/share/nvim/`; undo, swap, backups, sessions, and views under `~/.local/state/nvim/` |
| tmux | `~/.tmux.conf`, `~/.config/tmux/` | Plugins under `~/.tmux/plugins/` |
| Atuin | `~/.config/atuin/config.toml` | Local history; automatic sync and update checks disabled |
| Agents | `~/.agents/` | Public and optional private files share the directory |
| Bash/Readline | `~/.inputrc` | No repo-managed state |
| npm | Environment in `~/.zshenv` | Global packages under `~/.local/share/npm/` |
| Scripts | `~/bin/`, `~/.funcs/` | No shared state directory |
| Linux desktop | `~/.config/{i3,i3blocks,rofi}/`, X11 dotfiles | No repo-managed state |
| macOS desktop | `~/.config/karabiner/karabiner.json` | No repo-managed state |

Zsh history honors `XDG_STATE_HOME`; the npm prefix and Sheldon's data path
honor `XDG_DATA_HOME`; the Sheldon startup cache honors `XDG_CACHE_HOME`.
Neovim uses its standard config, data, and state paths. Vim keeps legacy config
entry points but honors `XDG_STATE_HOME` for generated state. See the
[XDG policy](design.md#xdg-boundary) before changing these defaults.
