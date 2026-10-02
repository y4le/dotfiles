# Setup qualification, 2026-10-01

The optional-pack implementation was qualified with three clean Linux ARM64
homes and the GitHub Linux/macOS workflow. Compatibility migrations remain
in place until existing machines have been updated.

## Clean-home bootstrap

Each selection started from an independent clone of `12ea9c6` in an empty
HOME, in an Ubuntu 24.04 container with only Git, Make, Stow, sudo, and CA
certificates preinstalled. Native packages and user tools were installed by
the real `make setup`; no host configuration was linked or changed.

| Selection | Selected mise tools | Bootstrap and repeat setup | Offline startup |
| --- | ---: | --- | --- |
| `PROFILE=full WITH=""` | 10 | Passed | Passed; Neovim default |
| `PROFILE=lite WITH=""` | 5 | Passed | Passed; Vim default |
| `PROFILE=lite WITH=node` | 6 | Passed | Passed; Vim default and Node |

For each selection, `make plan` ran before and after bootstrap. The resulting
mise fragment matched the selected catalog keys, every selected installation
existed, and no unselected catalog tool was installed. Repeating
`make setup-user` preserved the fragment's contents and inode. All repository
trees remained clean, including ignored and untracked files.

In both Node-enabled homes, Node matched the catalog pin and npm's prefix
was `~/.local/share/npm`. Lite without Node had no Node installation or
effective Node selection.

Offline checks reused the installed native packages and restored HOME with
Docker networking disabled, `MISE_OFFLINE=1`, and dead HTTP proxies. They
covered interactive Zsh startup, the default editor, and Git editor
selection. Both Node-enabled homes launched a small CLI from npm's bin
directory through `#!/usr/bin/env node`. This verifies PATH and runtime
availability; Codex and Gemini packages, authentication, and service calls
were not exercised.

Full passed the restored Neovim first-open checks for Lua, shell, Org,
Markdown, wiki, and book files offline. Lite homes had no Neovim, Atuin, or
Herdr configuration links. Offline checks passed again after updating the
clones to `da00d52`, whose only changes since bootstrap are the test fixes
described below.

## CI and portability fixes

The first [workflow run](https://github.com/y4le/dotfiles/actions/runs/36958788890)
passed Linux checks and actionlint but exposed four macOS fixture failures.
`43dfcdd` escapes an awk regex delimiter for BSD awk and canonicalizes
temporary roots in the availability, linking, and Vim-history fixtures.
These tests expected logical paths while the programs returned physical
paths. Production behavior was unchanged.

The complete local `make check` passed with `TMPDIR` pointing through a
symlink. Claude Fable reviewed the actual fix through native Herdr and
approved it before commit.

The [rerun at `43dfcdd`](https://github.com/y4le/dotfiles/actions/runs/36959592201)
cleared those failures, then reached a fifth fixture failure: nested shell
grouping in the picker stub was parsed as Bash arithmetic. `da00d52` adds
whitespace between the groups and runs the picker assertions under both
`sh` and Bash. The complete local check suite passed again, and Fable
approved that actual diff before commit.

The [final workflow at `da00d52`](https://github.com/y4le/dotfiles/actions/runs/36960019429)
passed all four jobs: actionlint, offline Linux/macOS checks with explicit
Sheldon and vim-plug fixtures, and the dispatched Linux x86-64 clean-HOME full
bootstrap with restored Neovim named-file checks. The runner also verified
that checks and bootstrap left the repository clean.

## Remaining boundaries

Fresh macOS and Arch bootstraps and upgrades of real pre-cutover machines
remain unqualified. Isolated migration tests remain in the suite. Live
terminal clipboard receipt, i3 locking/navigation/bar behavior, and Karabiner
GUI recovery still need target-machine observations; automated checks do
not close those items.

The CI check jobs still skip the optional real-fzf NUL-filter case because
fzf is not on their PATH. That case passed in the local `make check`; it
remains a gap in recurring CI coverage.

At the time of writing, local logs and disposable HOME trees are retained at
`/tmp/dotfiles-qualification-20261001-vc67arkx`; the workflow links above are
the remote evidence. The verification branch is
`verify/bootstrap-20261001-12ea9c6`; remote `master` was not updated.
