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
INSTALL_CLAUDE_CODE ?= true
INSTALL_OPENCODE    ?= true
INSTALL_COPILOT     ?= true

# ── Version pins (npm tag or "latest") ───────────────────────────────────────
CODEX_VERSION       ?= latest
CLAUDE_CODE_VERSION ?= latest
OPENCODE_VERSION    ?= latest

# ── Runtime ───────────────────────────────────────────────────────────────────
NODE_VERSION        ?= 22

# ── Match host user so volume-mounted files have correct ownership ────────────
HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

# ── Docker run flags shared between run/shell targets ────────────────────────
DOCKER_RUN_FLAGS := \
  --rm \
  --interactive \
  --tty \
  --volume "$(CURDIR):/workspace" \
  --workdir /workspace

# Pass common API key env vars through from the host (no-op if unset).
DOCKER_RUN_FLAGS += \
  --env OPENAI_API_KEY \
  --env ANTHROPIC_API_KEY \
  --env GITHUB_TOKEN

# =============================================================================
.PHONY: build run shell help

## build: Build the ai-box Docker image.
build:
	docker build \
	  --build-arg INSTALL_CODEX="$(INSTALL_CODEX)" \
	  --build-arg INSTALL_CLAUDE_CODE="$(INSTALL_CLAUDE_CODE)" \
	  --build-arg INSTALL_OPENCODE="$(INSTALL_OPENCODE)" \
	  --build-arg INSTALL_COPILOT="$(INSTALL_COPILOT)" \
	  --build-arg CODEX_VERSION="$(CODEX_VERSION)" \
	  --build-arg CLAUDE_CODE_VERSION="$(CLAUDE_CODE_VERSION)" \
	  --build-arg OPENCODE_VERSION="$(OPENCODE_VERSION)" \
	  --build-arg NODE_VERSION="$(NODE_VERSION)" \
	  --build-arg USER_UID="$(HOST_UID)" \
	  --build-arg USER_GID="$(HOST_GID)" \
	  --tag "$(IMAGE_NAME):$(IMAGE_TAG)" \
	  .

## run: Start an interactive shell with the current directory mounted.
run:
	docker run $(DOCKER_RUN_FLAGS) "$(IMAGE_NAME):$(IMAGE_TAG)"

## shell: Alias for run.
shell: run

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
	@echo "    INSTALL_CODEX       $(INSTALL_CODEX)"
	@echo "    INSTALL_CLAUDE_CODE $(INSTALL_CLAUDE_CODE)"
	@echo "    INSTALL_OPENCODE    $(INSTALL_OPENCODE)"
	@echo "    INSTALL_COPILOT     $(INSTALL_COPILOT)"
	@echo "    CODEX_VERSION       $(CODEX_VERSION)"
	@echo "    CLAUDE_CODE_VERSION $(CLAUDE_CODE_VERSION)"
	@echo "    OPENCODE_VERSION    $(OPENCODE_VERSION)"
	@echo "    HOST_UID            $(HOST_UID)"
	@echo "    HOST_GID            $(HOST_GID)"
	@echo ""
