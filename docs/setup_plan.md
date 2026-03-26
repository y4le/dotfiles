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
make setup        # full bootstrap: deps + packages + links
make link         # link dotfiles only (platform-aware)
make link-linux   # force linux stow set
make link-macos   # force macos stow set
make install      # install packages (brew on macOS, hint on Linux)
make sheldon      # install sheldon binary
make brew         # install homebrew (macOS only)
make clean        # unstow platform-matched packages
```

### Package classification (stow)

Explicit allowlists — every stow package must be classified. Unclassified
top-level directories are ignored (not silently stowed).

| Category   | Packages |
|------------|----------|
| **common** | agents, alacritty, bash, git, local, pet, scripts, tmux, vim, zsh |
| **linux**  | linux |
| **macos**  | osx |
| **skip**   | setup, docs, taskwarrior (deprecated) |

The Makefile auto-detects `uname -s` and stows `common + platform`.
`make clean` unstows the same set with `stow -D`.

### Package installation strategy

Two-tier approach:

**Tier 1 — mise** (cross-platform, no sudo, declarative `config.toml`):
Dev CLI tools and language runtimes. Replaces `asdf` and the bulk of
`update_brew.sh`. A single `~/.config/mise/config.toml` works everywhere.

Config lives at `zsh/.config/mise/config.toml` in this repo (stowed into
`~/.config/mise/config.toml` via the `zsh` package). Add `mise` to the
`COMMON` stow allowlist once the config file exists.

**Tier 2 — Native package manager** (system-level deps):
Libraries, build tools, core system packages. These require root and are
inherently platform-specific.
- macOS: `brew install` via `Brewfile` or script
- Debian/Ubuntu: `apt install`
- Arch: `pacman -S`

Parallel lists for tier 2 only — the list is short since mise handles
the bulk of dev tools.

### Bootstrap flow (`make setup`)

```
1. Ensure stow/xstow is available (error with install hint if missing)
2. Install mise (prebuilt binary or curl installer)
3. mise install (languages + dev tools from config.toml)
4. Install sheldon (prebuilt binary → ~/.local/bin)
5. Install system packages (native package manager, tier 2 only)
6. make link (platform-aware stow)
7. sheldon lock (fetch zsh plugins)
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

Full analysis of every package currently in `setup/update_brew.sh`.

`Used in dotfiles?` means a direct reference was found in tracked configs or
scripts during a repo-wide search. `no` means no direct reference was found; it
does not automatically mean the package is safe to remove.

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

### Move to mise (~15 packages)

bat, fd, fzf, jq, ripgrep, neovim, go, node, yarn, python, ruby, rust,
and optionally: sbcl, ocaml, opam, r

Plus replacements: eza (for exa), yt-dlp (for youtube-dl), delta (for
diff-so-fancy), zoxide (for fasd)

### Keep as system packages (~25 packages)

zsh, tmux, git, vim, gpg, htop, tree, wget, tldr, ranger, fpp, fortune,
ncdu, parallel, poppler, prettyping, pv, watch, watchman,
autoconf, automake, cmake, coreutils, ffmpeg, imagemagick, libtool,
libxslt, libyaml, openblas, openssl, readline, unixodbc

### Delete (~6 packages)

asdf (replaced by mise), mercurial (unused, config cleanup needed first),
flow (abandoned), octave (unused), fzy (redundant), sheldon (prebuilt binary)

### Config migrations required before package changes

These replacements/deletions have live config dependencies that must be
updated in the same pass:

| Change | Files to update |
|--------|----------------|
| fasd → zoxide | `zsh/.zshrc` (`zz` func, fasd alias guard), `zsh/.config/sheldon/plugins.toml` (oh-my-zsh fasd plugin), `scripts/.funcs/fzf_sources` |
| node/yarn → mise | `local/.pre_profile` (remove nvm init), `zsh/.zshenv` (remove nvm-aware npm prefix logic) |
| mercurial → delete | `vim/.vim/config/plugins.vim` (vim-signify hg, vim-lawrencium), `zsh/.config/zsh/themes/minimal.zsh-theme` (hg prompt), `scripts/.funcs/fzf_sources` (hg paths) |
| asdf → mise | `setup/update_brew.sh` (remove from package list) |
| diff-so-fancy → delta | `git/.gitconfig` (pager config if present), `zsh/.config/sheldon/plugins.toml` (zsh-diff-so-fancy was already removed in sheldon migration) |

---

## Implementation status

| Item | Status |
|------|--------|
| Makefile with platform-aware targets | done |
| .zshrc fail-fast guard | done |
| Delete legacy setup scripts | done |
| Create mise config (`zsh/.config/mise/config.toml`) | pending |
| Migrate fasd → zoxide (config + package) | pending |
| Migrate node/yarn from nvm → mise (config + package) | pending |
| Remove mercurial hg refs from vim/theme/fzf | pending |
| Replace update_brew.sh with tier 2 parallel lists | pending |
| docs/review.md mark #1, #3, #7 resolved | pending |

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
3. Fixed: mise config location specified (`zsh/.config/mise/config.toml`, stowed via `zsh` package).
4. Fixed: node/yarn migration now includes nvm removal from `.pre_profile` and `.zshenv`.

### Summary

All migration dependencies are now tracked in the config migrations table
and implementation status.
