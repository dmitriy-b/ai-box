#!/usr/bin/env bash
set -euo pipefail

VERSION="${CODEX_VERSION:-latest}"

echo "==> Installing Codex CLI (@openai/codex ${VERSION})..."
npm install -g "@openai/codex@${VERSION}" --no-audit --no-fund
/usr/local/bin/mise reshim
