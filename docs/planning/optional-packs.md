# Optional packs proposal

Design pass with Claude Fable, 2026-10-01. This is a proposal; the current
profile behavior documented in [setup](../setup.md) and [design](../design.md)
still applies. No new packs or installers are provided by this document.

## Recommendation

Extend the existing shallow components into a discoverable pack catalog. A
pack is a coherent setup someone wants on a machine; a profile is a preset
list of packs. Keep Make as the command surface and existing installers as
the execution layer. Generalize selection and preview across useful setups,
while adding installation support only for concrete needs.

Start with the existing Stow and mise payloads. Other recurring tools fit
this model just as well as language development. OS setups can share the
discovery and preview surface, but native installation, services, and system
settings need their own explicit phases. Keep `DESKTOP` separate initially.

Occasional commands do not need public packs. The decision to install `fd`,
`wget`, and `rclone` locally still stands. A Haskell development pack remains
a candidate because it represents a toolchain with setup and activation,
rather than a single command to download.

## What needs to change

Today, `setup/profiles.yaml` selects Stow packages and tools for installation.
It requires `full` to include every component and each tool to belong to one
component. That makes a genuinely optional component outside `full`
impossible, and makes overlapping setups difficult to express.

There is also a distinction between installation and activation. The entire
mise catalog is linked as the global configuration, including tools omitted
from the selected install list. A lite machine can therefore resolve the
development pins, and a later unqualified `mise install` can install them.
The current promise is selective installation, rather than a selective global
tool configuration. Packs should provide both.

The native package lists are currently independent of profiles. Desktop
selection links configuration; it does not install the full desktop stack.
Those distinctions remain useful and should be visible in the pack UX.

## Flat membership and shared tools

Retain the shallow manifest: named components with direct `packages` and
`tools` lists, and profiles containing component names. Calling these packs
in the UI does not require a schema rename. Add a one-line `summary` property
for discovery, with explicit parser support and validation. Native prerequisite
guidance stays in documentation initially; defer prerequisite/platform fields
until a concrete native pack needs them.

Change two constraints:

- `full` becomes a curated preset. Adding a catalog entry does not put it in
  the default setup. Preserve its existing membership during migration.
- Several packs may reference the same mise key. The canonical catalog owns
  its version and options once; selection takes the union of referenced keys.

For example, prospective packs could be:

| Pack | Direct tool references | Purpose |
| --- | --- | --- |
| `web-dev` | Node, Prettier, TypeScript language server | Web editing and development |
| `prose` | Node, Prettier | Markdown, wiki, and book formatting |
| `python-dev` | Python, uv, basedpyright, Ruff | Python tooling |
| `haskell-dev` | Provider and tool selection still to be designed | Haskell development on machines that need it |

These names and the split of today's `dev` component are illustrative.
Selecting both `web-dev` and `prose` installs Node and Prettier once. Removing
`web-dev` retains them while `prose` is selected. Each pack lists its own
required runtime; there is no `requires` graph, profile inheritance, or pack
dependency resolution.

Keep one owner per Stow package for now. Shared tools solve a concrete
overlap; shared configuration membership has no demonstrated need. Continue
rejecting competing managed paths, including local/private overlays.

Resolve tool output in canonical catalog order, independent of `WITH` order.
Preserve the existing runtime/bootstrap ordering, including uv before pipx
tools. Validate that each npm tool's pack includes Node and each pipx tool's
pack includes the Python/uv prerequisites used by this setup. Make continues
to own installer and plugin step ordering; pack entries contain no arbitrary
shell hooks.

Require every tool catalog key to be referenced by a pack and every reference
to resolve. Replace the current use of `full` as exhaustive coverage with a
synthetic all-packs selection in checks. Keep explicit tests of the actual
`full` and `lite` defaults, including their current membership.

## Selection UX

Use the existing `PROFILE` and `WITH` Make arguments. Avoid a second selection
file or a new CLI. The following commands describe the proposed interface;
`packs` and `pack` do not exist today, and the example language packs are not
implemented:

```sh
make packs
make pack NAME=python-dev
make PROFILE=lite WITH="nvim python-dev prose" plan
make profile-set PROFILE=lite WITH="nvim python-dev prose"
make plan
make setup-user
```

`packs` should list each pack's purpose and profile membership, alongside
separate guidance for desktop/native setup. `pack` should print its summary,
tools, configs, and known restore targets, then link to documentation for
installation recipes, native prerequisites, and remaining manual steps. Discovery must
still work when a saved selection is stale: discovery-only `help`, `packs`,
and `pack` invocations load the catalog without resolving `profile.mk`.
Invocations that also apply configuration still validate the selection.
Applying an unknown or unsupported selection fails before changing the machine.

`plan` should show the requested selection and where it came from, the
resolved tools with versions, shared tools and the packs requesting them,
link/configuration changes, planned restore steps, and installed-but-unselected
tools whose shims may become unusable. Link to the native prerequisite guide;
automatic prerequisite detection waits for typed native membership. State
which phases need network access or administrator privileges. Planning does
not install, download, invoke sudo, or write the active configuration.

Saving and applying remain separate. A one-off `WITH=... plan` neither saves
the choice nor changes activation. Explicit arguments to `link` or
`setup-user` apply that selection without changing the saved default, just
as explicit link selections do today. A later invocation using the saved
default can therefore change it back; preview must make this visible.

Make saving a complete selection explicit: require both `PROFILE` and `WITH`
on `profile-set`, with `WITH=""` meaning no add-ons. Print the previous and
new selection, including dropped packs, before reporting the save. This
replaces today's implicit clearing of add-ons when `WITH` is omitted. Do not
add incremental add/remove commands until repeated use warrants them. Update
the setup and maintenance recovery recipes and Make's stale-selection error
to include explicit `WITH=""`; this is a proposed command contract change.

Keep `profile.mk` checkout-local and ignored. Keep `DESKTOP`, native packages,
`local/`, and the private agent overlay outside the saved pack selection in
the first implementation. Selecting a pack never enables private agents.

## Selected mise configuration

Keep one version catalog outside the Stow tree, for example
`setup/tools.toml`. The Stow-managed global mise configuration retains the
existing settings that disable automatic installation, but no tool pins.
At configuration apply time, render the selected catalog entries into
`~/.config/mise/conf.d/dotfiles.toml`.

This is a deliberate, narrow exception to the symlink model: the active tool
list is machine-specific derived configuration. Static per-pack mise
fragments would avoid a renderer, but would duplicate shared pins or require
another composition layer. A single generated file keeps membership and
versions separate without making terminal startup compute a selection.

Mise merges tool configurations additively and lets higher-precedence
configuration override values. Its global `config.toml` is loaded after
global `conf.d` fragments. Keeping the complete catalog in that global file
would defeat selection; selection takes effect only once pins leave the global
file, after preparing the fragment as described below.
Project configuration and machine-local overrides may still select other
tools or versions. Recommend `~/.config/mise/config.local.toml` for local
overrides rather than relying on the alphabetical order of `conf.d` fragments.
See the official [configuration
reference](https://mise.jdx.dev/configuration.html).

The generated file needs an ownership marker and safe replacement rules:
preflight conflicts, preserve foreign files, write atomically, and remove
only a verified owned file on `clean`. The marker explicitly means the file
is replaced on apply, including local edits; preview shows the diff and the
header directs overrides to `config.local.toml`. Do not add checksum state
just to protect edits to a derived file. Deselecting a pack updates its entries
rather than deleting tools. Rendering happens during `link`, so standalone
configuration application and `setup-user` agree; preview and saving never
render into HOME.

Install explicit selected tool names against the full catalog using
`MISE_GLOBAL_CONFIG_FILE`, with ancestor lookup bounded by the physical
checkout ceiling as today. This override excludes the old HOME configuration
and fragments; a temporary selected install manifest is unnecessary. Keep
the checkout free of a competing project mise config. Installation must work
before linking. Update fzf/Neovim restore helpers, catalog validation, and CI's
hard-coded catalog paths together. The renderer must not require Python to
bootstrap a lite machine.

Preflight owned-file conflicts before network work in `setup-user`; install
desired tools before applying their active configuration. Do not promise a
transaction across downloads, Stow, and plugin restores. A failed restore
can leave completed phases behind and should be safe to rerun. Standalone
`link` stays offline and may select tools that are not yet installed; report
that state rather than installing them implicitly.

Removing a pack means stopping dotfiles management of its tools and configs.
Installed versions, native packages, plugins, and user data remain. However,
an installed mise tool's shim remains after its pin is removed and may fail
with "No version is set for shim". `command -v` and Neovim's `executable()`
can still report it as present, and `mise reshim --force` alone retains it.
Current deselection leaves the global pin working; selected configuration
deliberately changes that behavior. System copies may provide fallback, and
project/local pins can make a retained installation usable again.

Before shipping selected configuration, make editor selection and LSP/tool
detection check effective availability when the found executable is a mise
shim. Use noninteractive offline resolution, such as `mise which`, rather than
a pack-name permission check; support project/local versions and fallback to
actual system executables. Ordinary non-shim commands retain cheap presence
checks. Prefer resolving the default editor at use time through a small
launcher, preserving today's no-mise-startup-probe check. Validate consumers
of `EDITOR`/`VISUAL` with that launcher. An alternative resolver in `.zshenv`
would run in every Zsh, including noninteractive child shells; choosing it
requires measured cost and an explicit revision of the startup check.
Never prompt or install while resolving or probe every optional tool on shell
startup. A full-to-lite switch with only an unconfigured Neovim shim must fall
back to Vim and avoid enabling failing LSP/formatter shims. Usable local/project
or system tools remain eligible. This integration work belongs in the
selected-configuration slice.

For retained tools, document local pin overrides and the existing explicit
[uninstall/reshim recipe](../maintenance.md#retired-utilities-and-vim-profiler)
when no project needs the old versions. Setup does not run that uninstall.
Selection governs managed defaults, not which commands a project may use.

The existing global config is a live symlink into the checkout: removing its
pins on pull creates a gap before `link` writes the fragment. Use a two-stage
cutover. First introduce rendering from the existing catalog and apply the
owned fragment on existing machines while leaving the full global pins intact.
Then move the catalog and switch the managed global config to settings-only.
Document that machines skipping the preparatory stage must run offline
`make link` immediately after pulling, before relying on managed commands;
run `setup-user` afterward for any missing installations. Make and Stow must
remain available independently of the affected shims. Check both upgrade
paths; a normal fresh-HOME test alone does not exercise this gap.

## Other tools and OS setups

Generalize the concept to recurring capabilities now. An editor, a file
manager, or a future media CLI tool set can use the same flat membership when
existing backends suffice. Container clients may fit; installing their daemon
or runtime needs the native/service path below. Each addition needs an actual
use case and explicit support; the catalog should not become a mirror of a
package index.

Generalize execution gradually:

| Setup kind | Initial treatment | Boundary |
| --- | --- | --- |
| Stow configs and mise tools | Pack membership using existing backends | `link` is offline; `setup-user` restores user tools/plugins |
| Checked bootstrap binaries such as Herdr | Existing explicit Make steps associated with their pack | Pins and installer behavior remain in the existing bootstrap layer |
| Native prerequisites | Link prerequisite documentation; retain existing platform lists | Installation remains `system-packages` or the native phase of `setup` |
| Desktop setup | Discoverable guidance using existing `DESKTOP=1` selection | No automatic installation of the desktop stack |
| Services, OS settings, agent integrations | Specific documented targets or recipes | Explicit invocation; no generic activation/deactivation hooks |

When a concrete OS pack is needed, add typed native package membership and
platform support rather than shell commands embedded in YAML. An unsupported
selection should fail clearly, not silently skip part of the pack. Resolve
package-manager names explicitly and preview the resulting native phase.
`setup-user`, `link`, and shell/editor startup must never escalate privileges
or start services. Deselection does not remove native packages or disable
services. A native package manager may require administrator access; the
preview should describe the actual backend, including Homebrew's distinction
from the Linux sudo path.

Leave desktop selection separate until real OS examples establish the desired
behavior, including whether desktop choices should persist and how previously
linked desktop files should be reconciled. Today's `DESKTOP=0` does not remove
existing desktop links. Converting it into a pack would need a migration and
an explicit decision about that behavior.

For Haskell, first choose and validate a single toolchain provider, its native
prerequisites, and activation on the supported machines. Do not manage the
same compiler through both GHcup and mise. A pack may provide a machine
baseline while project configuration chooses project versions. Most machines
should continue without this pack; no unconditional GHcup startup import
returns. Project environments and virtualenvs must retain PATH precedence.

## Implementation slices and decisions

1. Add catalog discovery, allow shared tool references, and make `full` a
   curated preset. Preserve current default membership. Validate all packs
   without relying on `full`, and make stale-selection discovery/recovery
   usable. Add validated summaries and make complete saved selections explicit,
   updating the existing recovery commands.
2. Separate the tool catalog from active configuration and add the owned
   selected mise projection using the two-stage cutover above. Update pre-link
   installers, restore helpers, effective runtime detection, CI, cleanup, and
   migration docs together. Ship this before introducing a pack outside `full`,
   so the first optional pack is optional in global mise too.
3. Pilot a useful split of the existing broad `dev` component. Choose which
   packs belong in `full` with the owner; preserve `WITH=dev` as a broad direct
   tool list during migration if compatibility is needed. Add Haskell only
   when a machine actually needs a supported setup.
4. Use the first concrete OS/tool request to decide whether native membership
   or desktop integration earns its extra schema and tests. No OS examples
   have yet been chosen for this proposal.

Before implementation, settle the desired default development packs and the
first additional use case. The current design is enough for tools using Stow,
mise, or existing bootstrap steps; it intentionally leaves new providers and
OS actions to their own concrete design pass.

Implementation checks should cover shared-tool retention after deselection,
order-independent selection, runtime prerequisites, a pack outside `full`,
stale saved selections, and migration of the existing global mise symlink.
Use isolated homes to check generated-file ownership, local/project overrides,
pre-link installation resolution, missing installations, stale-shim editor/LSP/
formatter fallback, cleanup, and offline startup cost. Check fresh and upgraded
homes, including a skipped preparatory release. Check native preview separately
from privileged execution when that extension is introduced. Run `make check`
and relevant clean-machine restore checks for each implementation slice.

For this design pass, isolated offline probes against the pinned mise 2026.9.0
confirmed that the current global catalog resolves omitted development tools,
a settings-only global config plus selected fragment resolves only selected
keys, a project version overrides the global version, and removing the fragment
removes its requested keys. Further scratch-HOME probes with a fake Node install
confirmed retained shims fail after deselection and remain after forced reshim;
direct catalog override with the physical ceiling ignores old HOME and ancestor
configs. The probes installed nothing and changed no host configuration. These
validate configuration and shim behavior, not the unimplemented installer,
runtime fallback, migration, or native-package behavior.
