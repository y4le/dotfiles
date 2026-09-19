# Maintain the dotfiles

Run these commands from the checkout.

## Apply configuration changes

After updating the checkout, run `make link-plan` and `make link` to include new
files. Use `DESKTOP=1` for a desktop installation. Restart the shell or editor;
tmux reloads with prefix `R`.

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
`make sheldon-plugins`, `make tmux-plugins`, `make vim-plugins`, or
`make nvim-plugins`.

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

Tmux plugin commits live in
[`setup/pins/tmux-plugins.txt`](../setup/pins/tmux-plugins.txt). Review upstream
changes before replacing a commit, then run `make tmux-plugins`.

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

### Stow layouts

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
