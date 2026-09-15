# Download pins

`downloads.txt` is the reviewable trust boundary for bootstrap artifacts. Each
non-comment line has either five fields for a directly installed file or seven
fields for one exact member of a gzip-compressed tar archive:

```text
name version platform download_sha256 url [member installed_sha256]
```

Supported platforms are `linux-amd64`, `linux-arm64`, `darwin-amd64`,
`darwin-arm64`, and `any`. `mk/pinned.sh` verifies the downloaded bytes before
extracting anything, verifies the installed payload independently, and replaces
the destination atomically. The offline `make check-pins` target validates this
file and the installer behavior.

## Updating mise

Adopt a release only after reviewing its upstream notes. Prefer a release that
has been available for at least seven days unless the update fixes a security
issue.

1. Download `SHASUMS256.txt` and `SHASUMS256.txt.minisig` from the versioned
   mise GitHub release. Verify the signature when `minisign` is available.
2. Compare each archive and raw-binary hash with the corresponding GitHub
   release asset `digest` and with a locally computed SHA-256.
3. Confirm that every archive contains the single expected `mise/bin/mise`
   member and that its hash equals the published raw-binary hash.
4. Update all four mise rows together, run `make check-pins`, then test one real
   install and one no-network rerun in a disposable home.

Keep literal asset URLs here. Upstream platform naming belongs in this update
procedure, not in the installer.

## Updating Sheldon

Sheldon does not publish author-generated checksums. For each supported asset,
compare GitHub's release `digest` with a locally computed SHA-256 from an
independent download. Confirm that the archive contains a regular file named
`sheldon` at its root, then record that member's SHA-256 separately.

Before changing the pins:

1. Confirm the release is neither a draft nor a prerelease and has been public
   for at least seven days.
2. Confirm the Linux x86-64, Linux arm64, and macOS arm64 assets exist. Check
   whether upstream has added an Intel macOS asset.
3. Compare `sheldon --version` with the release version and the short prefix of
   the tagged commit returned by `git ls-remote`.
4. Update every supported row together, run `make check-pins`, then test a real
   install and a no-network rerun in a disposable home.

Sheldon 0.8 and newer currently publish no Intel macOS binary; the previous
`crate.sh` installer fails on that platform too. Install a trusted Sheldon binary
at `~/.local/bin/sheldon` through your organization or package manager, then run
`make mise-tools link plugins` instead of `make setup-user`. On corporate
networks, add an intercepting CA to the system trust bundle or set
`SSL_CERT_FILE`; the static Linux binary does not read Git's `http.sslCAInfo`.
Its musl resolver uses `/etc/resolv.conf`, so hostnames available only through
NSS modules may not resolve.

## Updating Sheldon plugin revisions

For a branch head, obtain the full commit with `git ls-remote` and review the log
and sourced-file diff from the old pin in a scratch clone. For a reviewed tag,
use its peeled `refs/tags/<tag>^{}` commit. The fzf plugin must use the peeled tag
matching the `aqua:junegunn/fzf` version in the mise config, and its `# v<version>`
comment must change in the same commit.

After updating a 40-character `rev`, run `make check-pins` and `make plugins`.
The latter fetches the commit and verifies the final checkout before replacing
the shell startup cache. If verification reports local changes, the dotfiles do
not delete them automatically. Either review and remove that checkout, or run
`SHELDON_DATA_DIR=<dir> ~/.local/bin/sheldon lock --reinstall` and retry. When
bumping the Sheldon binary, also reconfirm its
`repos/github.com/<owner>/<repo>` checkout layout.

## Updating vim-plug

vim-plug has no release assets, so pin the raw `plug.vim` file to the immutable
commit behind a reviewed release tag. Never use the `master` URL.

1. Resolve both the tag and its peeled target with
   `git ls-remote https://github.com/junegunn/vim-plug.git
   'refs/tags/<tag>' 'refs/tags/<tag>^{}'`. Use the peeled commit when the tag is
   annotated.
2. Download
   `https://raw.githubusercontent.com/junegunn/vim-plug/<commit>/plug.vim` and
   compare its SHA-256 with `git show <commit>:plug.vim` from a fresh clone.
   Also confirm that `git hash-object` of those bytes matches the GitHub contents
   API blob SHA for the same commit.
3. Review the `plug.vim` history and diff between the old and new commits, then
   update the single `vim-plug` row in `downloads.txt`.
4. Run `make check-pins`, test `make vim-plugins` in a disposable home, and run
   it again with network access disabled.

`:PlugUpgrade` follows upstream master. The next `make vim-plugins` deliberately
reports and replaces that drift with the reviewed version.
