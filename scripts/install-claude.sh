#!/usr/bin/env bash
set -euo pipefail

VERSION="${CLAUDE_VERSION:-latest}"

echo "==> Installing Claude Code (@anthropic-ai/claude-code ${VERSION})..."
npm install -g "@anthropic-ai/claude-code@${VERSION}" --no-audit --no-fund
/usr/local/bin/mise reshim
claude install
/usr/local/bin/mise reshim