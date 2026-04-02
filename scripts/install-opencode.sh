#!/usr/bin/env bash
set -euo pipefail

VERSION="${OPENCODE_VERSION:-latest}"

echo "==> Installing OpenCode (opencode-ai ${VERSION})..."
npm install -g "opencode-ai@${VERSION}" --no-audit --no-fund
/usr/local/bin/mise reshim
