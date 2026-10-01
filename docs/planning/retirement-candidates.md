# Dotfiles retirement candidates

This inventory prepares a later dependency and helper cleanup. It records what
the public configuration currently uses, what would change if a candidate were
removed, and what to check first. It does not authorize or implement removals.
The inventory was checked against the repository on 2026-10-01.

Repository references establish configured behavior, not how often a person
uses it. A plugin can provide commands or automatic behavior without an explicit
caller in these dotfiles. Machine-local configuration and private agent files
are outside this inventory.

## Candidates with limited repository use

| Candidate | Current use | Decision and checks before retirement |
| --- | --- | --- |
| [`profiler.vim`](../../vim/.vim/autoload/profiler.vim) | Exposes `profiler#start()` and `profiler#end()` for manual Vim profiling; writes `/tmp/vim_profile.log`. No in-repo callers or mappings were found. | Check whether these functions are called manually or from local config. If unused, remove the helper. If retained, use a temporary or state path rather than a shared fixed file. |
| `wget` in the [native package lists](../../setup/packages/) | Installed on Debian/Ubuntu, Arch, and macOS. The verified downloader uses `curl`; repository mentions of `wget` otherwise concern downloader detection and test stubs. | Check personal scripts and direct CLI use before removing it from all three lists. Keep the checks that recognize forbidden downloaders. |
| `fd` in [mise](../../mise/.config/mise/config.toml) and [core](../../setup/profiles.yaml) | Installed in both profiles as a general CLI tool. No direct public-config invocation was found; Neovim explicitly prefers `rg` for its file picker. | Check interactive use and plugin fallback behavior. Removal changes lite/full tool membership, so update profile expectations and docs together. |
| `rclone` in [mise](../../mise/.config/mise/config.toml) and its [component](../../setup/profiles.yaml) | Installed by full, or by `WITH=rclone`. No public rclone config or invocation was found. | Check personal backup/sync commands and machine-local config. Keeping it as an add-on while changing full membership would require revisiting the rule that full contains every component. |

## Editor candidates with active behavior

Vim declarations are in [`plugins.vim`](../../vim/.vim/config/plugins.vim).
Neovim declarations are in [`editing.lua`](../../nvim/.config/nvim/lua/plugins/editing.lua).

| Candidate | Current use | Decision and checks before retirement |
| --- | --- | --- |
| `leafgarland/typescript-vim` | Loads for TypeScript buffers to supply language runtime support. No plugin-specific mappings or settings were found. | Compare representative TypeScript syntax and indentation with the supported Vim runtime before removing it. A built-in TypeScript syntax file exists on the reviewed host; that alone does not establish equivalent behavior on every supported host. |
| `plasticboy/vim-markdown` | Loads for Markdown buffers. The Markdown ftplugin sets concealment, and `.book` files reuse Markdown runtime settings. | Compare concealment, links, folding, indentation, and commands with stock Vim. Check `.md` and `.book` separately. Do not assume the built-in syntax replaces every plugin feature. |
| `vim-scripts/restore_view.vim` | Automatically saves/restores views, including folds and cursor position. `settings.vim` configures the view directory, view options, and excluded Vim files. | Decide whether persistent folds are wanted. If only cursor restoration matters, compare Vim's persisted marks; otherwise keep the plugin or explicitly replace its view behavior. |
| `gioele/vim-autoswap` | Automatically handles swap-file situations when buffers are opened. No custom settings were found. | Exercise opening the same file in two editors and recovery after an interrupted editor. Removal restores Vim's ordinary swap prompts. |
| NERDTree in Vim and Neovim | `<Space>sn` toggles the sidebar; `<Space>sN` reveals the current file. Neovim also maps `<Space>sR` to refresh. Both editors additionally have file pickers and Yazi. | Check whether the persistent sidebar and reveal action are used. Yazi and fuzzy pickers overlap in file opening, but do not reproduce the sidebar experience. Neovim currently loads NERDTree eagerly; lazy loading is a smaller option than retirement. |
| The complete `mini.nvim` repository | Neovim config initializes `mini.misc` and uses `mini.misc.zoom()` for `<Space>z`. No other mini modules are configured. | Consider using the standalone module if it offers the same supported behavior. Preserve zoom; verify the replacement's pin and restore behavior before changing the dependency. |

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
