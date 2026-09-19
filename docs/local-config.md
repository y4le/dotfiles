# Keep local and private configuration

Public packages hold portable configuration. Anything that hints at company
information should stay outside them. Settings for one machine go in real files
under `~` or in the ignored `local/` package, which Make includes automatically
when it exists. Private settings shared across machines go in a separately
tracked private repo. `local/` is not a backup.

## Add machine-specific shell settings

The usual place is `~/.config/zsh/sources/`. After `make link`:

```sh
mkdir -p ~/.config/zsh/sources
```

Create `~/.config/zsh/sources/machine.zsh` with the settings needed on this
machine, then start a new Zsh shell. For example:

```zsh
export PROJECTS="$HOME/work"
alias cwork='cd "$PROJECTS"'
```

Zsh sources files under this directory recursively; keep backups and non-shell
files elsewhere. For settings that must load earlier or later, see
[local hooks](reference.md#local-hooks).

## Keep overrides in the checkout

Use the ignored `local/` package when a machine's files should live together.
Paths under `local/` mirror `HOME`:

| Company info that would go here | Instead goes here |
| --- | --- |
| `~/.zshrc` | `local/.config/zsh/sources/corp.zsh` |
| `~/.vimrc` | `local/.vim/config/{plugins,maps,settings}.local.vim` |
| `~/.config/nvim/init.lua` | `local/.config/nvim/lua/local/init.lua` |
| `~/.config/tmux/tmux.conf` | `local/.config/tmux/local.conf` |
| `~/.example_corp_config` | `local/.example_corp_config` |

Create the files, then run `make link-plan` and `make link`. Each destination
has one owner; move a file already under `~` into `local/` before linking that
path. Files inside public packages must be tracked; [link
conflicts](maintenance.md#resolve-link-conflicts) covers what the guard rejects.

## Customize editors

Put Vim overrides in `~/.vim/config/plugins.local.vim`, `settings.local.vim`,
or `maps.local.vim`. Plugin declarations load inside the vim-plug block; the
other two files load at the end of their matching config. Use `~/.vimrc.local`
for settings that must follow all three.

Vim autoload functions belong in `~/.vim/autoload/` (loaded on first use),
self-contained plugins in `~/.vim/plugin/` (loaded at startup), and filetype
plugins in `~/.vim/ftplugin/<language>.vim`. Add files with their own names;
editing a managed symlink changes the repo file it points to.

VimWiki defaults to `~/vimwiki`. Set `VIMWIKI_ROOT` to an absolute path for a
machine-specific location, or set `g:vimwiki_root` in a local Vim config before
the wiki setup loads.

Put Neovim overrides in `~/.config/nvim/lua/local/init.lua`. It runs after core
settings and keymaps, before lazy.nvim setup; later plugin setup can override
those values.

## Enable private agent skills

The public base is `agents/.agents/`; its `skills/` directory is a placeholder.
The private repo defaults to `~/dev/agents` and must expose an `agents/` Stow
package, with skills under `agents/.agents/skills/`.

With that checkout present:

```sh
make agents-plan-private
make agents-enable-private
```

Stow merges the public and private directories at `~/.agents/skills/`. Files
must have distinct destinations; the private package does not overwrite public
files. Private package files must be tracked before linking.

To use a different checkout, pass `PRIVATE_AGENTS_DIR=/path/to/agents` to each
private-agent command. `PRIVATE_AGENTS_PACKAGE` selects its Stow package
(default `agents`).

To remove the private links:

```sh
make agents-disable-private
```

Keep the private checkout available until removal finishes. If it has already
been deleted, dangling links need manual removal.
