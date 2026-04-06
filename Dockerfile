# =============================================================================
# ai-box — Lightweight Docker dev environment bundling multiple AI coding tools
# =============================================================================
#
# Build arguments (all optional):
#
#   Tool toggles (true / false):
#     INSTALL_CODEX        — install Codex CLI          (default: true)
#     INSTALL_CLAUDE       — install Claude Code        (default: true)
#     INSTALL_OPENCODE     — install OpenCode           (default: true)
#
#   Version pins (npm tag or "latest"):
#     CODEX_VERSION        (default: latest)
#     CLAUDE_VERSION       (default: latest)
#     OPENCODE_VERSION     (default: latest)
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
ARG INSTALL_CLAUDE=true
ARG INSTALL_OPENCODE=true
ARG INSTALL_OHO=true
ARG INSTALL_OHC=true
ARG INSTALL_ACPBRIDGE=true

ARG CODEX_VERSION=latest
ARG CLAUDE_VERSION=latest
ARG OPENCODE_VERSION=latest
ARG OHO_VERSION=latest
ARG OHC_VERSION=latest
ARG ACPBRIDGE_VERSION=latest

ARG USER_UID=1000
ARG USER_GID=1000

# ── Persistent environment ───────────────────────────────────────────────────

ENV INSTALL_OHO=${INSTALL_OHO} \
    OHO_VERSION=${OHO_VERSION} \
    INSTALL_OHC=${INSTALL_OHC} \
    OHC_VERSION=${OHC_VERSION} \
    INSTALL_ACPBRIDGE=${INSTALL_ACPBRIDGE} \
    ACPBRIDGE_VERSION=${ACPBRIDGE_VERSION}

# mise: store data + config in system-wide paths so every user can share them.
ENV MISE_DATA_DIR=/usr/local/share/mise \
    MISE_CONFIG_DIR=/etc/mise \
    MISE_CACHE_DIR=/tmp/mise-cache \
    # mise shims must come before any other node/npm paths.
    PATH="/usr/local/share/mise/shims:$PATH" \
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

# ── Install Docker CLI (static binary) ────────────────────────────────────────

ARG DOCKER_CLI_VERSION="27.5.1"
RUN curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/aarch64/')/docker-${DOCKER_CLI_VERSION}.tgz" -o docker.tgz \
    && tar -xzf docker.tgz docker/docker \
    && mv docker/docker /usr/local/bin/ \
    && rm -rf docker docker.tgz \
    && groupadd -r docker 2>/dev/null || true \
    && usermod -aG docker root

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
    && printf '[tools]\nnode = "%s"\nbun = "latest"\npython = "3.12"\nuv = "latest"\n' "${NODE_VERSION}" > /etc/mise/config.toml \
    && mise install \
    && mise reshim \
    # Ensure the entire data dir is readable/executable by all users.
    && chmod -R a+rX /usr/local/share/mise

RUN echo 'export PATH="/usr/local/share/mise/shims:$PATH"' > /etc/profile.d/mise.sh && \
    chmod +x /etc/profile.d/mise.sh

# ── Install AI tools ──────────────────────────────────────────────────────────

COPY scripts/install-*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/install-*.sh \
    && for script in /usr/local/bin/install-*.sh; do \
         toolname=$(basename "$script" | sed 's/install-//' | sed 's/\.sh//' | tr 'a-z-' 'A-Z_'); \
         varname="INSTALL_${toolname}"; \
         version_varname="${toolname}_VERSION"; \
         export "${version_varname}=$(eval echo \$${version_varname})"; \
         if [ "$(eval echo \$${varname})" = "true" ]; then \
             echo "Executing $script for $toolname..."; \
             "$script"; \
         fi; \
       done \
    && chmod -R a+rX /usr/local/share/mise 2>/dev/null || true

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
    && usermod -aG docker dev 2>/dev/null || true \
    # Allow passwordless sudo for convenience in development.
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

RUN mkdir -p /home/dev/.claude && \
    ln -s /home/dev/.claude/claude.json /home/dev/.claude.json && \
    chown -R "${USER_UID}:${USER_GID}" /home/dev/.claude /home/dev/.claude.json

RUN printf '#!/bin/bash\nset -e\n\nsudo chown "$(id -u)":"$(id -g)" /var/run/docker.sock 2>/dev/null || true\n\nif [ "${INSTALL_OHO:-false}" = "true" ] && [ ! -f ~/.config/opencode/oh-my-opencode.json ]; then\n    echo "Initializing OhMyOpenAgent for this workspace profile..."\n    mkdir -p ~/.config/opencode\n    bunx --bun oh-my-opencode@${OHO_VERSION:-latest} install --no-tui \\\n        --claude=no --openai=no --gemini=no --copilot=no \\\n        --opencode-zen=no --zai-coding-plan=no || true\nfi\n\nif [ "${INSTALL_OHC:-false}" = "true" ] && command -v claude &>/dev/null; then\n    OHC_PKG_DIR="$(npm root -g)/oh-my-claude-sisyphus"\n    if [ -d "$OHC_PKG_DIR/.claude-plugin" ] && ! claude plugin list 2>/dev/null | grep -q oh-my-claudecode; then\n        echo "Registering oh-my-claudecode as Claude Code plugin..."\n        claude plugin marketplace add "$OHC_PKG_DIR" 2>/dev/null || true\n        claude plugin install oh-my-claudecode 2>/dev/null || true\n    fi\nfi\n\nexec "$@"\n' > /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Workspace ─────────────────────────────────────────────────────────────────

RUN mkdir -p /workspace && chown "${USER_UID}:${USER_GID}" /workspace

WORKDIR /workspace

USER dev

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Drop into an interactive login shell by default.
CMD ["/bin/bash", "-l"]
