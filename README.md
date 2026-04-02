# ai-box

A lightweight, Docker-based development environment that bundles multiple AI coding tools into a single reproducible image.

## Why?

- Run tools inside fully isolated docker environmnt (only mount volumes with working repository) 
- Speedup agent work (e.g. using `--dangerously-skip-permissions`)
- Quick switch beetween tools subscriptions by using custom profiles and bash aliases
- Test tools without installing it on the host
- Easy to share tools, configs with just export docker image 

## What it includes

| Tool | Package | Command |
|------|---------|---------|
| [Codex CLI](https://github.com/openai/codex) | `@openai/codex` | `codex` |
| [Claude Code](https://github.com/anthropics/claude-code) | `@anthropic-ai/claude-code` | `claude` |
| [OhMyOpenAgent](https://ohmyopenagent.com/) | `oh-my-opencode` | `bunx oh-my-opencode` |
| [OhMyOpenClaude](https://github.com/Yeachan-Heo/oh-my-claudecode) | `oh-my-claude-sisyphus` | `oh-my-claude` |
| [OpenCode](https://github.com/sst/opencode) | `opencode-ai` | `opencode` |

Docker CLI is also installed so you can run containers from within the ai-box environment.

Node.js and other runtimes are managed by **[mise](https://mise.jdx.dev/)**, a fast polyglot version manager.

---

## Quick start

```bash
# 1. Build the image (all tools enabled, Node.js 22)
make build

# 2. Run an interactive shell with the current directory mounted
make run
```

Inside the container, all tools are on `$PATH` and your local files are available under `/workspace/$(basename $PWD)`.

You can also run tools directly and pass arguments using `--`:
```bash
make run -- claude --some-flag
make run -- codex --version
```

---

## Global Usage (Use from anywhere)

You don't need to be inside the `ai-box` directory to use your tools. Run `make aliases` to generate shell functions and aliases that you can add to your `~/.zshrc` or `~/.bashrc`:

```bash
make aliases
```

This will output a snippet you can copy-paste, including:
1. A global `ai-box` command that intelligently mounts your current host directory into the container.
2. Fast aliases like `claude-box`, `codex-box`, etc.
3. Automatically generated aliases for any specific **accounts/profiles** you've created (e.g. `claude-personal`, `claude-work`).

To apply them immediately:
```bash
make aliases >> ~/.zshrc && source ~/.zshrc
```

---

## Multiple Accounts / Subscriptions

If you use multiple accounts (e.g. one for personal, one for work), `ai-box` can seamlessly switch between them by persisting configurations in separate local directories under `data/`.

Provide the `ACCOUNT` variable when running:

```bash
# Use "work_account" profile
make run ACCOUNT=work_account -- claude

# Use "personal_account" profile
make run ACCOUNT=personal_account -- codex
```

This ensures that each account gets its own independent config files (e.g., `data/claude/work_account/`, `data/codex/personal_account/`), which are automatically volume-mounted into the correct XDG/home paths inside the container (`~/.claude`, `~/.codex`, `~/.config/opencode`, etc.).

If you only want to generate config directories for specific tools:

```bash
make setup-data ACCOUNT=work_account opencode,codex
```

**Note:** The `data/` directory is ignored by Git to prevent accidentally committing your authentication tokens.

---

## Building

### Default build (all tools)

```bash
make build
```

### Enable or disable individual tools

```bash
make build INSTALL_OHO=false
make build INSTALL_OHC=false
make build INSTALL_OPENCODE=false
make build INSTALL_CODEX=false
```

### Pin specific tool versions

```bash
make build OHO_VERSION=1.2.3
make build OHC_VERSION=1.2.3
make build CODEX_VERSION=0.1.2 CLAUDE_VERSION=1.2.3
```

### Change Node.js version

```bash
make build NODE_VERSION=20
```

### Build directly with `docker build`

```bash
docker build \
  --build-arg INSTALL_CODEX=true \
  --build-arg INSTALL_CLAUDE=true \
  --build-arg INSTALL_OHO=true \
  --build-arg INSTALL_OHC=true \
  --build-arg INSTALL_OPENCODE=true \
  --build-arg NODE_VERSION=22 \
  --build-arg USER_UID=$(id -u) \
  --build-arg USER_GID=$(id -g) \
  -t ai-box .
```

---

## Running interactively

```bash
# Interactive shell (current directory mounted at /workspace/$(basename $PWD))
make run

# Equivalent docker command
docker run -it --rm \
  -v "$(pwd):/workspace/$(basename $PWD)" \
  -w "/workspace/$(basename $PWD)" \
  -e OPENAI_API_KEY \
  -e ANTHROPIC_API_KEY \
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
| `INSTALL_CLAUDE` | `true` | Install Claude Code |
| `INSTALL_OHO` | `true` | Install OhMyOpenAgent |
| `INSTALL_OHC` | `true` | Install OhMyOpenClaude |
| `INSTALL_OPENCODE` | `true` | Install OpenCode |
| `CODEX_VERSION` | `latest` | Codex CLI npm version |
| `CLAUDE_VERSION` | `latest` | Claude Code npm version |
| `OHO_VERSION` | `latest` | OhMyOpenAgent npm version |
| `OHC_VERSION` | `latest` | OhMyOpenClaude npm version |
| `OPENCODE_VERSION` | `latest` | OpenCode npm version |
| `USER_UID` | `1000` | UID of the in-container `dev` user |
| `USER_GID` | `1000` | GID of the in-container `dev` user |

---

## Environment variables at runtime

Pass API keys and tokens via `-e` or by exporting them in your shell before running `make run`.

Runtime argument:

- `SHARE_DOCKER=true/false` (default: `true`): when enabled, the host's `/var/run/docker.sock` is mounted into the container.

| Variable | Used by |
|----------|---------|
| `OPENAI_API_KEY` | Codex CLI |
| `ANTHROPIC_API_KEY` | Claude Code |

---

## Makefile targets

| Target | Description |
|--------|-------------|
| `make build` | Build the Docker image |
| `make run` | Start an interactive shell with `$(pwd)` mounted |
| `make shell` | Alias for `make run` |
| `make aliases` | Generate shell aliases/functions to use tools from any directory |
| `make setup-data` | Pre-create `data/` directories to prevent root-ownership by Docker |
| `make help` | Print all targets and current variable values |

---

## Adding more tools

The project uses a data-driven approach to tool installation. To add a new tool (e.g. `foo`):

1. Create a script at `scripts/install-foo.sh` to install the tool.
2. Add `ARG INSTALL_FOO=true` and `ARG FOO_VERSION=latest` to the `Dockerfile`.
3. Add matching config in the `Makefile` (`INSTALL_FOO ?= true`, `FOO_VERSION ?= latest`).
4. Update `setup-data` in the `Makefile` if the tool requires isolated configurations or state directories.
5. Document the new variables in this README.
