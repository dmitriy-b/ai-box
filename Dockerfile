# =============================================================================
# ai-box — Lightweight Docker dev environment bundling multiple AI coding tools
# =============================================================================
#
# Build arguments (all optional):
#
#   Tool toggles (true / false):
#     INSTALL_CODEX        — install Codex CLI          (default: true)
#     INSTALL_CLAUDE_CODE  — install Claude Code        (default: true)
#     INSTALL_OPENCODE     — install OpenCode           (default: true)
#     INSTALL_COPILOT      — install GitHub Copilot CLI (default: true)
#
#   Version pins (npm tag or "latest"):
#     CODEX_VERSION        (default: latest)
#     CLAUDE_CODE_VERSION  (default: latest)
#     OPENCODE_VERSION     (default: latest)
#     (gh-copilot extension is always installed at latest)
#
#   Runtime:
#     NODE_VERSION         — Node.js version for mise   (default: 22)
#
#   User / permissions:
#     USER_UID             — UID for the in-container dev user (default: 1000)
#     USER_GID             — GID for the in-container dev user (default: 1000)
# =============================================================================

FROM debian:bookworm-slim

# ── Build arguments ──────────────────────────────────────────────────────────

ARG NODE_VERSION=22

ARG INSTALL_CODEX=true
ARG INSTALL_CLAUDE_CODE=true
ARG INSTALL_OPENCODE=true
ARG INSTALL_COPILOT=true

ARG CODEX_VERSION=latest
ARG CLAUDE_CODE_VERSION=latest
ARG OPENCODE_VERSION=latest

ARG USER_UID=1000
ARG USER_GID=1000

# ── Persistent environment ───────────────────────────────────────────────────

# mise: store data + config in system-wide paths so every user can share them.
ENV MISE_DATA_DIR=/usr/local/share/mise \
    MISE_CONFIG_DIR=/etc/mise \
    MISE_CACHE_DIR=/tmp/mise-cache \
    # mise shims must come before any other node/npm paths.
    PATH="/usr/local/share/mise/shims:$PATH" \
    # gh CLI: store extensions in a world-readable system path.
    GH_DATA_DIR=/usr/local/share/gh \
    # Suppress npm update-notifier noise inside the container.
    NO_UPDATE_NOTIFIER=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false

# ── System dependencies ───────────────────────────────────────────────────────

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# ── Install mise (universal version manager) ─────────────────────────────────
# https://mise.jdx.dev/

RUN curl -fsSL https://mise.run \
    | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# ── Install Node.js via mise ──────────────────────────────────────────────────

# Write a global mise config declaring the Node.js version, then install.
# `mise reshim` creates shim scripts in $MISE_DATA_DIR/shims so that tools
# installed via npm (codex, claude, etc.) are discoverable without needing
# `eval "$(mise activate bash)"`.
RUN mkdir -p /etc/mise \
    && printf '[tools]\nnode = "%s"\n' "${NODE_VERSION}" > /etc/mise/config.toml \
    && mise install \
    && mise reshim \
    # Ensure the entire data dir is readable/executable by all users.
    && chmod -R a+rX /usr/local/share/mise

# ── Install AI tools ──────────────────────────────────────────────────────────

COPY scripts/install-tools.sh /usr/local/bin/install-tools.sh
RUN chmod +x /usr/local/bin/install-tools.sh \
    && INSTALL_CODEX="${INSTALL_CODEX}" \
       INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE}" \
       INSTALL_OPENCODE="${INSTALL_OPENCODE}" \
       INSTALL_COPILOT="${INSTALL_COPILOT}" \
       CODEX_VERSION="${CODEX_VERSION}" \
       CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION}" \
       OPENCODE_VERSION="${OPENCODE_VERSION}" \
       GH_DATA_DIR="${GH_DATA_DIR:-/usr/local/share/gh}" \
       /usr/local/bin/install-tools.sh \
    # Make npm globals and gh data readable by all users.
    && chmod -R a+rX /usr/local/share/mise 2>/dev/null || true \
    && chmod -R a+rX /usr/local/share/gh   2>/dev/null || true

# ── Create a non-root developer user ─────────────────────────────────────────
# UID / GID are configurable at build time so that files written to a mounted
# volume (-v $(pwd):/workspace) are owned by the same user as on the host.

RUN groupadd --gid "${USER_GID}" dev 2>/dev/null || true \
    && useradd \
        --uid "${USER_UID}" \
        --gid "${USER_GID}" \
        --create-home \
        --shell /bin/bash \
        dev 2>/dev/null || true \
    # Allow passwordless sudo for convenience in development.
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

# ── Workspace ─────────────────────────────────────────────────────────────────

RUN mkdir -p /workspace && chown "${USER_UID}:${USER_GID}" /workspace

WORKDIR /workspace

USER dev

# Drop into an interactive login shell by default.
CMD ["/bin/bash", "-l"]
