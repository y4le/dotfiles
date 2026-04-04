[#](#) Syncthing Plan

## Status

Proposed only. As of 2026-03-31, the repo has no `syncthing` targets in the
`Makefile` and no repo-managed Syncthing package.

## Problem

I want an optional Syncthing setup for a shared `~/sync` directory across my
personal machines.

Constraints:

- this must be opt-in per machine
- it must not run as part of default `make setup`
- work machines should be able to use the repo without ever downloading the
  synced files
- we should not track machine-specific Syncthing state in dotfiles

## Goal

Add a Syncthing workflow that makes personal-machine setup easy while keeping
the default bootstrap unchanged and safe for machines that should never
participate.

## Non-Goals

- automatically enrolling every machine in the sync mesh
- automatically accepting new devices or folders
- syncing the Syncthing config directory itself between machines
- managing secrets or approval state in git

## Hard Constraints

- do not track Syncthing's live config (`config.xml`, keys, database state,
  device IDs, API keys)
- keep Syncthing out of default package lists and out of `make setup`
- sync only `~/sync`, not `$HOME`

## Proposed Design

### Commands

Add explicit optional targets only:

- `make syncthing-install`
- `make syncthing-enable`
- `make syncthing-disable`
- `make syncthing-status`

Optional follow-ups if they prove useful:

- `make syncthing-id`
- `make syncthing-gui`

### Install and Service Model

Prefer the native service story instead of a repo-managed unit by default:

- Linux: install the package and run
  `systemctl --user enable --now syncthing.service`
- macOS: install with Homebrew and use `brew services start syncthing`

Do not add a `syncthing/` stow package unless a later change actually needs
tracked override files or helper assets.

### Sync Folder

Standardize on:

```sh
~/sync
```

`make syncthing-enable` should create the directory if it does not exist.

Only this folder is shared. We should not sync dotfiles, `$HOME`, or any
machine-specific config paths.

### Enrollment Model

Enrollment stays manual and approval-based:

- no automatic device acceptance
- no automatic folder acceptance
- no implicit enrollment during bootstrap

CLI-first flow is preferred; the GUI is optional.

Example enrollment flow on a new personal machine:

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

## Planned Repo Changes

### Makefile

Add optional targets for:

- installing Syncthing through the platform package manager
- creating `~/sync`
- enabling and disabling the user service
- printing status and next-step guidance

Important: none of these targets should be dependencies of `make setup`.

### Scripts

Start without a dedicated helper script. If the Makefile target bodies become
too repetitive or platform-specific, move the shared logic into
`scripts/bin/`.

### Documentation

Document the CLI-first enrollment path and keep the safety rules explicit:

- Syncthing is optional
- only `~/sync` is shared
- live Syncthing state is never tracked
- new devices and folders still require manual approval

## Safety Defaults

Defaults should bias toward not sharing data accidentally:

- no default install
- no default enable
- no auto-accept
- no home-directory sync
- no tracked machine-local Syncthing config

## Success Criteria

- work machines can keep using the repo without Syncthing installed
- personal machines can opt in with a small set of explicit commands
- the repo never tries to sync or version-control Syncthing identity/state
