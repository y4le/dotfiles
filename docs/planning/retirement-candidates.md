# Dotfiles retirement candidates

This inventory prepares a later dependency and helper cleanup. It records what
the public configuration currently uses, what would change if a candidate were
removed, and what to check first. Remaining candidates need a usage decision
before removal.
The inventory was checked against the repository on 2026-10-01.

Repository references establish configured behavior, not how often a person
uses it. A plugin can provide commands or automatic behavior without an explicit
caller in these dotfiles. Machine-local configuration and private agent files
are outside this inventory.

## Completed retirements

On 2026-10-01, `profiler.vim`, `fd`, `wget`, and `rclone` were retired from the
public setup. The profiler had no public callers; the three utilities are
occasional commands to install locally when needed. Their pins, profile
membership, and native package entries were removed. Existing binaries and
user data remain; linking cleans up only owned profiler symlinks. See the
[migration notes](../maintenance.md#retired-utilities-and-vim-profiler), including
recovery from a saved `WITH=rclone` selection.

Vim's `typescript-vim`, `vim-markdown`, `restore_view.vim`, and `vim-autoswap`
were also retired. TypeScript and Markdown now use Vim's stock runtime; the
local Markdown and `.book` settings remain. Views are saved and loaded only
with explicit native commands. Vim and Neovim disable swap files while retaining
persistent undo and backups. NERDTree is retained in both editors for the
frequently used `<Space>sn` sidebar and `<Space>sN` reveal commands.

Neovim also retires `mini.nvim`, whose only configured module was `mini.misc`
for zoom. `<Space>z` and `:Zoom` now use a native temporary tab, preserving the
original split layout and returning the zoomed buffer and cursor.

## Retained editor behavior

Vim declarations are in [`plugins.vim`](../../vim/.vim/config/plugins.vim).
Neovim declarations are in [`editing.lua`](../../nvim/.config/nvim/lua/plugins/editing.lua).

| Candidate | Current use | Decision and checks before retirement |
| --- | --- | --- |
| NERDTree in Vim and Neovim | `<Space>sn` toggles the sidebar; `<Space>sN` reveals the current file. Neovim also maps `<Space>sR` to refresh. Both editors additionally have file pickers and Yazi. | Keep: the sidebar and reveal commands are frequently used and provide value beyond netrw, Yazi, and fuzzy pickers. |

## Shell candidates with plugin provided commands

These declarations are in [`plugins.toml`](../../zsh/.config/sheldon/plugins.toml).

| Candidate | Current use | Decision and checks before retirement |
| --- | --- | --- |
| `wfxr/forgit` | Deferred shell plugin supplying interactive Git helpers. No public-config invocation or custom setting was found. | Check use of its plugin-provided aliases/functions and local overrides. Fugitive operates inside editors and is not an equivalent shell replacement. |
| `b4b4r07/zsh-vimode-visual` | Deferred plugin extending Zsh's vi editing behavior. `.zshrc` explicitly enables vi mode, and the prompt responds to keymap changes. | Check visual selection/editing habits and interaction with vi mode, autosuggestions, and syntax highlighting before removing it. |
| Optional ghcup startup integration | `.zshenv` sources `~/.ghcup/env` when present and preserves inherited PATH precedence. The public mise manifest does not install Haskell tools. | Check Haskell use on supported machines. Moving this to a machine-local environment hook is an alternative to dropping support; preserve noninteractive PATH behavior if still needed. |

## Compatibility and convenience candidates

| Candidate | Current use | Decision and checks before retirement |
| --- | --- | --- |
| Legacy plugin-local fzf binary cleanup in [`vim-plugins.sh`](../../mk/vim-plugins.sh) | Removes an untracked `bin/fzf` left by the old vim-plug install hook, so it cannot override the mise binary. Tracked plugin helpers remain. | Keep until the relevant machines have restored Vim plugins since that hook was removed. Removing the cleanup early leaves an existing plugin-local binary overriding mise on machines not yet cleaned. |
| Older path migrations in [`bootstrap.mk`](../../mk/bootstrap.mk) | Replaces owned legacy IdeaVim/tmux links, migrates old local Zsh hook paths, and handles the former managed Git config. Runtime fallback paths also keep older local hooks usable. | Check which machines still need migration, then choose a documented sunset. Review link cleanup and runtime fallback together; preserve creation of the machine-local `~/.gitconfig` for identity. Recent retired-helper migrations should remain until machines have had time to use them. |
| Theme `autoload colors` in [`minimal.zsh-theme`](../../zsh/.config/zsh/themes/minimal.zsh-theme) | Initializes Zsh color arrays; the public prompt builds ANSI escapes directly. No public use of `$fg`, `$bg`, or `$reset_color` was found. | Check whether local theme code or shell plugins rely on the initialized arrays before removing this startup work. |
| Optional `fzf-tmux` branch in [successful-history search](../../zsh/.zshrc) | Successful-history search automatically requests a popup inside tmux. It uses `fzf-tmux` when that separate helper is on `PATH` and tmux supports `display-popup`; otherwise it calls fzf directly. The installed mise fzf package on the reviewed host contains only the binary. | Check whether that display mode is used. Compare fzf's built-in tmux support before replacing the helper path; preserve cancellation and command selection behavior. |
| [`link-linux` and `link-macos`](../../mk/bootstrap.mk) | Convenience targets calling `_link` with the Linux or macOS package set. | Check command habits or external scripts. `make PLATFORM=linux link` and `make PLATFORM=macos link` already express the same selection. |

## Behavior to preserve during a later cleanup

The shell's Ctrl-G Yazi navigation is explicitly used. Keep the sourced `y`
wrapper because it changes the caller's directory. `filez` supplies shell/Vim
picker candidates, while `cpy` and `pst` back clipboard operations in shells,
editors, and tmux. These are active integrations, not unused-helper candidates.

Vim still uses `junegunn/fzf` for the runtime required by `fzf.vim`; removing
Sheldon's separate fzf checkout does not make that editor runtime redundant.

Keep the offline startup and explicit restore boundaries, machine-local hooks,
and profile/local/private separation. Retire one coherent feature at a time,
including its mappings, settings, docs, pins, and owned-link migration where
needed. Run `make check` and relevant real runtime checks before committing.
