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
