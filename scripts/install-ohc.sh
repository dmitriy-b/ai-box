#!/usr/bin/env bash
set -euo pipefail

VERSION="${OHC_VERSION:-latest}"
PACKAGE="oh-my-claude-sisyphus@${VERSION}"

echo "==> Installing OhMyOpenClaude ($PACKAGE) globally via npm..."

npm i -g "$PACKAGE" || true
/usr/local/bin/mise reshim
