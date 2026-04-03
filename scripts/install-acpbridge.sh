#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing ACP Bridge (sample-acp-bridge)..."

VERSION="${ACPBRIDGE_VERSION:-latest}"
if [ "$VERSION" = "latest" ]; then
    VERSION="main"
fi

INSTALL_DIR="/usr/local/share/sample-acp-bridge"
echo "Cloning sample-acp-bridge @ $VERSION into $INSTALL_DIR..."
git clone --branch "$VERSION" --single-branch https://github.com/aws-samples/sample-acp-bridge.git "$INSTALL_DIR"

cd "$INSTALL_DIR"
# Use mise's uv to sync dependencies
eval "$(/usr/local/bin/mise activate bash)"
export UV_PYTHON_INSTALL_DIR=/usr/local/share/uv-python
uv sync

# Create a global wrapper
cat << 'WRAPPER' > /usr/local/bin/acp-bridge
#!/usr/bin/env bash
# Preserve user's CWD, but add sample-acp-bridge to PYTHONPATH just in case
export PYTHONPATH="${PYTHONPATH:-}:/usr/local/share/sample-acp-bridge"

ARGS=("$@")
HAS_CONFIG=0
for arg in "${ARGS[@]}"; do
    if [[ "$arg" == "--config" || "$arg" == *"--config="* ]]; then
        HAS_CONFIG=1
        break
    fi
done

if [ $HAS_CONFIG -eq 0 ] && [ -f /home/dev/.acp-bridge/config.yml ]; then
    ARGS=("--config" "/home/dev/.acp-bridge/config.yml" "${ARGS[@]}")
fi

# Ensure all mise shims (like opencode) are available in PATH
eval "$(/usr/local/bin/mise activate bash)"

exec /usr/local/share/sample-acp-bridge/.venv/bin/python /usr/local/share/sample-acp-bridge/main.py "${ARGS[@]}"
WRAPPER

chmod +x /usr/local/bin/acp-bridge
chmod -R a+rX /usr/local/share/sample-acp-bridge
chmod -R a+rX /usr/local/share/uv-python 2>/dev/null || true
