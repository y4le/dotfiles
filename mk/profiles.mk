# A saved choice is local to this checkout. Command-line values override it.
-include profile.mk

# PROFILE and WITH are intentionally make arguments, not ambient environment
# variables that may be set by unrelated tools.
ifeq ($(origin PROFILE),environment)
  PROFILE := full
endif
ifeq ($(origin WITH),environment)
  WITH :=
endif
PROFILE ?= full
WITH ?=

# Discovery stays available even when the saved selection references a retired pack.
PROFILE_DISCOVERY_ONLY := $(if $(strip $(filter-out help packs pack,$(MAKECMDGOALS))),,yes)
ifneq ($(filter profile-set,$(MAKECMDGOALS)),)
  ifneq ($(origin PROFILE),command line)
    $(error profile-set requires explicit PROFILE and WITH Make arguments; use WITH="" for no add-ons)
  endif
  ifneq ($(origin WITH),command line)
    $(error profile-set requires explicit PROFILE and WITH Make arguments; use WITH="" for no add-ons)
  endif
endif

profile_shell_quote = '$(subst ','\'',$(1))'
KNOWN_PROFILE_PACKAGES := $(shell sh mk/profile.sh all-packages)
ifeq ($(PROFILE_DISCOVERY_ONLY),)
PROFILE_COMPONENTS := $(shell sh mk/profile.sh components $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)) || printf '__invalid_profile__')
ifneq ($(filter __invalid_profile__,$(PROFILE_COMPONENTS)),)
  $(error invalid PROFILE or WITH selection; if profile.mk is stale, run 'make profile-set PROFILE=full WITH=""' or remove profile.mk)
endif
PROFILE_PACKAGES := $(shell sh mk/profile.sh packages $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)))
PROFILE_TOOLS := $(shell sh mk/profile.sh tools $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)))
endif
PROFILE_SOURCE := $(if $(filter command line,$(origin PROFILE)),command line,$(if $(wildcard profile.mk),saved profile.mk,built-in default))
WITH_SOURCE := $(if $(filter command line,$(origin WITH)),command line,$(if $(wildcard profile.mk),saved profile.mk,built-in default))

# Keep the execution order and the profile summary on the same selection.
profile_tool_steps = $(strip $(if $(or $(2),$(filter mise,$(1))),mise-tools) $(if $(filter zsh,$(1)),sheldon) $(if $(filter herdr,$(1)),herdr))
profile_plugin_steps = $(strip $(if $(filter zsh,$(1)),sheldon-plugins) $(if $(filter vim,$(1)),vim-plugins) $(if $(filter nvim,$(1)),nvim-plugins) $(if $(filter herdr,$(1)),herdr-plugins))
TOOL_STEPS := $(call profile_tool_steps,$(PROFILE_PACKAGES),$(PROFILE_TOOLS))
PLUGIN_STEPS := $(call profile_plugin_steps,$(PROFILE_PACKAGES))

.PHONY: profile profile-set packs pack

profile: ## [offline] show the selected setup components and tools
	@echo "profile: $(PROFILE)"
	@echo "profile source: $(PROFILE_SOURCE); add-on source: $(WITH_SOURCE)"
	@echo "add-ons: $(if $(strip $(WITH)),$(WITH),none)"
	@echo "components: $(PROFILE_COMPONENTS)"
	@echo "Stow packages: $(PROFILE_PACKAGES)"
	@echo "mise tools: $(PROFILE_TOOLS)"
	@echo "tool pins:"
	@pins="$$(awk -v action=entries -v selected=$(call profile_shell_quote,$(PROFILE_TOOLS)) -f mk/catalog.awk "$(MISE_CONFIG_FILE)")" || exit $$?; \
		printf '%s\n' "$$pins" | sed 's/^/  /'
	@shared="$$(sh mk/profile.sh tool-users $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)))"; \
		printf 'shared tools: %s\n' "$${shared:-none}"
	@echo "tool steps: $(TOOL_STEPS)"
	@echo "plugin steps: $(PLUGIN_STEPS)"

profile-set: ## [offline] save explicit PROFILE and WITH as the complete default
	@sh mk/save-profile.sh "$(CURDIR)" $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH))

packs: ## [offline] discover setup packs and preset membership
	@sh mk/profile.sh packs
	@echo "Desktop links: make DESKTOP=1 link; native prerequisites: docs/setup.md"

pack: PACK_PACKAGES = $(if $(NAME),$(shell sh mk/profile.sh pack $(call profile_shell_quote,$(NAME)) | sed -n 's/^Stow packages: //p'))
pack: PACK_TOOLS = $(if $(NAME),$(shell sh mk/profile.sh pack $(call profile_shell_quote,$(NAME)) | sed -n 's/^mise tools: //p'))
pack: ## [offline] describe one pack (NAME=...) and its restore steps
	@test -n $(call profile_shell_quote,$(NAME)) || { echo "pack: NAME is required (make pack NAME=nvim)" >&2; exit 2; }
	@sh mk/profile.sh pack $(call profile_shell_quote,$(NAME))
	@echo "restore targets: $(call profile_tool_steps,$(PACK_PACKAGES),$(PACK_TOOLS)) $(call profile_plugin_steps,$(PACK_PACKAGES))"
	@echo "Apply with make PROFILE=lite WITH=$(NAME) setup-user; preview with plan first."
	@echo "Recipes and prerequisites: docs/setup.md; desktop/native setup stays separate."
