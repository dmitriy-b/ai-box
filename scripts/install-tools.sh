#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install-tools.sh — Conditionally install AI coding tools.
#
# Environment variables (all optional, with defaults):
#   INSTALL_CODEX        true|false  (default: true)
#   INSTALL_CLAUDE_CODE  true|false  (default: true)
#   INSTALL_OPENCODE     true|false  (default: true)
#
#   CODEX_VERSION        npm version tag or "latest"  (default: latest)
#   CLAUDE_CODE_VERSION  npm version tag or "latest"  (default: latest)
#   OPENCODE_VERSION     npm version tag or "latest"  (default: latest)
# ---------------------------------------------------------------------------
set -euo pipefail

INSTALL_CODEX="${INSTALL_CODEX:-true}"
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-true}"
INSTALL_OPENCODE="${INSTALL_OPENCODE:-true}"

CODEX_VERSION="${CODEX_VERSION:-latest}"
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-latest}"
OPENCODE_VERSION="${OPENCODE_VERSION:-latest}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { echo "==> $*"; }

# npm_install <package> <version>
npm_install() {
    local pkg="$1" ver="$2"
    if [ "$ver" = "latest" ]; then
        npm install -g "$pkg" --no-audit --no-fund
    else
        npm install -g "${pkg}@${ver}" --no-audit --no-fund
    fi
}

# ---------------------------------------------------------------------------
# Codex CLI  (https://github.com/openai/codex)
# ---------------------------------------------------------------------------
if [ "$INSTALL_CODEX" = "true" ]; then
    log "Installing Codex CLI (@openai/codex ${CODEX_VERSION})..."
    npm_install "@openai/codex" "$CODEX_VERSION"
    /usr/local/bin/mise reshim
fi

# ---------------------------------------------------------------------------
# Claude Code  (https://github.com/anthropics/claude-code)
# ---------------------------------------------------------------------------
if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then
    log "Installing Claude Code (@anthropic-ai/claude-code ${CLAUDE_CODE_VERSION})..."
    npm_install "@anthropic-ai/claude-code" "$CLAUDE_CODE_VERSION"
    /usr/local/bin/mise reshim
fi

# ---------------------------------------------------------------------------
# OpenCode  (https://github.com/sst/opencode)
# ---------------------------------------------------------------------------
if [ "$INSTALL_OPENCODE" = "true" ]; then
    log "Installing OpenCode (opencode ${OPENCODE_VERSION})..."
    npm_install "opencode-ai" "$OPENCODE_VERSION"
    /usr/local/bin/mise reshim
fi

log "Reshimming mise to expose installed tools globally..."
/usr/local/bin/mise reshim

log "All requested tools installed successfully."
