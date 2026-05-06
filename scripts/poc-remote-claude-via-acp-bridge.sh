#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ssh_target> <acp_bridge_token> [prompt]"
  echo "Example: $0 ubuntu@10.0.0.12 super-token 'Summarize repository structure'"
  exit 1
fi

SSH_TARGET="$1"
ACP_TOKEN="$2"
PROMPT="${3:-Say hello from remote Claude Code via ACP Bridge}"
PROMPT_ESCAPED="${PROMPT//$'\n'/ }"
PROMPT_ESCAPED="${PROMPT_ESCAPED//\"/\\\"}"

BRIDGE_HOST="${BRIDGE_HOST:-${SSH_TARGET##*@}}"
BRIDGE_PORT="${BRIDGE_PORT:-18010}"
BRIDGE_IMAGE="${BRIDGE_IMAGE:-ai-box:latest}"
BRIDGE_CONTAINER="${BRIDGE_CONTAINER:-ai-box-acp-bridge}"

echo "==> Starting ACP Bridge on remote VM: ${SSH_TARGET}"
ssh "$SSH_TARGET" \
  "ACP_TOKEN='$ACP_TOKEN' BRIDGE_PORT='$BRIDGE_PORT' BRIDGE_IMAGE='$BRIDGE_IMAGE' BRIDGE_CONTAINER='$BRIDGE_CONTAINER' bash -s" <<'EOS'
set -euo pipefail
docker rm -f "$BRIDGE_CONTAINER" >/dev/null 2>&1 || true
docker run -d \
  --name "$BRIDGE_CONTAINER" \
  -p "${BRIDGE_PORT}:18010" \
  -e ACP_BRIDGE_TOKEN="$ACP_TOKEN" \
  -e ANTHROPIC_API_KEY \
  "$BRIDGE_IMAGE" acp-bridge >/dev/null
EOS

echo "==> Waiting for bridge health endpoint on ${BRIDGE_HOST}:${BRIDGE_PORT}"
HEALTH_OK=false
for _ in $(seq 1 20); do
  if curl -fsS --retry 2 --retry-delay 1 "http://${BRIDGE_HOST}:${BRIDGE_PORT}/health" >/dev/null; then
    HEALTH_OK=true
    break
  fi
  sleep 2
done
if [[ "$HEALTH_OK" != "true" ]]; then
  echo "Bridge did not become healthy in time" >&2
  exit 1
fi

echo "==> Submitting Claude job"
curl -fsS --retry 3 --retry-delay 2 --retry-connrefused \
  -X POST "http://${BRIDGE_HOST}:${BRIDGE_PORT}/jobs" \
  -H "Authorization: Bearer ${ACP_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"agent_name\": \"claude\",
    \"prompt\": \"${PROMPT_ESCAPED}\",
    \"target\": \"user:poc\",
    \"channel\": \"terminal\"
  }"

echo
echo "==> POC request sent successfully"
