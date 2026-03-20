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

# 3. (Corporate/VPN networks) Generate the proxy CA cert bundle
#    Ollama needs this to pull models through TLS-inspecting proxies
#    First find your proxy CN: openssl s_client -connect registry.ollama.ai:443 2>/dev/null | grep issuer
mkdir -p certs
python3 -c "
import subprocess, re, sys
proxy_name = sys.argv[1] if len(sys.argv) > 1 else 'your-proxy-name'
out = subprocess.check_output(['security','find-certificate','-a','-c', proxy_name,'-p','/Library/Keychains/System.keychain'], stderr=subprocess.DEVNULL).decode()
open('certs/corporate-proxy.pem','w').write(out)
print(f'Wrote {len(re.findall(\"BEGIN CERTIFICATE\",out))} certs to certs/corporate-proxy.pem')
" your-proxy-cn
# Skip step 3 if not on a corporate network — remove the cert volume
# from the ollama service in docker-compose.yml if not needed

# 4. (First time) Index a repo so gitnexus-serve has something to serve
cd ../your-repo && npx gitnexus analyze && cd -

# 5. Uncomment your repo mounts in docker-compose.yml (gitnexus-serve volumes)

# 6. Start everything (builds gitnexus images on first run — ~2 min)
docker compose up -d

# 7. Pull a model into Ollama (e.g. llama3.2)
docker exec ollama ollama pull llama3.2
```

- Open [http://localhost:3000](http://localhost:3000) → **Open WebUI** — create an admin account on first launch
- Open [http://localhost:8080](http://localhost:8080) → **GitNexus graph explorer** — click "Connect to local server"

> **Shortcut**: Source `skills/docker.sh` in your shell for `dc` aliases — `dcup`, `dcb`, `olpull llama3.2`, etc.

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

> **Tip**: Source `skills/docker.sh` for short aliases. Add this to your `~/.bashrc` or `scripts/personal.sh` in `tool-development-utility`:
> ```bash
> source /absolute/path/to/webapp-lib-toolbox/skills/docker.sh
> ```

| Alias | Full command | Purpose |
|---|---|---|
| `dcup` | `docker compose up -d` | Start all services |
| `dcdown` | `docker compose down` | Stop all (volumes preserved) |
| `dcb` | `docker compose build` | Build all images |
| `dcbup` | `docker compose build && docker compose up -d` | Build then start |
| `dcbnc` | `docker compose build --no-cache` | Build ignoring cache |
| `dcrestart` | `docker compose restart` | Restart all services |
| `dcl` | `docker compose logs -f` | Tail all logs |
| `dcps` | `docker compose ps` | Show running services |
| `ollist` | `docker exec ollama ollama list` | List downloaded models |
| `olpull` | `docker exec ollama ollama pull` | Pull a model |
| `olrm` | `docker exec ollama ollama rm` | Remove a model |

```bash
# Rebuild a single service after source changes
docker compose build gitnexus-web && docker compose up -d gitnexus-web

# Reload after indexing a new repo (no rebuild needed)
docker compose restart gitnexus-serve

# Stop all and delete volumes ⚠️  model downloads will be lost
docker compose down -v

# Pull latest upstream images (ollama + open-webui)
docker compose pull ollama open-webui && docker compose up -d
```

---

### File Structure

```
webapp-lib-toolbox/
├── docker-compose.yml              # Main orchestration (4 services)
├── .env                            # Local env config (gitignored)
├── .env.example                    # Template — copy to .env
├── certs/                          # Corporate proxy CA certs (gitignored)
│   └── corporate-proxy.pem         # Generated locally — see Quick Start step 3
├── skills/
│   └── docker.sh                   # Shell aliases: dcup, dcb, olpull, etc.
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

### TLS / Corporate Network

On networks with TLS inspection (e.g. enterprise proxies that re-sign HTTPS traffic), Ollama will fail to pull models with a certificate error:
```
Error: pull model manifest: tls: failed to verify certificate: x509: certificate signed by unknown authority
```

**Step 1 — Find your proxy's certificate name:**
```bash
openssl s_client -connect registry.ollama.ai:443 2>/dev/null | grep issuer
# Look for the CN= value, e.g. CN=myproxy.company.com
```

**Step 2 — Generate the cert bundle and restart Ollama:**
```bash
mkdir -p certs
python3 -c "
import subprocess, re, sys
proxy_name = sys.argv[1] if len(sys.argv) > 1 else 'your-proxy-name'
out = subprocess.check_output(['security','find-certificate','-a','-c', proxy_name,'-p','/Library/Keychains/System.keychain'], stderr=subprocess.DEVNULL).decode()
open('certs/corporate-proxy.pem','w').write(out)
print(f'Wrote {len(re.findall(\"BEGIN CERTIFICATE\",out))} certs')
" <your-proxy-cn>
docker compose up -d --force-recreate ollama
```

The `certs/` directory is gitignored — the cert file is generated locally and never committed.

> **Not on a corporate network?** Remove the `certs/` volume mount and the `SSL_CERT_FILE` / `REQUESTS_CA_BUNDLE` env vars from the `ollama` service in `docker-compose.yml`.

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
