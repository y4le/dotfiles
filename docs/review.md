# Dotfiles Review

Comprehensive audit of the dotfiles repo, covering bugs, staleness, dead code,
security, modernization, and structural improvements. Produced by Claude and
Codex working in parallel and then synthesized.

---

## Bugs (broken behavior)

These are actual runtime breakages or logic errors.

### Critical

| # | File | Line | Issue |
|---|------|------|-------|
| ~~B1~~ | ~~`scripts/bin/benchmark.sh`~~ | ~~1~~ | ~~Shebang is `#/bin/bash` — missing `!`. Script won't execute with the intended interpreter.~~ |
| ~~B2~~ | ~~`scripts/bin/benchmark.sh`~~ | ~~22~~ | ~~`[ -z cmd ]` should be `[ -z "$cmd" ]`. Always evaluates false (tests the literal string "cmd").~~ |
| ~~B3~~ | ~~`scripts/bin/benchmark.sh`~~ | ~~25~~ | ~~`return 1` at top-level in a script — should be `exit 1`. `return` only works inside functions or sourced scripts.~~ |
| ~~B4~~ | ~~`linux/.config/i3/config`~~ | ~~166~~ | ~~`Shift+Control+&mod+Right` — `&mod` is a typo for `$mod`. This keybinding silently does nothing.~~ |
| ~~B5~~ | ~~`taskwarrior/.config/zsh/sources/taskwarrior-aliases.zsh`~~ | ~~2-3~~ | ~~`return 0` followed by `echo` — the echo is unreachable dead code.~~ |
| ~~B6~~ | ~~`taskwarrior/.config/zsh/sources/taskwarrior-aliases.zsh`~~ | ~~24-25~~ | ~~Inverted retry logic: `$?` is checked after `command task "$@"` on line 22 already overwrites it. The `$? == 0` check means it retries when sync *succeeded*, not when it failed.~~ |

### High

| # | File | Line | Issue |
|---|------|------|-------|
| ~~B7~~ | ~~`alacritty/.config/alacritty/alacritty.yml`~~ | ~~289-295~~ | ~~Tmux shortcut key bindings send `\x02` (Ctrl-B prefix), but tmux is configured to use `C-Space` prefix. All Alacritty-tmux shortcuts are broken.~~ |
| ~~B8~~ | ~~`tmux/.tmux.conf`~~ | ~~50~~ | ~~Copy binding hardcodes `reattach-to-user-namespace cpy` — macOS-specific and will fail on Linux. Should conditionally check for the binary.~~ |
| ~~B9~~ | ~~`scripts/.funcs/cpst`~~ | ~~10-18~~ | ~~`cpy()` runs both `pbcopy` and `xclip` paths sequentially (not `elif`). On a system with both installed, input gets consumed by the first and the second gets empty stdin.~~ |
| ~~B10~~ | ~~`scripts/bin/compair.sh`~~ | ~~—~~ | ~~No shebang line. Behavior depends on whatever shell invokes it. Also uses `eval $cmd` which is fragile with special characters in filenames.~~ |
| ~~B11~~ | ~~`linux/bin/i3_switch_workspaces.sh`~~ | ~~3~~ | ~~`[ -z $@ ]` — unquoted `$@` in test. Should be `[ -z "$*" ]`.~~ |
| ~~B12~~ | ~~`linux/bin/i3_switch_workspaces.sh`~~ | ~~17~~ | ~~Calls `i3_empty_workspace.sh` which doesn't exist anywhere in the repo.~~ (inlined logic) |
| ~~B13~~ | ~~`taskwarrior/.config/taskwarrior/info/setup_taskd_client.sh`~~ | ~~1, 9~~ | ~~Declares `#!/bin/sh` but uses `[[ ]]` on line 9, which is a bashism. Will fail under dash or strict POSIX sh.~~ (file deleted) |

### Low

| # | File | Line | Issue |
|---|------|------|-------|
| ~~B14~~ | ~~`zsh/.zshrc`~~ | ~~109~~ | ~~`unalias zz` will error if the fasd oh-my-zsh plugin didn't create the alias (e.g., fasd not installed). Wrap in `(( $+aliases[zz] ))` guard.~~ |
| ~~B15~~ | ~~`zsh/.zshrc`~~ | ~~23-24~~ | ~~`a6='amd64'` and `x8='x86_64'` are hardcoded for x86. Breaks on Apple Silicon (`arm64`/`aarch64`).~~ |
| ~~B16~~ | ~~`scripts/bin/filez`~~ | ~~8-29~~ | ~~`--root` flag sets `root_file` but `fzf_sources` never uses it (only in debug output). The flag is effectively dead.~~ (wired up) |

---

## Security & Privacy

### Google-Internal Leakage

The repo was clearly migrated from a Google-internal environment. These
references should be cleaned up or moved to a gitignored local overlay:

| # | File | Line | Content |
|---|------|------|---------|
| ~~S1~~ | ~~`README.md`~~ | ~~1~~ | ~~`goto.google.com/who/loyale` link~~ |
| ~~S2~~ | ~~`osx/.config/zsh/sources/osx.zsh`~~ | ~~1-3~~ | ~~`g4d()` function with `/google/src/cloud/loyale/` path~~ (file deleted) |
| ~~S3~~ | ~~`vim/.ideavimrc`~~ | ~~33-41~~ | ~~Blaze-specific actions (`Blaze.OpenCorrespondingBuildFile`, `Blaze.PartialSync`, etc.)~~ |
| ~~S4~~ | ~~`pet/.config/pet/config.toml`~~ | ~~2~~ | ~~Hardcoded `/usr/local/google/home/loyale/` path~~ |
| ~~S5~~ | ~~`pet/.config/pet/snippet.toml`~~ | ~~3~~ | ~~Google-internal p4/citc workspace command~~ (file deleted) |
| ~~S6~~ | ~~`taskwarrior/.config/zsh/sources/taskwarrior-aliases.zsh`~~ | ~~6~~ | ~~`TASKD_HOST="yale.c.googlers.com"`~~ |
| ~~S7~~ | ~~`taskwarrior/.taskrc`~~ | ~~6~~ | ~~`taskd.credentials=Goog/Yale/0a817d0a-...`~~ |
| ~~S8~~ | ~~`taskwarrior/.config/taskwarrior/info/info.txt`~~ | ~~1-3~~ | ~~Org/ID metadata~~ (file deleted) |
| ~~S9~~ | ~~`taskwarrior/.config/taskwarrior/info/setup_taskd_client.sh`~~ | ~~21~~ | ~~Hardcoded Goog/Yale credentials~~ (file deleted) |
| ~~S10~~ | ~~`taskwarrior/.config/taskwarrior/info/certs.7z`~~ | ~~—~~ | ~~Bundled certificate archive — potentially sensitive~~ (file deleted) |
| ~~S11~~ | ~~`linux/.xsessionrc`~~ | ~~4, 7~~ | ~~References "gnome for trusty" and internal `g/i3-users/` note~~ |
| ~~S12~~ | ~~`linux/.config/i3/config`~~ | ~~218-220~~ | ~~Hardcodes `/usr/share/goobuntu-desktop-files/xsecurelock.sh`~~ |
| S13 | `.gitignore` | 1-2 | Entries for `google` and `amazon` directories — intentional, supports information isolation pattern |

### Other

| # | File | Line | Issue |
|---|------|------|-------|
| ~~S14~~ | ~~`taskwarrior/.taskrc`~~ | ~~7~~ | ~~`taskd.trust=ignore hostname` weakens TLS hostname verification~~ |
| ~~S15~~ | ~~`firefox/...userChrome.css`~~ | ~~path~~ | ~~Hardcoded Firefox profile ID `nvh7lqns.default` — machine-specific~~ (package deleted) |
| ~~S16~~ | ~~`zsh/.zshenv`~~ | ~~10~~ | ~~`BROWSER='chromium-browser'` — distro-specific, broken on macOS and many Linux distros~~ |

---

## Staleness (unmaintained/deprecated tools)

| # | Tool | Where Referenced | Status | Replacement |
|---|------|-----------------|--------|-------------|
| T1 | **zplug** | `zsh/.zshrc` | Unmaintained for years | zinit, sheldon, or antidote |
| T2 | **fasd** | `zsh/.zshrc` (plugin + command) | Archived/unmaintained | **zoxide** (Rust, actively maintained) |
| T3 | **junegunn/fzf-bin** | `zsh/.zshrc:30` | Deprecated repo | Use `junegunn/fzf` (ships binaries now) |
| T4 | **zdharma/fast-syntax-highlighting** | `zsh/.zshrc:46` | zdharma org deleted | **zdharma-continuum/fast-syntax-highlighting** |
| T5 | **w0rp/ale** | `vim/.vim/config/plugins.vim:65` | Repo moved | **dense-analysis/ale** |
| T6 | **scrooloose/nerdtree** | `vim/.vim/config/plugins.vim:53` | Repo moved | **preservim/nerdtree** |
| T7 | **majutsushi/tagbar** | `vim/.vim/config/plugins.vim:58` | Repo moved | **preservim/tagbar** |
| T8 | **youtube-dl** | `setup/update_brew.sh:45` | Effectively dead | **yt-dlp** |
| T9 | **exa** | `setup/update_brew.sh:23` | Unmaintained (author posted notice) | **eza** (maintained community fork) |
| T10 | **vimpager** | `zsh/.zshenv:18`, vim plugins | Niche, largely superseded | **bat** + **less** |
| T11 | **Alacritty YAML** | `alacritty/.config/alacritty/alacritty.yml` | Deprecated config format | Migrate to `alacritty.toml` (TOML) |
| T12 | **reattach-to-user-namespace** | `tmux/.tmux.conf:50` | Not needed on modern macOS/tmux | Remove; tmux 2.6+ handles clipboard natively |
| T13 | **Homebrew install URLs** | `setup/maybe_install_brew.sh:7,10` | Obsolete `master` branch URLs | Use `Homebrew/install/HEAD/install.sh` |
| T14 | **mercurial (hg)** | Theme, vim-signify, vim-lawrencium, fzf_sources | Likely unused | Remove hg integration unless actively used |
| T15 | **Linuxbrew** | `setup/maybe_install_brew.sh:10-14` | Merged into Homebrew | Update to current Homebrew-on-Linux flow |

---

## Dead Code

| # | File | Line | Description |
|---|------|------|-------------|
| D1 | `vim/.vim/plugin/resize_mode.vim` | 1-53 | Entire file is commented out except for a 2-line header. ~50 lines of dead code. |
| ~~D2~~ | ~~`scripts/.funcs/cpst`~~ | ~~32-34~~ | ~~Leftover `foobar()` test function.~~ |
| D3 | `setup.sh` | 9-10 | Commented-out brew install/update lines. |
| D4 | `vim/.vim/config/plugins.vim` | 114-115 | `ycm_filetype_blacklist` config for YouCompleteMe, but YCM is commented out (line 62). |
| D5 | `vim/.vim/config/plugins.vim` | 113 | `gutentags_cache_dir` setting, but vim-gutentags is commented out (line 57). |
| D6 | `vim/.vim/config/plugins.vim` | 92-97 | Language plugins for CoffeeScript, Ruby, Lisp — assess if still used. |
| ~~D7~~ | ~~`scripts/bin/filez`~~ | ~~`--root` flag~~ | ~~Accepted but never functionally used by `fzf_sources`.~~ (wired up) |
| ~~D8~~ | ~~`taskwarrior/.config/zsh/sources/taskwarrior-aliases.zsh`~~ | ~~3~~ | ~~Unreachable `echo` after `return 0`.~~ |

---

## Modernization Opportunities

### High Value

1. **zplug → zinit or sheldon** — zplug is unmaintained and slow. zinit (formerly zplugin) or sheldon (Rust) are actively maintained and faster. This is the highest-impact modernization since it affects shell startup time and plugin reliability.

2. **fasd → zoxide** — zoxide is a drop-in improvement: faster (Rust), actively maintained, same `z` command interface. The `zz` function in `.zshrc` can be replaced by `zi` (zoxide interactive).

3. **Alacritty YAML → TOML** — newer Alacritty versions only support TOML. The current YAML config will stop working on upgrade. Strip the extensive comments (most are defaults) during migration.

4. **Fix clipboard abstraction** — `cpy`/`pst` should use `elif` chains and add `wl-copy`/`wl-paste` for Wayland support.

### Medium Value

5. **exa → eza** and **youtube-dl → yt-dlp** — simple package name swaps in brew list.

6. **vim-plug repo names** — update `scrooloose/nerdtree` → `preservim/nerdtree`, `majutsushi/tagbar` → `preservim/tagbar`, `w0rp/ale` → `dense-analysis/ale`.

7. **Vim-to-FZF coupling** — `plugins.vim:75` hardcodes `~/.zplug/repos/junegunn/fzf` for the fzf runtime path. This couples vim startup to zplug's on-disk layout. Let vim-plug manage its own fzf copy, or use a system-installed fzf.

8. **Neovim entrypoint** — `update_brew.sh` installs neovim, and `plugins.vim` has nvim-specific paths, but there's no `init.vim` or `init.lua`. If neovim is a target, add a proper config. If not, remove the neovim references.

### Nice to Have

9. **Consider Nerd Fonts** — Alacritty config uses "Inconsolata for Powerline". Nerd Fonts (which superset Powerline) are more widely supported by modern tools.

10. **NERDTree → oil.nvim or nvim-tree** — if migrating to neovim as primary editor.

11. **rofi config format** — rofi deprecated the old `rofi.key: value` format in favor of a rasi config file.

---

## Structural Improvements

### Setup & Bootstrap

1. **Stow platform logic is inverted** — `symlinks.sh` blacklists `osx` and `taskwarrior` but does *not* blacklist `linux`. Running `./setup.sh` on macOS will stow Linux-specific files (i3, xbindkeys, xsession) into `~`. Should auto-detect platform and only stow the relevant directory, or maintain explicit allowlists per platform.

2. **Side effects in .zshenv** — `.zshenv` runs on *every* shell (including non-interactive subshells, scripts, cron). Lines 36-44 run `mkdir -p` and `npm config --global set prefix` unconditionally. These should move to `.zshrc` or a one-time setup script.

3. **Bootstrap happens at shell startup** — zplug clones itself on first shell open (`.zshrc:11`), and TPM auto-installs on first tmux session. This is convenient but means first-shell-open is slow and network-dependent. Consider moving to explicit setup.

4. **Brew lists are stale** — `update_brew.sh` includes tools that may no longer be relevant (octave, mercurial, sbcl, flow, opam). Worth pruning to reduce install time.

5. **Missing `asdf` config** — `update_brew.sh` installs asdf ("replaces rvm/nvm") but `.pre_profile` sets up nvm. Pick one or document the intended flow.

### Organization

6. **No CLAUDE.md** — a project-level `CLAUDE.md` would help Claude Code understand the repo structure, conventions, and local override patterns.

7. **Consider a Makefile or justfile** — for discoverable setup commands (`make install`, `make link-linux`, `make link-macos`) rather than the current `setup.sh` which has limited options.

8. **XDG compliance is inconsistent** — some configs use `~/.config/` (alacritty, tmux, zsh themes) while others use `~/` (`.vimrc`, `.tmux.conf`, `.taskrc`). Full XDG compliance would be a large refactor but worth noting.

---

## Summary of Priorities

### Fix Now (bugs affecting daily use)
- ~~B4: i3 `&mod` typo~~
- ~~B7: Alacritty/tmux prefix mismatch~~
- ~~B1-B3: benchmark.sh shebang and logic errors~~
- ~~B6: Taskwarrior inverted retry logic~~
- ~~B9: cpy/pst double-execution~~

### Clean Up Soon (security/privacy)
- ~~S1-S13: Remove or gitignore all Google-internal references~~
- ~~S10: Evaluate whether `certs.7z` should be in the repo at all~~
- ~~S14: Fix `taskd.trust=ignore hostname`~~

### Modernize When Ready (staleness)
- T1-T2: zplug → zinit/sheldon, fasd → zoxide (highest impact)
- T11: Alacritty YAML → TOML (will break on upgrade)
- T4-T7: Update stale GitHub repo URLs
- T8-T9: exa → eza, youtube-dl → yt-dlp

### Address Eventually (structure)
- Platform-aware stow setup
- Move npm side effects out of `.zshenv`
- Prune dead code and commented-out blocks
- Decide neovim's role

---

## Methodology

This review was produced by Claude (primary analysis — read all files, compiled
findings) and Codex (independent parallel audit — explored repo in read-only
sandbox, performed web searches on tool maintenance status). Findings were
cross-referenced and deduplicated. Areas of agreement are noted; Codex
contributed additional findings on taskwarrior bugs (B5, B6), the stow
platform logic issue, `.zshenv` side effects, the vim-fzf-zplug coupling,
and the benchmark.sh variable quoting bug (B2).

---

| Metric | Value |
|--------|-------|
| Mode | research (open-ended) |
| Agent | Codex CLI v0.101.0 |
| Cost | N/A (Codex CLI does not report cost) |
| Tokens | N/A (Codex CLI does not report tokens) |
| Duration | 735s |
| Session | `/tmp/parley-lite-dotfiles-review-99669` |
