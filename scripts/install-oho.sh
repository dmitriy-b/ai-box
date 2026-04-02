#!/usr/bin/env bash
set -euo pipefail

VERSION="${OHO_VERSION:-latest}"
PACKAGE="oh-my-opencode@${VERSION}"

echo "==> Installing OhMyOpenAgent ($PACKAGE) globally via bun..."

mise exec bun -- bun install -g "$PACKAGE" || true
/usr/local/bin/mise reshim
