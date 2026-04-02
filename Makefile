# =============================================================================
# ai-box Makefile
# =============================================================================
#
# Usage examples:
#   make build                        # build with all tools enabled
#   make build INSTALL_OPENCODE=false # skip OpenCode
#   make run                          # interactive shell + current dir mounted
#   make shell                        # same as run
#   make help                         # show this help
# =============================================================================

# ── Image ─────────────────────────────────────────────────────────────────────
IMAGE_NAME  ?= ai-box
IMAGE_TAG   ?= latest

# ── Tool toggles ──────────────────────────────────────────────────────────────
INSTALL_CODEX       ?= true
INSTALL_CLAUDE      ?= true
INSTALL_OPENCODE    ?= true

# ── Version pins (npm tag or "latest") ───────────────────────────────────────
CODEX_VERSION       ?= latest
CLAUDE_VERSION      ?= latest
OPENCODE_VERSION    ?= latest

# ── Runtime ───────────────────────────────────────────────────────────────────
NODE_VERSION        ?= 22

# ── Match host user so volume-mounted files have correct ownership ────────────
HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

# ── Dynamic Workspace Mounting ────────────────────────────────────────────────
# Directory from which the user is running the command (defaults to ai-box root)
HOST_DIR ?= $(CURDIR)
# The base name of the host directory to use inside the container
DIR_NAME ?= $(notdir $(HOST_DIR))
# The path inside the container where the host directory will be mounted
WORKDIR  ?= /workspace/$(DIR_NAME)

# ── Accounts / Configurations ────────────────────────────────────────────────
ACCOUNT             ?= default
DATA_DIR            := $(CURDIR)/data
CLAUDE_DATA_DIR     := $(DATA_DIR)/claude/$(ACCOUNT)
CODEX_DATA_DIR      := $(DATA_DIR)/codex/$(ACCOUNT)
OPENCODE_DATA_DIR   := $(DATA_DIR)/opencode/$(ACCOUNT)

# ── Docker run flags shared between run/shell targets ────────────────────────
DOCKER_RUN_FLAGS := \
  --rm \
  --interactive \
  --volume "$(HOST_DIR):$(WORKDIR)" \
  --workdir "$(WORKDIR)"

# Mount data directories to persist tool configurations
DOCKER_RUN_FLAGS += \
  --volume "$(CLAUDE_DATA_DIR)/.claude:/home/dev/.claude" \
  --volume "$(CODEX_DATA_DIR)/.codex:/home/dev/.codex" \
  --volume "$(OPENCODE_DATA_DIR)/.config/opencode:/home/dev/.config/opencode" \
  --volume "$(OPENCODE_DATA_DIR)/.local/share/opencode:/home/dev/.local/share/opencode" \
  --volume "$(OPENCODE_DATA_DIR)/.local/state/opencode:/home/dev/.local/state/opencode" \
  --volume "$(OPENCODE_DATA_DIR)/.cache/opencode:/home/dev/.cache/opencode"

# Allocate a TTY only if the command is run in a terminal
ifeq ($(shell test -t 0 && echo true),true)
  DOCKER_RUN_FLAGS += --tty
endif

# Pass common API key env vars through from the host (no-op if unset).
DOCKER_RUN_FLAGS += \
  --env OPENAI_API_KEY \
  --env ANTHROPIC_API_KEY \
  --env GITHUB_TOKEN

# =============================================================================
.PHONY: build run shell help setup-data aliases

# Ensure local data directories and files exist before running so Docker doesn't
# create them as root-owned directories.
# Supports specific tools: make setup-data opencode,codex
ifeq (setup-data,$(firstword $(MAKECMDGOALS)))
  SETUP_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(SETUP_ARGS):;@:)
endif

setup-data:
	@if [ -z "$(SETUP_ARGS)" ]; then \
		mkdir -p "$(CLAUDE_DATA_DIR)/.claude"; \
		mkdir -p "$(CODEX_DATA_DIR)/.codex"; \
		mkdir -p "$(OPENCODE_DATA_DIR)/.config/opencode"; \
		mkdir -p "$(OPENCODE_DATA_DIR)/.local/share/opencode"; \
		mkdir -p "$(OPENCODE_DATA_DIR)/.local/state/opencode"; \
		mkdir -p "$(OPENCODE_DATA_DIR)/.cache/opencode"; \
	else \
		IFS=',' read -ra TOOLS <<< "$(SETUP_ARGS)"; \
		for tool in "$${TOOLS[@]}"; do \
			if [ "$$tool" = "claude" ]; then mkdir -p "$(CLAUDE_DATA_DIR)/.claude"; fi; \
			if [ "$$tool" = "codex" ]; then mkdir -p "$(CODEX_DATA_DIR)/.codex"; fi; \
			if [ "$$tool" = "opencode" ]; then \
				mkdir -p "$(OPENCODE_DATA_DIR)/.config/opencode"; \
				mkdir -p "$(OPENCODE_DATA_DIR)/.local/share/opencode"; \
				mkdir -p "$(OPENCODE_DATA_DIR)/.local/state/opencode"; \
				mkdir -p "$(OPENCODE_DATA_DIR)/.cache/opencode"; \
			fi; \
		done; \
	fi

# If the first argument is "run" or "shell", allow passing additional arguments.
# For example: make run -- claude --some-flag
ifeq (run,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif
ifeq (shell,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

## build: Build the ai-box Docker image.
build:
	docker build \
	  --build-arg INSTALL_CODEX="$(INSTALL_CODEX)" \
	  --build-arg INSTALL_CLAUDE="$(INSTALL_CLAUDE)" \
	  --build-arg INSTALL_OPENCODE="$(INSTALL_OPENCODE)" \
	  --build-arg CODEX_VERSION="$(CODEX_VERSION)" \
	  --build-arg CLAUDE_VERSION="$(CLAUDE_VERSION)" \
	  --build-arg OPENCODE_VERSION="$(OPENCODE_VERSION)" \
	  --build-arg NODE_VERSION="$(NODE_VERSION)" \
	  --build-arg USER_UID="$(HOST_UID)" \
	  --build-arg USER_GID="$(HOST_GID)" \
	  --tag "$(IMAGE_NAME):$(IMAGE_TAG)" \
	  .

## run: Start an interactive shell with the current directory mounted.
run: setup-data
	docker run $(DOCKER_RUN_FLAGS) "$(IMAGE_NAME):$(IMAGE_TAG)" $(RUN_ARGS)

## shell: Alias for run.
shell: run

## aliases: Generate shell aliases/functions to use ai-box from any directory.
aliases:
	@echo ""
	@echo "# ============================================================================="
	@echo "# Add the following to your ~/.zshrc or ~/.bashrc to use ai-box globally"
	@echo "# ============================================================================="
	@echo ""
	@echo "# Generic wrapper to run ai-box tools from any directory"
	@echo "ai-box() {"
	@echo "    make -C \"$(abspath $(CURDIR))\" run HOST_DIR=\"\$$PWD\" -- \"\$$@\""
	@echo "}"
	@echo ""
	@echo "# Fast tool aliases (using default account)"
	@echo "alias claude-box='ai-box claude'"
	@echo "alias codex-box='ai-box codex'"
	@echo "alias opencode-box='ai-box opencode'"
	@echo ""
	@echo "# ── Auto-detected account aliases ────────────────────────────────────────────"
	@for tool in claude codex opencode; do \
		if [ -d "$(DATA_DIR)/$$tool" ]; then \
			for acc_dir in "$(DATA_DIR)/$$tool"/*; do \
				if [ -d "$$acc_dir" ]; then \
					account=$$(basename "$$acc_dir"); \
					if [ "$$account" != "default" ] && [ "$$account" != "*" ]; then \
						echo "alias $${tool}-$${account}='make -C \"$(abspath $(CURDIR))\" run HOST_DIR=\"\$$PWD\" ACCOUNT=\"$$account\" -- $$tool'"; \
					fi; \
				fi; \
			done; \
		fi; \
	done
	@echo ""
	@echo "# To apply automatically, run:"
	@echo "# make aliases >> ~/.zshrc && source ~/.zshrc"
	@echo ""

## help: Show this help message.
help:
	@echo ""
	@echo "  ai-box — AI coding tools Docker environment"
	@echo ""
	@echo "  Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /    /'
	@echo ""
	@echo "  Build variables (override with VAR=value):"
	@echo "    IMAGE_NAME          $(IMAGE_NAME)"
	@echo "    IMAGE_TAG           $(IMAGE_TAG)"
	@echo "    NODE_VERSION        $(NODE_VERSION)"
	@echo "    ACCOUNT             $(ACCOUNT)"
	@echo "    INSTALL_CODEX       $(INSTALL_CODEX)"
	@echo "    INSTALL_CLAUDE      $(INSTALL_CLAUDE)"
	@echo "    INSTALL_OPENCODE    $(INSTALL_OPENCODE)"
	@echo "    CODEX_VERSION       $(CODEX_VERSION)"
	@echo "    CLAUDE_VERSION      $(CLAUDE_VERSION)"
	@echo "    OPENCODE_VERSION    $(OPENCODE_VERSION)"
	@echo "    HOST_UID            $(HOST_UID)"
	@echo "    HOST_GID            $(HOST_GID)"
	@echo ""
