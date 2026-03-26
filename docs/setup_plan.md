# Setup Overhaul Plan

Addresses structural improvements #1 (platform-aware stow), #7 (Makefile),
and #3 (bootstrap without auto-install) from `docs/review.md`.

---

## Goals

1. **Single entry point**: `make setup` bootstraps a fresh machine
2. **Platform-aware linking**: only stow packages relevant to the current OS
3. **No hidden network calls in shell init**: `.zshrc` fails fast with a
   helpful message instead of auto-installing sheldon
4. **Cross-OS package installation**: mise for dev tools, native package
   manager for system dependencies

---

## Design

### Makefile targets

```
make setup        # full bootstrap: native packages + mise tools + links + sheldon lock
make link         # link dotfiles only (platform-aware)
make link-linux   # force linux stow set
make link-macos   # force macos stow set
make install      # install native packages + mise-managed tools
make sheldon      # install sheldon binary
make brew         # install homebrew (macOS only)
make clean        # unstow platform-matched packages
```

### Package classification (stow)

Explicit allowlists — every stow package must be classified. Unclassified
top-level directories are ignored (not silently stowed).

| Category   | Packages |
|------------|----------|
| **common** | agents, alacritty, bash, git, local, mise, nvim, pet, scripts, tmux, vim, zsh |
| **linux**  | linux |
| **macos**  | osx |
| **skip**   | setup, docs, taskwarrior (deprecated) |

The Makefile auto-detects `uname -s` and stows `common + platform`.
`make clean` unstows the same set with `stow -D`.

### Package installation strategy

Two-tier approach:

**Tier 1 — mise** (cross-platform, no sudo, declarative `config.toml`):
Pinned runtimes and cross-platform CLI tools. Replaces `asdf`, `nvm`, and the
bulk of the old brew script.

Config lives at `mise/.config/mise/config.toml` in this repo (stowed into
`~/.config/mise/config.toml` via the `mise` package).

**Tier 2 — Native package manager** (system-level deps):
Core shell/editor/bootstrap packages. These require root and are inherently
platform-specific.
- macOS: `setup/packages/brew.txt`
- Debian/Ubuntu: `setup/packages/apt.txt`
- Arch: `setup/packages/pacman.txt`

Parallel lists stay intentionally short: `git`, `ranger`, `stow`, `tmux`,
`tree`, `vim`, `wget`, `zsh`, plus `curl` on Linux so `mise` can bootstrap.

### Bootstrap flow (`make setup`)

```
1. Install native packages for the current platform
2. Install mise (prebuilt binary via curl installer)
3. mise install (runtimes + CLI tools from config.toml)
4. make link (platform-aware stow, including mise + nvim packages)
5. Install sheldon (prebuilt binary → ~/.local/bin)
6. sheldon lock (fetch zsh plugins)
```

Each step is idempotent — safe to re-run.

### .zshrc

Fail-fast guard, no auto-install:

```zsh
if ! command -v sheldon &>/dev/null; then
  echo "sheldon not found — run 'make setup' from your dotfiles repo"
  return
fi
eval "$(sheldon source)"
```

---

## Dependency Audit

Full analysis of packages that were previously managed in `setup/update_brew.sh`.

`Used in dotfiles?` means a direct reference was found in tracked configs or
scripts during a repo-wide search. `no` means no direct reference was found; it
does not automatically mean the package is safe to remove.

This audit is broader than the initial conservative implementation. `keep` /
`move to mise` means the package fits the new model, not that it is part of the
default package lists today.

### Core packages

| Package | Current source | Setup tier | In mise? | Used in dotfiles? | Recommendation |
|---------|---------------|------------|----------|-------------------|----------------|
| asdf | brew | — | — | no | **delete** — replaced by mise |
| tmux | brew | system | yes (but system is better) | yes | **keep** — system package |
| zsh | brew | system | no | yes | **keep** — system package |

### VCS packages

| Package | Current source | Setup tier | In mise? | Used in dotfiles? | Recommendation |
|---------|---------------|------------|----------|-------------------|----------------|
| git | brew | system | no | yes | **keep** — system package |
| mercurial | brew | — | no | yes | **delete** — flagged unused in review (T14). Note: repo still has hg refs in vim-signify, fzf helpers, and zsh theme — config cleanup needed before removing |

### Editor packages

| Package | Current source | Setup tier | In mise? | Used in dotfiles? | Recommendation |
|---------|---------------|------------|----------|-------------------|----------------|
| neovim | brew | mise | yes | yes | **keep** — move to mise |
| vim | brew | system | yes | yes | **keep** — system package (always available) |

### CLI tools (other_packages)

| Package | Current source | Setup tier | In mise? | Used in dotfiles? | Recommendation |
|---------|---------------|------------|----------|-------------------|----------------|
| bat | brew | mise | yes | yes | **keep** — move to mise |
| fasd | brew | — | no | yes | **replace** with zoxide (T2, archived). Requires config migration: `.zshrc` `zz` function, sheldon oh-my-zsh fasd plugin, `scripts/.funcs/fzf_sources` |
| diff-so-fancy | brew | system | no | no | **replace** with delta (mise-compatible, maintained) |
| exa | brew | — | yes | no | **replace** with eza (T9, unmaintained) |
| fd | brew | mise | yes | yes | **keep** — move to mise |
| fortune | brew | system | no | no | **keep** — system package |
| fpp | brew | system | no | no | **keep** — system package |
| fzf | brew | mise | yes | yes | **keep** — move to mise |
| fzy | brew | system | no | no | **delete** — redundant with fzf |
| gpg | brew | system | no | no | **keep** — system package |
| htop | brew | system | no | no | **keep** — system package |
| jq | brew | mise | yes | no | **keep** — move to mise |
| ncdu | brew | system | no | no | **keep** — system package |
| parallel | brew | system | no | no | **keep** — system package |
| poppler | brew | system | no | no | **keep** — system package |
| prettyping | brew | system | no | no | **keep** — system package |
| pv | brew | system | no | no | **keep** — system package |
| ranger | brew | system | no | yes | **keep** — system package |
| ripgrep | brew | mise | yes | yes | **keep** — move to mise |
| tldr | brew | system | no | no | **keep** — system package |
| tree | brew | system | no | yes | **keep** — system package |
| watch | brew | system | no | no | **keep** — system package |
| watchman | brew | system | no | no | **keep** — system package |
| wget | brew | system | no | no | **keep** — system package |
| youtube-dl | brew | — | yes | no | **replace** with yt-dlp (T8, dead) |

### Language packages

| Package | Current source | Setup tier | In mise? | Used in dotfiles? | Recommendation |
|---------|---------------|------------|----------|-------------------|----------------|
| go | brew | mise | yes | no | **keep** — move to mise |
| node | brew | mise | yes | yes | **keep** — move to mise. Requires nvm removal: clean up `local/.pre_profile` nvm init and `zsh/.zshenv` nvm-aware npm prefix logic |
| flow | brew | — | no | no | **delete** — FB abandoned it, TypeScript won |
| yarn | brew | mise | yes | no | **keep** — move to mise |
| sbcl | brew | mise | yes | yes | **keep** — move to mise (if still used) |
| ocaml | brew | mise | yes | no | **keep** — move to mise (if still used) |
| opam | brew | mise | yes | no | **keep** — move to mise (if still used) |
| octave | brew | system | no | no | **delete** — unlikely still used |
| python | brew | mise | yes | yes | **keep** — move to mise |
| r | brew | mise | yes | no | **keep** — move to mise (if still used) |
| ruby | brew | mise | yes | yes | **keep** — move to mise |
| rust | brew | mise | yes | no | **keep** — move to mise |

### Library packages

| Package | Current source | Setup tier | In mise? | Used in dotfiles? | Recommendation |
|---------|---------------|------------|----------|-------------------|----------------|
| autoconf | brew | system | no | no | **keep** — system package |
| automake | brew | system | no | no | **keep** — system package |
| cmake | brew | system | no | no | **keep** — system package |
| coreutils | brew | system | no | no | **keep** — system package (macOS only, Linux has it) |
| ffmpeg | brew | system | no | no | **keep** — system package |
| imagemagick | brew | system | no | no | **keep** — system package |
| libtool | brew | system | no | no | **keep** — system package |
| libxslt | brew | system | no | no | **keep** — system package |
| libyaml | brew | system | no | no | **keep** — system package |
| openblas | brew | system | no | no | **keep** — system package |
| openssl | brew | system | no | no | **keep** — system package |
| readline | brew | system | no | yes | **keep** — system package |
| unixodbc | brew | system | no | no | **keep** — system package |

---

## Summary

### Move to mise (~10 packages)

bat, fd, fzf, ripgrep, zoxide, neovim, go, node, python, rust

### Keep as native packages (~8 packages)

git, ranger, stow, tmux, tree, vim, wget, zsh

### Remove from bootstrap

Legacy `setup/update_brew.sh`, `asdf`, and `nvm` are removed. Optional tools
that are not part of the conservative default stay out of the package lists
until there is a concrete need to add them back.

### Config migrations completed in this pass

| Change | Files updated |
|--------|---------------|
| node → mise | `zsh/.zshenv`, `zsh/.zshrc`, `mise/.config/mise/config.toml` |
| nvm removal (tracked files) | `zsh/.zshenv` |
| native package lists | `Makefile`, `setup/packages/brew.txt`, `setup/packages/apt.txt`, `setup/packages/pacman.txt` |
| neovim entrypoint | `nvim/.config/nvim/init.vim` |

---

## Implementation status

| Item | Status |
|------|--------|
| Makefile with platform-aware targets | done |
| .zshrc fail-fast guard | done |
| Delete legacy setup scripts | done |
| Create mise config (`mise/.config/mise/config.toml`) | done |
| Add tracked nvim entrypoint (`nvim/.config/nvim/init.vim`) | done |
| Migrate fasd → zoxide (config + package) | done |
| Migrate node from nvm → mise (config + package) | done |
| Remove mercurial hg refs from vim/theme/fzf | done |
| Replace update_brew.sh with native package lists | done |
| docs/review.md mark resolved items | done |

---

## Review (round 1 — codex)

### Findings

1. Fixed: `make setup` brew check was parse-time — now runtime.
2. Fixed: `make install` calls `bash` not `sh`.
3. Fixed: brew prefix fallback covers Intel macOS.
4. Fixed: `_require-stow` runs first in `setup`.

### Summary

Makefile structural refactor is complete. Remaining work is the package
installation strategy (mise + parallel lists for system packages).

---

## Review (round 2 — codex)

### Findings

1. Fixed: mercurial deletion now notes live hg config deps; migration table added.
2. Fixed: fasd → zoxide now lists all config files that need updating.
3. Superseded by implementation: `mise` now lives at `mise/.config/mise/config.toml` and is stowed via its own package.
4. Fixed in tracked files: node migration removes the repo-managed nvm-specific shell init.

---

## Review (implementation pass — codex)

### Notes

1. Implemented the conservative split:
   `mise` handles pinned runtimes and cross-platform CLI tools, while
   `setup/packages/*.txt` covers the short native package lists.
2. `vim` remains the default editor. `neovim` is installed and supported via
   `nvim/.config/nvim/init.vim`, which sources the existing `~/.vimrc`.
3. The repo-managed nvm-specific shell init is removed. `mise` is activated
   in `zsh/.zshrc`, and `~/.local/share/mise/shims` is present in `PATH`
   from `zsh/.zshenv`.

### Summary

All migration dependencies are now tracked in the config migrations table
and implementation status.
