# webapp-lib-toolbox
Development and Testing Utilities

---

## LLM Stack — Ollama + Open WebUI + GitNexus

One `docker compose up -d` starts four services:

| Service | URL | Purpose |
|---|---|---|
| **Ollama** | `http://localhost:11434` | LLM backend — serves and manages local models |
| **Open WebUI** | `http://localhost:3000` | Chat UI connected to Ollama |
| **GitNexus Web** | `http://localhost:8080` | Graph explorer UI (React/WASM static site) |
| **GitNexus Serve** | `http://localhost:4747` | HTTP backend — exposes your indexed repos to the browser UI |

Models are stored in a shared named volume (`ollama-models`) so Ollama downloads each model once and Open WebUI reads from the same store.

The **GitNexus Serve** service runs `gitnexus serve` inside Docker, so the graph explorer at `:8080` can connect to your locally-indexed repos without any manual terminal work. Click **"Connect to local server"** on the GitNexus page after the stack starts.

---

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker + Docker Compose v2)
- The sibling repos checked out at the same workspace level:
  - `webapp-ui-gitnexus/` — contains `gitnexus-web/` and `gitnexus/`
- At least one repo indexed with `gitnexus analyze` (required for the neural net to show data)

---

### Quick Start

```bash
# 1. Clone / ensure you're in this directory
cd webapp-lib-toolbox

# 2. Copy the env file and fill in the absolute paths
cp .env.example .env
# Edit .env — set GITNEXUS_WEB_PATH, GITNEXUS_CLI_PATH,
#             WEBAPP_LIB_TOOLBOX_PATH, GITNEXUS_REGISTRY_PATH, WORKSPACE_PATH

# 3. (First time) Index a repo so gitnexus-serve has something to serve
cd ../your-repo && npx gitnexus analyze && cd -

# 4. Uncomment your repo mounts in docker-compose.yml (gitnexus-serve volumes)

# 5. Start everything (builds gitnexus images on first run — ~2 min)
docker compose up -d

# 6. Pull a model into Ollama (e.g. llama3.2)
docker exec ollama ollama pull llama3.2
```

- Open [http://localhost:3000](http://localhost:3000) → **Open WebUI** — create an admin account on first launch
- Open [http://localhost:8080](http://localhost:8080) → **GitNexus graph explorer** — click "Connect to local server"

---

### Exposing Your Repos to GitNexus

The `gitnexus-serve` container reads your indexed repos from the host's `~/.gitnexus/registry.json`. For the container to open the KuzuDB files, each repo root must be **bind-mounted at its exact original absolute path** (because the index stores absolute file paths).

**Steps:**

1. Run `gitnexus analyze` in any repo you want to explore (only needed once per repo)
2. In `docker-compose.yml`, find the `gitnexus-serve` volumes section and uncomment/add:

```yaml
volumes:
  - type: bind
    source: ${GITNEXUS_REGISTRY_PATH}   # ~/.gitnexus — already there
    target: /root/.gitnexus

  # Add one block per repo:
  - type: bind
    source: ${WORKSPACE_PATH}/your-repo
    target: ${WORKSPACE_PATH}/your-repo
    read_only: true
```

3. Set `WORKSPACE_PATH` in `.env` to your workspace root
4. `docker compose up -d` (or `docker compose restart gitnexus-serve` if already running)

---

### Common Commands

```bash
# Start all services
docker compose up -d

# Start a single service
docker compose up -d ollama

# Rebuild after source changes
docker compose build gitnexus-web && docker compose up -d gitnexus-web
docker compose build gitnexus-serve && docker compose up -d gitnexus-serve

# Reload after indexing a new repo (no rebuild needed)
docker compose restart gitnexus-serve

# Stop all (volumes preserved)
docker compose down

# Stop all and delete volumes (model data will be lost)
docker compose down -v

# Tail logs
docker compose logs -f
docker compose logs -f gitnexus-serve

# Pull latest images (ollama + open-webui)
docker compose pull ollama open-webui
docker compose up -d
```

### Ollama Model Management

```bash
# List downloaded models
docker exec ollama ollama list

# Pull a model
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull codellama
docker exec ollama ollama pull mistral

# Remove a model
docker exec ollama ollama rm llama3.2
```

---

### File Structure

```
webapp-lib-toolbox/
├── docker-compose.yml              # Main orchestration (4 services)
├── .env                            # Local env config (gitignored)
├── .env.example                    # Template — copy to .env
├── docker/
│   ├── gitnexus/
│   │   ├── Dockerfile              # gitnexus-web: Node (Vite) → nginx
│   │   └── nginx.conf              # nginx config with COOP/COEP headers for WASM
│   └── gitnexus-serve/
│       ├── Dockerfile              # gitnexus-serve: builds gitnexus CLI → serve
│       └── entrypoint.sh           # (reference) registry setup helper
├── open-webui-setup.md             # Manual / one-off Docker run notes
└── README.md
```

### Sibling Repos (not nested — stay at workspace level)

```
workspace/
├── webapp-lib-toolbox/             ← you are here (orchestration)
├── webapp-ui-gitnexus/
│   ├── gitnexus/                   ← build context for gitnexus-serve
│   └── gitnexus-web/               ← build context for gitnexus-web
├── your-repo/                      ← example: indexed repo
└── your-other-repo/                ← example: indexed repo
```

The other projects do **not** need to be nested inside `webapp-lib-toolbox`. They stay as sibling directories at the workspace level. Docker Compose references them via absolute paths in `.env`.

---

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    llm-network (bridge)                      │
│                                                              │
│  ┌──────────┐    OLLAMA_BASE_URL    ┌──────────────────┐    │
│  │  ollama  │◄────────────────────│   open-webui     │    │
│  │ :11434   │                      │   :3000          │    │
│  └──────────┘                      └──────────────────┘    │
│       │                                                      │
│  ollama-models (named volume — shared model store)          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  gitnexus-web (nginx static + WASM)        :8080       │ │
│  │  ↕ browser connects to gitnexus-serve via host port    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  gitnexus-serve (gitnexus CLI HTTP API)    :4747       │ │
│  │  mounts: ~/.gitnexus/ + repo root dirs (read-only)     │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

> **GitNexus Web** is a fully browser-side app. It connects to `gitnexus-serve` directly from your browser at `http://localhost:4747`, **not** through the Docker network. The `GITNEXUS_SERVE_PORT` env var controls which host port it listens on.

---

### Configuration

All values are set in `.env` (copy from `.env.example`):

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_DOCKER_TAG` | `latest` | Ollama image tag |
| `OLLAMA_PORT` | `11434` | Host port for Ollama API |
| `WEBUI_DOCKER_TAG` | `main` | Open WebUI image tag |
| `OPEN_WEBUI_PORT` | `3000` | Host port for Open WebUI |
| `WEBUI_SECRET_KEY` | `change-me-in-production` | Session signing secret |
| `WEBUI_AUTH` | `false` | `true` enables login/auth |
| `GITNEXUS_PORT` | `8080` | Host port for GitNexus Web UI |
| `GITNEXUS_WEB_PATH` | *(must set)* | Absolute path to `webapp-ui-gitnexus/gitnexus-web` |
| `GITNEXUS_SERVE_PORT` | `4747` | Host port for GitNexus HTTP backend |
| `GITNEXUS_CLI_PATH` | *(must set)* | Absolute path to `webapp-ui-gitnexus/gitnexus` |
| `GITNEXUS_REGISTRY_PATH` | `~/.gitnexus` | Host path to global gitnexus registry dir |
| `WORKSPACE_PATH` | *(must set)* | Absolute path to your workspace root (for repo mounts) |
| `WEBAPP_LIB_TOOLBOX_PATH` | *(must set)* | Absolute path to this `webapp-lib-toolbox` directory |
