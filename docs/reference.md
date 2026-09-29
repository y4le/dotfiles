# Configuration reference

## Packages

Each Stow package mirrors paths under `HOME`. Component membership and mise
tool selection live in [`setup/profiles.yaml`](../setup/profiles.yaml); platform
and desktop selection live in [`mk/config.mk`](../mk/config.mk).

| Package set | Contents |
| --- | --- |
| Full (default) | `agents`, `atuin`, `bash`, `git`, `herdr`, `mise`, `nvim`, `scripts`, `tmux`, `vim`, `zsh` |
| Lite | `agents`, `bash`, `git`, `mise`, `scripts`, `tmux`, `vim`, `zsh` |
| Add-on components | `atuin`, `yazi`, `nvim`, `herdr`, `dev`, `rclone`; each adds its declared packages and/or mise tools |
| Machine-local | `local`, included when present |
| Linux core | Selected profile and machine-local packages |
| macOS core | Selected profile and machine-local packages, plus `osx` |
| Linux desktop (`DESKTOP=1`) | Linux core plus `linux-desktop` (X11/i3) |
| macOS desktop (`DESKTOP=1`) | macOS core plus `osx-desktop` (Karabiner) |

Zsh is the primary shell; `bash` contains fallback Readline configuration.
`scripts` supplies `~/bin` commands and `~/.config/shell/functions/` helpers.

Neovim uses `stylua` for Lua formatting and `taplo` for TOML formatting when
those commands are installed. `shellcheck` enables Bash and POSIX shell linting
in Neovim and local `make check` runs; CI installs it explicitly. These three
tools are optional and are not installed by `make tools`.

## Make targets

`make` defaults to `make help`. The help output is the complete target list;
these are the main entry points.

| Target | Effect | Access |
| --- | --- | --- |
| `profile` | Show selected components, Stow packages, tools, and restore steps | Offline |
| `profile-set` | Save `PROFILE` and `WITH` to ignored `profile.mk` | Offline |
| `plan` | Show profile and preview link changes | Offline |
| `link-plan` | Preview selected links and detect conflicts | Offline |
| `link` | Restow selected packages, remove unselected add-on links, ensure a local Git config | Offline |
| `link-linux`, `link-macos` | Link an explicit platform's package set | Offline |
| `setup-user` | Run `tools`, `link`, then `plugins` | Network; no sudo |
| `setup` | Run `system-packages`, then `setup-user` | Network; sudo on Linux |
| `system-packages` | Install the native package list | Network; sudo on Linux |
| `tools` | Install selected user-space tools | Network |
| `herdr` | Install the checksum-pinned Herdr binary and validate its config | Network |
| `herdr-integrations` | Install the selected agent hooks; opt-in | Network; writes agent config |
| `plugins` | Restore selected Zsh, Vim, Neovim, and Herdr plugins | Network |
| `sheldon-plugins`, `vim-plugins`, `nvim-plugins`, `herdr-plugins` | Restore one subsystem's plugins | Network |
| `nvim-update` | Update Neovim plugins and the tracked lock | Network |
| `agents-plan-private` | Preview private agent links | Offline |
| `agents-enable-private` | Link the private agent package | Offline |
| `agents-disable-private` | Unstow the private agent package | Offline |
| `clean` | Unstow all known public, desktop, and local packages | Offline |
| `check` | Run repository validation | Offline |
| `check-profiles` | Validate profile syntax, package paths, and mise tool keys | Offline |
| `check-actions` | Run actionlint (separate from `check`) | Offline |
| `check-nvim-first-open` | Open named Lua, shell, and Org files with restored Neovim plugins | Offline; after `nvim-plugins` |

`mise-tools` installs mise and only the selected tool names; `nvim-lazy`
restores only lazy.nvim.

`make PLAN_VERBOSE=1 plan` shows the full Stow dry-run trace; the default plan
hides restow operations that leave existing links unchanged.

`WITH` adds components to `PROFILE` for one invocation. Pass both as Make
arguments (`make PROFILE=lite WITH=yazi plan`); environment variables with
those names are ignored. `profile-set` saves the choice for this checkout;
absent a saved choice, `PROFILE=full`. Shrinking a profile does not prune
installed binaries. An old installation cannot satisfy a newer pin. If an
unselected tool's pin changes, its leftover shim uses a same-named system
executable under mise's default system fallback, or reports the missing pin.
Select the component and run `make tools` to install the new version.
The tracked mise config still lists all pins, so running bare `mise install`
can install the full set; use Make for profile-aware installs. A one-command
`PROFILE` or `WITH` override does not persist; repeat it for each command or
use `profile-set` before running `plan` and `setup-user`.
`HERDR_INTEGRATIONS` defaults to `claude codex antigravity-cli` and can be
overridden when invoking `herdr-integrations`.

`DESKTOP` accepts `0` (default) or `1`. It affects package selection for
linking, not the native package lists. Neither `PROFILE` nor `WITH` changes
the native package lists. `DESKTOP=0` leaves previously linked desktop files
in place; `clean` removes them regardless of its value. `link-linux` and
`link-macos` force only the Stow package set, not the host's package manager.

## Zsh startup

These are the repo's startup stages; system-wide Zsh files are separate.

1. `~/.zshenv` runs in all shells. It first sources
   `~/.config/zsh/hooks/env.zsh`, then sets editor, pager, and path defaults.
2. `~/.zshrc` runs in interactive shells. It first sources
   `~/.config/zsh/hooks/pre.zsh`, then initializes available tools and loads
   the Sheldon cache (or fallback prompt).
3. `~/.config/shell/functions` and `~/.config/zsh/sources` are sourced
   recursively, in that directory order.
4. The rest of `.zshrc` sets terminal options, history, key bindings, and fzf
   options.
5. `~/.config/zsh/hooks/post.zsh` runs last.

Each hook falls back to its legacy home path when the new file is absent.

The Sheldon startup cache is
`${XDG_CACHE_HOME:-~/.cache}/dotfiles/sheldon.zsh`. Startup reads it without
running Sheldon or downloading plugins; `make sheldon-plugins` creates it.

## Local hooks

| Hook | When it loads | Use |
| --- | --- | --- |
| `~/.config/zsh/hooks/env.zsh` | First inside `.zshenv`, including noninteractive shells | Cheap environment setup; later defaults can overwrite values |
| `~/.config/zsh/hooks/pre.zsh` | First inside `.zshrc` | Setup needed before interactive tool initialization |
| `~/.config/zsh/sources/*` | After tool initialization, before remaining shell options | Usual place for machine aliases and environment |
| `~/.config/zsh/hooks/post.zsh` | Last inside `.zshrc` | Final interactive overrides |
| `~/.vim/config/plugins.local.vim` | Before `plug#end()` when vim-plug is available | Additional plugin declarations |
| `~/.vim/config/settings.local.vim` | End of `settings.vim` | Built-in settings |
| `~/.vim/config/maps.local.vim` | End of `maps.vim` | Mappings |
| `~/.vimrc.local` | After plugins, settings, and maps | Final vimrc overrides |
| `~/.config/nvim/lua/local/init.lua` | After core config, before lazy.nvim | Neovim settings and mappings |
| `~/.config/tmux/local.conf` | Before navigation and status bar includes | Machine-specific tmux settings; later includes can override them |
| `~/.gitconfig` | User-owned global Git config | Identity and machine-specific Git settings |

## Editors and tmux

Vim sources `plugins.vim`, `settings.vim`, and `maps.vim` from `~/.vim/config/`,
in that order. VimWiki's root is `g:vimwiki_root`, then `VIMWIKI_ROOT`, then
`~/vimwiki`; work and personal wikis live below it.

Neovim loads `lua/config/`, the local hook, then lazy.nvim with specs from
`lua/plugins/`. `lazy-lock.json` pins plugin commits; startup does not install
missing plugins or check for updates.

In Neovim, plain `j`/`k` follow wrapped display lines; counted jumps use buffer
lines. `<leader>lf` formats with conform and falls back to LSP formatting, and
`<leader>e` shows diagnostics. `.wiki` and `.book` use Markdown formatting.
`SessionSave`, `SessionLoad`, and `SessionDelete` complete saved session names.
`SessionSaveMin` and `SessionSaveMax` accept an optional name and save with
temporary session settings; they preserve the settings used by ordinary saves.
Without a name they overwrite the current directory's default session, as
`SessionSave` does. Vim's Min/Max commands still select persistent session settings.

In a direct SSH session, Neovim sends clipboard copies to the local terminal
with OSC 52. Pastes use text copied in that Neovim session, so they do not query
the terminal clipboard. Tmux and sessions with a graphical clipboard retain
their usual clipboard provider.

Tmux starts with `Ctrl-B`; prefix `a`, `b`, or `Space` changes the active prefix
to `Ctrl-A`, `Ctrl-B`, or `Ctrl-Space`. Prefix `R` reloads the config and prefix
`r` enters resize mode. The configuration uses built-in tmux functionality and
has no plugin restore step.

Herdr also starts with `Ctrl-B`. Prefix `Ctrl-A` or `Ctrl-Space` switches to
that prefix, and pressing the active prefix twice sends it to the pane.
`~/.config/herdr/herdr-prefix` makes each switch by rewriting `keys.prefix` and
a managed block of switch bindings in `config.toml`, then reloading the server.
The switch persists across Herdr restarts until `herdr-prefix reset`.

## Configuration and state paths

These are default locations. The link targets always place configuration under
`HOME`, including literal `~/.config` paths; setting `XDG_CONFIG_HOME` elsewhere
does not relocate them.

| Subsystem | Configuration | Data, cache, or state |
| --- | --- | --- |
| Zsh | `~/.zshenv`, `~/.zshrc`, `~/.config/zsh/` | History under `~/.local/state/zsh/`; fallback at `~/.history` |
| Sheldon | `~/.config/sheldon/plugins.toml` | `~/.local/share/sheldon/`; startup cache under `~/.cache/dotfiles/` |
| mise | `~/.config/mise/config.toml` | `~/.local/share/mise/`; bootstrap binary in `~/.local/bin/` |
| Herdr | `~/.config/herdr/config.toml` | Pinned binary in `~/.local/bin/`; sockets, logs, session snapshots, and `.plugins.lock` stay local under `~/.config/herdr/`; downloaded agent manifests and client state use `~/.local/state/herdr/` |
| Git | `~/.config/git/config`, local `~/.gitconfig` | Per-repository state |
| Vim | `~/.vimrc`, `~/.vim/` | Plugins under `~/.local/share/vim/plugged/`; generated state under `~/.local/state/vim/` |
| IdeaVim | `~/.config/ideavim/ideavimrc` | IDE-managed state |
| Neovim | `~/.config/nvim/` | Plugins under `~/.local/share/nvim/`; undo, swap, backups, sessions, and views under `~/.local/state/nvim/` |
| tmux | `~/.config/tmux/tmux.conf` and supporting files | No repo-managed persistent state |
| Atuin | `~/.config/atuin/config.toml` | Local history; automatic sync and update checks disabled |
| Agents | `~/.agents/` | Public and optional private files share the directory |
| Bash/Readline | `~/.inputrc` | No repo-managed state |
| npm | Environment in `~/.zshenv` | Global packages under `~/.local/share/npm/` |
| Scripts | `~/bin/`, `~/.config/shell/functions/` | No shared state directory |
| Linux desktop | `~/.config/{i3,i3blocks,rofi}/`, X11 dotfiles | No repo-managed state |
| macOS desktop | `~/.config/karabiner/karabiner.json` | No repo-managed state |

Zsh history honors `XDG_STATE_HOME`; the npm prefix and Sheldon's data path
honor `XDG_DATA_HOME`; the Sheldon startup cache honors `XDG_CACHE_HOME`.
Neovim uses its standard config, data, and state paths. Vim keeps legacy config
entry points but honors `XDG_STATE_HOME` for generated state. See the
[XDG policy](design.md#xdg-boundary) before changing these defaults.

Herdr's config directory remains a real directory; Stow links only
`config.toml`. Settings changes made inside Herdr can therefore write through
the link into this checkout. Inspect `git diff -- herdr/` after changing Herdr
settings. Herdr plugins and their lock file are intentionally not tracked.
Herdr's sockets, logs, and session snapshots under the config directory are an
upstream layout exception to this repo's normal XDG state boundary.
