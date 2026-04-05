# Syncthing Plan

## Status

Not implemented. As of 2026-04-05, the repo has no `syncthing` targets in the
`Makefile` and no repo-managed Syncthing package.

## Constraints

- this must be opt-in per machine
- it must not run as part of default `make setup`
- work machines should be able to use the repo without ever downloading the
  synced files
- we should not track machine-specific Syncthing state in dotfiles
- do not track Syncthing's live config (`config.xml`, keys, database state,
  device IDs, API keys)
- sync only `~/sync`, not `$HOME`

## TODO

### Commands

- `make syncthing-install`
- `make syncthing-enable`
- `make syncthing-disable`
- `make syncthing-status`

Optional later:

- `make syncthing-id`
- `make syncthing-gui`

### Implementation Shape

- keep Syncthing out of default package lists and out of `make setup`
- prefer the native service story instead of a repo-managed unit by default

Linux:

- install the package
- run `systemctl --user enable --now syncthing.service`

macOS:

- install with Homebrew
- run `brew services start syncthing`

Do not add a `syncthing/` stow package unless a later change actually needs
tracked override files or helper assets.

### Sync Folder

```sh
~/sync
```

`make syncthing-enable` should create the directory if it does not exist.

Only this folder is shared. Do not sync dotfiles, `$HOME`, or any
machine-specific config paths.

### Enrollment Model

Keep enrollment manual and approval-based:

- no automatic device acceptance
- no automatic folder acceptance
- no implicit enrollment during bootstrap

Example flow on a new personal machine:

1. `make syncthing-install`
2. `make syncthing-enable`
3. `syncthing --device-id`
4. add that device from an already-trusted machine
5. share only the `sync` folder
6. accept the folder locally at `~/sync`

If one always-on machine exists, the introducer feature is worth considering,
but it should stay an explicit opt-in choice, not the default plan.

### Local State

Syncthing keeps its own machine-local state, which remains untracked. Typical
locations vary by platform and version:

- newer Linux: `~/.local/state/syncthing/`
- older Linux: `~/.config/syncthing/`
- macOS: `~/Library/Application Support/Syncthing/`

Repo code should avoid depending on those paths unless a helper target has a
clear reason to inspect them.

### Makefile Scope

- install Syncthing through the platform package manager
- create `~/sync`
- enable and disable the user service
- print status and next-step guidance

Important: none of these targets should be dependencies of `make setup`.

### Scripts

Start without a dedicated helper script. If the Makefile target bodies become
too repetitive or platform-specific, move the shared logic into `scripts/bin/`.

### Documentation

- Syncthing is optional
- only `~/sync` is shared
- live Syncthing state is never tracked
- new devices and folders still require manual approval

## Success Criteria

- work machines can keep using the repo without Syncthing installed
- personal machines can opt in with a small set of explicit commands
- the repo never tries to sync or version-control Syncthing identity/state
