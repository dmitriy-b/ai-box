# ai-box

A lightweight, Docker-based development environment that bundles multiple AI coding tools into a single reproducible image.

## What it includes

| Tool | Package | Command |
|------|---------|---------|
| [Codex CLI](https://github.com/openai/codex) | `@openai/codex` | `codex` |
| [Claude Code](https://github.com/anthropics/claude-code) | `@anthropic-ai/claude-code` | `claude` |
| [OpenCode](https://github.com/sst/opencode) | `opencode-ai` | `opencode` |
| [GitHub Copilot CLI](https://githubnext.com/projects/github-copilot-cli) | `gh` + `gh-copilot` extension | `gh copilot` |

Node.js and other runtimes are managed by **[mise](https://mise.jdx.dev/)**, a fast polyglot version manager.

---

## Quick start

```bash
# 1. Build the image (all tools enabled, Node.js 22)
make build

# 2. Run an interactive shell with the current directory mounted
make run
```

Inside the container, all tools are on `$PATH` and your local files are available under `/workspace`.

---

## Building

### Default build (all tools)

```bash
make build
```

### Enable or disable individual tools

```bash
make build INSTALL_OPENCODE=false
make build INSTALL_CODEX=false INSTALL_COPILOT=false
```

### Pin specific tool versions

```bash
make build CODEX_VERSION=0.1.2 CLAUDE_CODE_VERSION=1.2.3
```

### Change Node.js version

```bash
make build NODE_VERSION=20
```

### Build directly with `docker build`

```bash
docker build \
  --build-arg INSTALL_CODEX=true \
  --build-arg INSTALL_CLAUDE_CODE=true \
  --build-arg INSTALL_OPENCODE=true \
  --build-arg INSTALL_COPILOT=true \
  --build-arg NODE_VERSION=22 \
  --build-arg USER_UID=$(id -u) \
  --build-arg USER_GID=$(id -g) \
  -t ai-box .
```

---

## Running interactively

```bash
# Interactive shell (current directory mounted at /workspace)
make run

# Equivalent docker command
docker run -it --rm \
  -v "$(pwd):/workspace" \
  -e OPENAI_API_KEY \
  -e ANTHROPIC_API_KEY \
  -e GITHUB_TOKEN \
  ai-box
```

---

## Mounting the current directory safely

The image creates an in-container user (`dev`) whose UID/GID defaults to `1000:1000`.  
Passing your host UID/GID at **build time** ensures that files written inside the container are owned by your host user — no `chown` or `sudo` headaches.

```bash
make build   # already uses HOST_UID=$(id -u) HOST_GID=$(id -g) automatically
```

If you share one image across multiple machines (with different UIDs), rebuild the image once per machine or use `docker run --user $(id -u):$(id -g)` at runtime:

```bash
docker run -it --rm \
  --user "$(id -u):$(id -g)" \
  -v "$(pwd):/workspace" \
  ai-box
```

---

## Build arguments reference

| Build arg | Default | Description |
|-----------|---------|-------------|
| `NODE_VERSION` | `22` | Node.js version managed by mise |
| `INSTALL_CODEX` | `true` | Install Codex CLI |
| `INSTALL_CLAUDE_CODE` | `true` | Install Claude Code |
| `INSTALL_OPENCODE` | `true` | Install OpenCode |
| `INSTALL_COPILOT` | `true` | Install GitHub Copilot CLI (`gh` + extension) |
| `CODEX_VERSION` | `latest` | Codex CLI npm version |
| `CLAUDE_CODE_VERSION` | `latest` | Claude Code npm version |
| `OPENCODE_VERSION` | `latest` | OpenCode npm version |
| `USER_UID` | `1000` | UID of the in-container `dev` user |
| `USER_GID` | `1000` | GID of the in-container `dev` user |

---

## Environment variables at runtime

Pass API keys and tokens via `-e` or by exporting them in your shell before running `make run`.

| Variable | Used by |
|----------|---------|
| `OPENAI_API_KEY` | Codex CLI |
| `ANTHROPIC_API_KEY` | Claude Code |
| `GITHUB_TOKEN` | gh / Copilot extension |

> **GitHub Copilot** requires an active Copilot subscription. Authenticate with `gh auth login` on first use, or pass `GITHUB_TOKEN` at runtime.

---

## Makefile targets

| Target | Description |
|--------|-------------|
| `make build` | Build the Docker image |
| `make run` | Start an interactive shell with `$(pwd)` mounted |
| `make shell` | Alias for `make run` |
| `make help` | Print all targets and current variable values |

---

## Adding more tools

1. Add a new `ARG INSTALL_MYTOOL=true` / `ARG MYTOOL_VERSION=latest` section in `Dockerfile`.
2. Add the corresponding install block in `scripts/install-tools.sh`.
3. Document the new variables in this README.
4. Expose the new variables in `Makefile`.
