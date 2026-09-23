# Maintain the dotfiles

Run these commands from the checkout.

## Apply configuration changes

After updating the checkout, run `make link-plan` and `make link` to include new
files. Use `DESKTOP=1` for a desktop installation. Restart the shell or editor;
tmux reloads with prefix `R`.

Herdr reads its tracked configuration through
`~/.config/herdr/config.toml`. Reload it with `herdr server reload-config` after
pulling a change. Settings changed inside Herdr may write through that link, so
review `git diff -- herdr/` before committing them. Logs, sockets, session
snapshots, plugin state, and downloaded agent manifests remain machine-local.
On a host where Herdr already created a regular config file, compare it with
`herdr/.config/herdr/config.toml`, move the old file to a backup outside the
Herdr directory, then rerun `make link`. The link step refuses to overwrite an
existing file.

## Restore tools and plugins

On Intel Macs, follow the [Sheldon workaround](setup.md#intel-macs) instead of
running `make setup-user`.

```sh
make setup-user
```

This reruns `tools`, `link`, and `plugins`. `make tools` restores the mise and
Sheldon binaries to their pins, replacing self-updated binaries, and installs
the mise tool versions. `make plugins` needs tools and links in place; it never
installs a missing tool binary. To restore one subsystem, run
`make sheldon-plugins`, `make vim-plugins`, or `make nvim-plugins`.

Vim's fzf integration uses the binary installed by mise. If Vim offers to
download fzf because it is not on `PATH`, answer no, run `make tools`, and start
a new shell. `make vim-plugins` also restores the pinned vim-plug file;
`:PlugUpgrade` drift is replaced on the next run. Vim plugins themselves remain
upstream branch checkouts.

## Update pins

Edit tool versions in [`mise/.config/mise/config.toml`](../mise/.config/mise/config.toml)
and follow the [pin review procedures](../setup/pins/README.md) for bootstrap
artifacts and Zsh plugins. Keep the fzf binary version and Zsh plugin revision
in sync.

For Neovim:

```sh
make nvim-update
git diff -- nvim/.config/nvim/lazy-lock.json
```

Review the lock diff before committing it. Use `make nvim-plugins` to restore
the checked-in lock; it verifies restored commits and preserves the lock file.
Treesitter parsers are also installed by these targets.

## Recover a rejected Zsh plugin restore

If `make sheldon-plugins` reports an off-pin or modified checkout, inspect the
reported path. The verifier rejects tracked changes, untracked or ignored
files, and hidden-index changes. Preserve any work before cleaning or
reinstalling the checkout, then rerun `make sheldon-plugins`.

A failed restore leaves the previous startup cache in place. That cache still
sources the same checkout paths; it does not isolate the shell from modified
plugin files. Resolve the checkout before starting a new shell. See
[reinstalling Sheldon plugins](../setup/pins/README.md#updating-sheldon-plugin-revisions).

## Resolve link conflicts

Run `make link-plan` to identify conflicting destinations. Move existing files
to a backup or an appropriate [local hook](local-config.md), then rerun the
plan. Stow does not merge two files at the same path.

If the artifact guard reports files inside a public package, move machine-local
files into `local/` or real directories under `~`. Track a new portable file
before linking it. Do not bypass the guard by adding files to `.gitignore`;
ignored package files are rejected too.

## Migrate older installs

### Shell helpers

`make link` removes the old `~/.funcs/` links only when they point into this
checkout. Move any machine-local helpers from `~/.funcs/` to
`~/.config/shell/functions/` before starting a new shell; the new directory is
sourced at the same point in Zsh startup.

### Zsh local hooks

Move existing local hooks to their new paths while preserving their contents:

| Old path | New path |
| --- | --- |
| `~/.zshenv.local` | `~/.config/zsh/hooks/env.zsh` |
| `~/.pre_profile` | `~/.config/zsh/hooks/pre.zsh` |
| `~/.post_profile` | `~/.config/zsh/hooks/post.zsh` |

The new hooks keep their original startup phases. Each old path remains a
fallback until its new counterpart exists. If a hook is stowed from `local/`,
move its source into `local/.config/zsh/hooks/` and run `make link`; the target
path changes with it. `make link` removes a legacy local symlink only after the
new hook exists, and only when the link points into this checkout.

### Shell data and state

After updating an existing install, migrate npm globals before starting a new
shell. Copy the history file so shells that are already running can still write
their old history safely:

```sh
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
mkdir -p "$data_home"
mkdir -p -m 700 "$state_home/zsh"
mv "$HOME/.config/npm/globals" "$data_home/npm"
cp -p "$HOME/.history" "$state_home/zsh/history"
```

Run only the commands whose source exists and whose destination does not. Start
a new shell, confirm npm commands and history are available, then remove the
legacy history file.

### Vim state

Close Vim before migrating state. Create the destination directories, then copy
each existing source that is present:

```sh
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
mkdir -p -m 700 "$state_home/vim/undo" "$state_home/vim/view" \
  "$state_home/vim/sessions"
[ ! -f "$HOME/.viminfo" ] || cp -p "$HOME/.viminfo" "$state_home/vim/viminfo"
[ ! -f "$HOME/.vim/mru_files" ] || \
  cp -p "$HOME/.vim/mru_files" "$state_home/vim/mru_files"
for name in undo view sessions; do
  [ ! -d "$HOME/.vim/$name" ] || \
    cp -Rp "$HOME/.vim/$name/." "$state_home/vim/$name/"
done
```

The old `~/.vim/tmp/` mixed disposable swap files with backup files. After all
Vim processes have stopped and any needed recovery is complete, remove it; Vim
now creates separate `swap/` and `backup/` directories under its state root.
After confirming the migrated state, remove the other legacy sources copied by
the commands above.

IdeaVim discovers `~/.config/ideavim/ideavimrc` in supported versions. `make link`
removes the old `~/.ideavimrc` only when it is a managed symlink into this
checkout; move any user-owned config before linking. Restart the IDE and test
a custom mapping after migration.

### Tmux configuration

Tmux 3.1 and newer reads `~/.config/tmux/tmux.conf`. `make link` removes the old
`~/.tmux.conf` only when it is a managed symlink into this checkout. Move a
machine-local `~/.tmux.local.conf` to `~/.config/tmux/local.conf`.

The tmux configuration no longer loads TPM, third-party plugins, or saved
layouts. Older plugin and resurrect directories are not consumed. Preserve
them while an older tmux server is still running; inspect and remove them
manually only after they are no longer needed.

Installs from before the core/desktop split may have desktop links into the old
`linux/` package or removed paths in `osx/`. On a desktop, run
`make DESKTOP=1 link` once to replace them. Elsewhere, `make link` leaves those
links dangling; inspect the old i3, i3blocks, rofi, X11, and helper-script links
on Linux, or `~/.config/karabiner/karabiner.json` on macOS, and remove only stale
links into this checkout.

Older Vim installs may have
`~/.vim/autoload -> <dotfiles>/vim/.vim/autoload`. Remove the generated
`vim/.vim/autoload/plug.vim`, run `make link`, then run `make vim-plugins`.
The plugin target refuses to download through that legacy directory link.

A legacy managed `~/.gitconfig` link is replaced during `make link`. Configure
[Git identity](setup.md#configure-git-identity) again afterward.

## Check repository changes

```sh
make check
```

The checks cover whitespace, shell syntax and lint, download pins, Homebrew
prerequisites, Vim behavior, offline startup, Stow package graphs, isolated
linking, and Make target graphs. Install Git, Make, Stow, Zsh, Bash, Vim, tmux,
Neovim, and ShellCheck for full local coverage; some checks skip missing tools
outside CI. Neovim runtime coverage also needs the pinned lazy.nvim checkout
(`make nvim-lazy`, a networked preparation step).

Run `make check-actions` when changing GitHub Actions workflows; it requires
actionlint. The [CI workflow](../.github/workflows/ci.yml) runs checks on Linux
and macOS; a manually dispatched run also tests full setup in a clean Linux
home.
