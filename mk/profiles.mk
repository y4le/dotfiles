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

profile_shell_quote = '$(subst ','\'',$(1))'
PROFILE_COMPONENTS := $(shell sh mk/profile.sh components $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)) || printf '__invalid_profile__')
ifneq ($(filter __invalid_profile__,$(PROFILE_COMPONENTS)),)
  $(error invalid PROFILE or WITH selection)
endif
PROFILE_PACKAGES := $(shell sh mk/profile.sh packages $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)))
PROFILE_TOOLS := $(shell sh mk/profile.sh tools $(call profile_shell_quote,$(PROFILE)) $(call profile_shell_quote,$(WITH)))
KNOWN_PROFILE_PACKAGES := $(shell sh mk/profile.sh all-packages)

.PHONY: profile profile-set

# Saving a new profile clears old add-ons unless WITH was supplied explicitly.
PROFILE_SET_WITH = $(if $(filter command line,$(origin WITH)),$(WITH),)

profile: ## [offline] show the selected setup components and tools
	@echo "profile: $(PROFILE)"
	@echo "add-ons: $(if $(strip $(WITH)),$(WITH),none)"
	@echo "components: $(PROFILE_COMPONENTS)"
	@echo "Stow packages: $(PROFILE_PACKAGES)"
	@echo "mise tools: $(PROFILE_TOOLS)"
	@echo "tool steps: $(if $(filter mise,$(PROFILE_PACKAGES)),mise-tools) $(if $(filter zsh,$(PROFILE_PACKAGES)),sheldon) $(if $(filter herdr,$(PROFILE_PACKAGES)),herdr)"
	@echo "plugin steps: $(if $(filter zsh,$(PROFILE_PACKAGES)),sheldon-plugins) $(if $(filter vim,$(PROFILE_PACKAGES)),vim-plugins) $(if $(filter nvim,$(PROFILE_PACKAGES)),nvim-plugins)"

profile-set: ## [offline] save PROFILE and WITH as this checkout's default
	@set -eu; \
	target="$(CURDIR)/profile.mk"; \
	tmp="$$target.tmp.$$$$"; \
	trap 'rm -f "$$tmp"' EXIT; \
	trap 'rm -f "$$tmp"; exit 1' HUP INT TERM; \
	(umask 077; printf 'PROFILE := %s\nWITH := %s\n' \
		$(call profile_shell_quote,$(PROFILE)) \
		$(call profile_shell_quote,$(PROFILE_SET_WITH)) > "$$tmp"); \
	mv "$$tmp" "$$target"; \
	trap - EXIT HUP INT TERM; \
	echo "saved profile=$(PROFILE) add-ons=$(if $(strip $(PROFILE_SET_WITH)),$(PROFILE_SET_WITH),none) in $$target"; \
	echo "run 'make plan' to preview its setup"
