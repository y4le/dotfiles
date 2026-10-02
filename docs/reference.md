# Configuration reference

## Packages

Each Stow package mirrors paths under `HOME`. Component membership and mise
tool selection live in [`setup/profiles.yaml`](../setup/profiles.yaml); platform
and desktop selection live in [`mk/config.mk`](../mk/config.mk).

| Package set | Contents |
| --- | --- |
| Full (default) | `agents`, `atuin`, `bash`, `git`, `herdr`, `mise`, `nvim`, `scripts`, `tmux`, `vim`, `zsh` |
| Lite | `agents`, `bash`, `git`, `mise`, `scripts`, `tmux`, `vim`, `zsh` |
| Add-on components | `atuin`, `yazi`, `nvim`, `herdr`, `node`, `web-dev`, `python-dev`, `go-dev`, `rust-dev`, `dev`; each adds its declared packages and/or mise tools |
| Machine-local | `local`, included when present |
| Linux core | Selected profile and machine-local packages |
| macOS core | Selected profile and machine-local packages, plus `osx` |
| Linux desktop (`DESKTOP=1`) | Linux core plus `linux-desktop` (X11/i3) |
| macOS desktop (`DESKTOP=1`) | macOS core plus `osx-desktop` (Karabiner); see [GUI save recovery](maintenance.md#recover-a-karabiner-configuration-replaced-by-the-gui) |

`full` selects everyday core CLIs, Atuin, Yazi, Neovim with LuaLS, Herdr, and
Node for locally installed CLI tools. Language development runtimes and servers
are optional. See the [pack recipes](setup.md#enable-optional-tools) for payloads
and activation; `WITH=dev` restores the previous broad development selection.
Existing machines need to save optional development packs before the next link.
Lite machines using Node-based CLIs can select `WITH=node`.

Zsh is the primary shell; `bash` contains fallback Readline configuration.
`scripts` supplies standalone `~/bin` commands and the sourced Yazi wrapper
at `~/.config/shell/functions/y`. Local shell functions can also live in
`~/.config/shell/functions/` for Zsh to source.

Neovim uses `stylua` for Lua formatting and `taplo` for TOML formatting when
those commands are installed. `shellcheck` enables Bash and POSIX shell linting
in Neovim and local `make check` runs; CI installs it explicitly. These three
tools are optional and are not installed by `make tools`.

Occasional utilities such as `fd`, `wget`, and `rclone` are installed locally
when needed; the public setup does not install or pin them. Use the machine's
package manager or machine-local tool configuration rather than adding them
to `setup/tools.toml`.

## Vim files, buffers, and recursive search

`<Space>m` opens recent files from Vim's persisted history and this session's
buffers. `:FzfMru` and `:Oldfiles` use the same fzf.vim history picker; no MRU
plugin or separate history file is needed. Add `!` for fullscreen, or press
`?` to toggle the preview. `<Space>Fm` and `<Space>Fpm` open the same picker.
`<Space>qm` also opens recent files; select files and press `Ctrl-Q` to send
them to quickfix.

`<Space>j` (`:Buffs`) lists ordinary buffers in recent-use order, with the
current buffer shown as a header. `<Space>J` (`:AllBuffs`) also includes existing
unlisted buffers such as help and scratch buffers. Buffer selection uses
buffer numbers, so unnamed buffers are selectable. These pickers select one
buffer at a time; both commands accept `!` for fullscreen.

Ferret's `:Ack` has been removed. Use the existing commands below instead:

| Command | Search behavior |
| --- | --- |
| `:Fw literal text` | Recursive, case-insensitive literal search from Vim's working directory, with fzf selection and optional preview |
| `:Fl literal text` | The same search from the current file's directory |
| `:grep! -e 'pattern' .` then `:copen` | Recursive ripgrep regex search into quickfix; smart case, honoring ignore files |
| `:cnext`, `:cprevious` | Move through quickfix matches |

`:Fw` and `:Fl` include hidden and ignored files, follow symlinks, and exclude
`.git`. Use `Tab` to select several matches, or `Alt-A` to select all; `Enter`
opens quickfix for multiple selected matches. This provides the search-to-
quickfix workflow previously supplied by `:Ack`.

For replacement across matched lines, Vim's native quickfix workflow is
`:cdo s/old/new/ge | update`; use `:cfdo %s/old/new/ge | update` to replace
throughout each matched file. Review the quickfix results before either.

## Make targets

`make` defaults to `make help`. The help output is the complete target list;
these are the main entry points.

| Target | Effect | Access |
| --- | --- | --- |
| `packs`, `pack NAME=...` | Discover packs or inspect one payload and restore steps | Offline |
| `profile` | Show selected components, Stow packages, tools, and restore steps | Offline |
| `profile-set` | Save `PROFILE` and `WITH` to ignored `profile.mk` | Offline |
| `plan` | Show selection, installation inventory, and link/configuration changes | Offline |
| `link-plan` | Preview selected links and detect conflicts | Offline |
| `link` | Restow selected packages, prepare the owned mise fragment, remove unselected links, ensure a local Git config | Offline |
| `setup-user` | Preflight mise file ownership, then run `tools`, `link`, and `plugins` | Network; no sudo |
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
| `clean` | Remove the owned mise fragment and unstow known public, desktop, and local packages | Offline |
| `check` | Run repository validation | Offline |
| `check-profiles` | Validate profile syntax, package paths, and mise tool keys | Offline |
| `check-actions` | Run actionlint (separate from `check`) | Offline |
| `check-nvim-first-open` | Open named files and check filetypes and plugin loading with restored Neovim plugins | Offline; after `nvim-plugins` |

`mise-tools` installs mise and only the selected tool names; `nvim-lazy`
restores only lazy.nvim.

`link-plan` reports dangling links into this checkout in dotfile destinations
and helper directories, including links left by deleted packages. It leaves
them for inspection. On macOS, the plan includes `.zprofile`; when `clean`
removes that managed profile, it restores the preserved `.zprofile.local`.

`make PLAN_VERBOSE=1 plan` shows the full Stow dry-run trace; the default plan
hides restow operations that leave existing links unchanged.

`WITH` adds components to `PROFILE` for one invocation. Pass both as Make
arguments (`make PROFILE=lite WITH=yazi plan`); environment variables with
those names are ignored. `profile-set` requires explicit `PROFILE` and `WITH` and saves the complete
choice for this checkout;
absent a saved choice, `PROFILE=full`. Shrinking a profile does not prune
installed binaries. An old installation cannot satisfy a newer pin. A retained
shim needs a selected, project, or local pin; otherwise it may fall back to a
system copy or fail. Select the pack and run `make mise-tools link` to install
and activate its pinned versions. `setup/tools.toml` holds the full catalog;
the linked global config holds settings only. `make link` writes selected pins
to `~/.config/mise/conf.d/dotfiles.toml`. Bare `mise install` follows effective
configuration, including project and local overrides, while Make installs the
explicit selection against the catalog. A one-command `PROFILE` or `WITH`
override does not persist; repeat it for each command or use `profile-set`
before running `plan` and `setup-user`.
Zsh exports `EDITOR=dotfiles-vim` and `VISUAL=dotfiles-vim`. The launcher chooses
usable Neovim at invocation time, falling back to Vim. Ordinary commands use
presence checks; mise shims require an offline `mise which` lookup, with system
copies later on PATH eligible if that fails. Active shims are retained so mise
can supply each backend's environment. Shell startup does not probe mise.
Neovim uses the same availability rule for language servers, linters, and
formatters, and executes a usable system copy when a stale shim would hide it.
Project and machine-local mise versions remain eligible without a pack selection.

`HERDR_INTEGRATIONS` defaults to `claude codex antigravity-cli` and can be
overridden when invoking `herdr-integrations`.

`DESKTOP` accepts `0` (default) or `1` as a Make argument; an environment
value is ignored. An explicitly empty `PROFILE` is rejected. `DESKTOP` affects
package selection for linking, not the native package lists. Neither `PROFILE`
nor `WITH` changes the native package lists. `DESKTOP=0` leaves previously
linked desktop files in place; `clean` removes them regardless of its value.

## Linux desktop locking

The opt-in i3 configuration needs `xss-lock`, `xsecurelock`, and `xset`
(Debian's x11-xserver-utils or Arch's xorg-xset). Install them separately;
`make system-packages` installs base prerequisites only. The configuration
sets the X screensaver timeout to three minutes and starts
`xss-lock -l -- xsecurelock`, which handles idle and logind suspend events.
The manual lock binding (`$meta+l`) requests `xset s activate` through that
same locker. This follows [XSecureLock's integration guidance](https://github.com/google/xsecurelock#automatic-locking).

After installing dependencies and linking, log out of the X11/i3 session and
log back in. Reloading or restarting i3 does not rerun these `exec` startup
commands; an existing xautolock process otherwise keeps running. Avoid
starting a second locker through another desktop autostart entry. Verify
manual lock, the three-minute idle lock, and suspend/resume on the machine
before relying on this configuration. Repository checks validate syntax;
they do not exercise authentication or display-server behavior.

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

For a locally installed Haskell toolchain, explicitly source `~/.ghcup/env`
from `~/.config/zsh/hooks/env.zsh` on machines that need it. That local hook
owns activation and PATH ordering. Portable PATH defaults preserve inherited
entries. The hook runs before those defaults, so toolchain paths it prepends
take precedence over managed bins and mise shims.

Successful-history search (`Ctrl-X o`) uses fzf's native popup with a tmux 3.3 or
newer server, with inline selection elsewhere. Popup size defaults to 90% width
and 70% height; `ATUIN_TMUX_POPUP_WIDTH` and `ATUIN_TMUX_POPUP_HEIGHT` override it.
`ATUIN_TMUX_POPUP=false` disables the popup. Selection replaces the command
line; cancellation preserves it.

The Sheldon startup cache is
`${XDG_CACHE_HOME:-~/.cache}/dotfiles/sheldon.zsh`. Startup reads it without
running Sheldon or downloading plugins; `make sheldon-plugins` creates it.
That restore also bundles `fzf --zsh` from the mise-selected binary (falling
back to `PATH`) and loads it at the existing deferred position before syntax
highlighting. It does not
run fzf to initialize each shell. If necessary, pass `FZF_BIN=/path/to/fzf`
to the restore target; the binary must support `--zsh`. After updating an
existing checkout, run `make link sheldon-plugins` to link the new wrapper and
refresh the cache.

## File navigation in Zsh

`filez` supplies candidates for the default fzf picker (including Vim's
`:FzfDefault`) and Zsh Ctrl-T. It runs independently of shell initialization
or a stowed helper. Its scope is the current directory, recursively; it does
not expand a subdirectory to the repository root.

Inside a Git worktree, it lists existing tracked files and nonignored
untracked files. Tracked files matching ignore rules and nonignored dotfiles
remain visible. Deleted files, broken symlinks, directory entries, and
submodule contents are excluded; symlinks to existing files remain usable.
Git metadata directories and bare repositories produce a clear error.

Outside Git, it uses `rg --no-config --files`, respecting rg's ignore files.
`--hidden` (or `-h`) enables hidden paths in this filesystem scan; Git
membership already includes dotfiles. `.git` entries are excluded from the scan.
This requires Git 2.31+ for worktrees and ripgrep elsewhere, both provided by
the normal setup. There is no fd/find fallback with different ignore behavior.

`--root DIR` (or `-r DIR`) selects a directory. The default `.` emits `./`
paths; other roots emit physical absolute paths, so selections remain
openable from the caller's directory. `--debug` reports the selected source
on stderr, and `--help` describes the options. Unknown arguments and missing
root values fail with status 2; invalid roots fail with status 1.

An empty listing succeeds. Producer failures retain their nonzero status,
diagnostics, and any partial output; no second source retries the scan.
Default output uses newlines for existing fzf/Vim consumers, so filenames
containing newlines require `--print0`. Ctrl-T reads candidates with fzf's
`--read0`, but the upstream Zsh widget inserts selections line by line, so
newline-containing filenames are not supported through Ctrl-T insertion.
A separate machine pipeline must preserve NUL delimiters through selection
and consumption; other text pickers keep their own delimiter settings.

For directory jumps, use `z` or interactive `zi`; fzf supplies Alt-C for
choosing a directory and Ctrl-T for inserting a file path. Yazi remains
available through its optional component and editor integrations. Shell
Ctrl-G invokes the sourced `y` wrapper to open Yazi and change the current
shell directory on exit. Calling `y` directly provides the same behavior;
Yazi and directory-change failures return nonzero and temporary files are
cleaned up. The unused `nav`, `compair.sh`, and `benchmark.sh` helpers are
retired.
Use `vim -d first second` for ordinary file comparisons and shell `time` for
occasional measurements. After changing shell config, open a fresh shell;
re-sourcing `.zshrc` does not clear deleted definitions or bindings.

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

Neovim's `<Space>z` / `:Zoom` opens the current split in a temporary tab. Toggle
again from either tab to return its buffer and cursor and focus the original
split. Other tabs can be zoomed independently. Sidebar and split commands work in the temporary
tab; toggling back closes it with ordinary buffer safeguards. Closing
it manually also leaves the original layout intact. If the original split or
zoom window was closed, toggling releases zoom state and keeps the remaining
work as an ordinary tab. Saved sessions keep the temporary tab as an ordinary
tab. A single window is already full size.

Both editors disable swap files and retain persistent undo and backups. Vim
uses its stock TypeScript and Markdown runtime and explicit `:mkview` /
`:loadview` commands for saved views.

In Neovim, plain `j`/`k` follow wrapped display lines; counted jumps use buffer
lines. `<leader>lf` formats with conform and falls back to LSP formatting, and
`<leader>e` shows diagnostics. `.wiki` and `.book` use the Markdown filetype;
the public setup no longer supplies Prettier formatting for prose or web files.
JavaScript and TypeScript still format on save through LSP fallback when their
language server is available, using TypeScript's style rather than project
Prettier settings. Markdown/wiki/book, JSON, YAML, CSS, and HTML have no
configured formatter or LSP formatting provider in this setup.
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
| mise | Settings in `~/.config/mise/config.toml`, selected pins in `~/.config/mise/conf.d/dotfiles.toml`, overrides in `config.local.toml` | `~/.local/share/mise/`; bootstrap binary in `~/.local/bin/` |
| Herdr | `~/.config/herdr/config.toml` | Pinned binary in `~/.local/bin/`; sockets, logs, session snapshots, and `.plugins.lock` stay local under `~/.config/herdr/`; downloaded agent manifests and client state use `~/.local/state/herdr/` |
| Git | `~/.config/git/config`, local `~/.gitconfig` | Per-repository state |
| Vim | `~/.vimrc`, `~/.vim/` | Plugins under `~/.local/share/vim/plugged/`; generated state under `~/.local/state/vim/` |
| IdeaVim | `~/.config/ideavim/ideavimrc` | IDE-managed state |
| Neovim | `~/.config/nvim/` | Plugins under `~/.local/share/nvim/`; undo, backups, sessions, and views under `~/.local/state/nvim/` |
| tmux | `~/.config/tmux/tmux.conf` and supporting files | No repo-managed persistent state |
| Atuin | `~/.config/atuin/config.toml` | Local history; automatic sync and update checks disabled |
| Agents | `~/.agents/` | Public and optional private files share the directory |
| Bash/Readline | `~/.inputrc` | No repo-managed state |
| npm | Environment in `~/.zshenv` | Global packages under `~/.local/share/npm/` |
| Scripts | `~/bin/`, `~/.config/shell/functions/y` | No shared state directory |
| Linux desktop | `~/.config/{i3,i3blocks,rofi}/`, X11 dotfiles | No repo-managed state |
| macOS desktop | `~/.config/karabiner/karabiner.json` | No repo-managed state |

Zsh inserts missing default PATH entries before their next configured neighbor,
preserving custom prefixes and the order of entries inherited from
its parent. Activated virtual environments keep their precedence in child
shells. Mise
shims use `MISE_SHIMS_DIR`, then `MISE_DATA_DIR/shims`, then
`${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims`. The macOS login profile
restores the order captured before `path_helper` after loading the original
local profile. Entries that profile prepends stay ahead of system directories
and behind the managed tools; additional system entries are retained.

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

### Linux clipboard backends

`cpy` and `pst` use `wl-copy`/`wl-paste` only when `WAYLAND_DISPLAY` is set,
and xclip only when `DISPLAY` is set. Install `wl-clipboard` for a Wayland
session or `xclip` for X11 (for example, `sudo apt-get install wl-clipboard`
or `sudo apt-get install xclip`). These are session dependencies rather than
base setup packages. macOS uses its built-in `pbcopy`/`pbpaste`.

`cpy` and `pst` are standalone commands sharing one executable via a sibling
symlink; they work from the checkout and do not source shell configuration.
Wayland paste uses `wl-paste --no-newline` to preserve the clipboard's bytes.
Backend failures propagate without retrying a different clipboard.

Copy over SSH uses the terminal clipboard. Inside tmux it uses
`tmux load-buffer -w -`, which also works in copy-pipe jobs without a
controlling terminal. Otherwise it emits OSC 52 to `/dev/tty`; failed
encoding emits no sequence, and a missing terminal fails explicitly.
Terminal copying is best effort: the terminal must support and permit OSC 52;
tmux also needs an attached client whose terminal advertises the `Ms`
capability or `clipboard` feature. Remote terminfo can affect this detection. Successful submission does not
confirm clipboard receipt, including when no client is attached. In tmux
copy mode, native copy and the copy-pipe command can create identical buffers;
ordinary `cpy` output remains available to tmux's default paste-buffer action.

Paste reads the graphical clipboard available on the current host. Over SSH,
this can differ from the local terminal clipboard used by copy; use the
terminal's paste for that clipboard. Without a display backend, `pst` reports
an error; it does not invent or export a display.
