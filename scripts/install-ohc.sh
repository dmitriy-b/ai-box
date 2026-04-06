#!/usr/bin/env bash
set -euo pipefail

VERSION="${OHC_VERSION:-latest}"
PACKAGE="oh-my-claude-sisyphus@${VERSION}"

echo "==> Installing oh-my-claudecode ($PACKAGE) globally via npm..."

if [ "$(id -u)" -eq 0 ]; then
  npm i -g "$PACKAGE"
else
  sudo env "PATH=$PATH" npm i -g "$PACKAGE"
fi
/usr/local/bin/mise reshim
