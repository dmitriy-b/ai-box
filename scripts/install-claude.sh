#!/usr/bin/env bash
set -euo pipefail

VERSION="${CLAUDE_VERSION:-latest}"

echo "==> Installing Claude Code (@anthropic-ai/claude-code ${VERSION})..."
npm install -g "@anthropic-ai/claude-code@${VERSION}" --no-audit --no-fund
/usr/local/bin/mise reshim

# `claude install` downloads a native binary to ~/.local/bin/claude.
# Run it, then symlink the result into /usr/local/bin so it's available
# for all users (the build runs as root, so ~/.local = /root/.local).
claude install || echo "WARNING: 'claude install' failed (non-critical), continuing..."
/usr/local/bin/mise reshim

# Ensure the claude binary is globally accessible regardless of where
# `claude install` placed it. The native binary lives under root's home
# which other users can't traverse, so copy it to /usr/local/bin.
CLAUDE_REAL="$(readlink -f "$HOME/.local/bin/claude" 2>/dev/null || true)"
if [ -n "$CLAUDE_REAL" ] && [ -f "$CLAUDE_REAL" ] && [ ! -f /usr/local/bin/claude ]; then
    cp "$CLAUDE_REAL" /usr/local/bin/claude
    chmod a+rx /usr/local/bin/claude
    echo "Copied claude to /usr/local/bin/claude"
fi