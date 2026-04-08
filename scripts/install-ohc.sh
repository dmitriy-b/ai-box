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

# Fix OMC hooks that ship with a hardcoded CI node path
# (e.g. /opt/hostedtoolcache/node/…) instead of plain `node`.
OHC_HOOKS="$(npm root -g)/oh-my-claude-sisyphus/hooks/hooks.json"
if [ -f "$OHC_HOOKS" ] && grep -q '/opt/hostedtoolcache/' "$OHC_HOOKS"; then
  echo "Patching hardcoded node path in OMC hooks..."
  sed -i 's|\\"/opt/hostedtoolcache/[^\\]*node\\" |node |g' "$OHC_HOOKS"
fi
