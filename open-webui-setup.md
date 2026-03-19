# Open WebUI — Local Setup Guide (with Ollama)

## Overview

This documents the setup process for running [Open WebUI](https://github.com/open-webui/open-webui) locally as a chat interface for Ollama models.

The local source repo (`open-webui/`) is the full Open WebUI codebase intended for development. For simply **running** the app locally alongside Ollama, the **Docker approach is recommended** — it avoids Python version requirements and npm dependency conflicts.

---

## Prerequisites

| Tool | Required Version | Notes |
|---|---|---|
| Docker | Any recent version | `docker --version` to verify |
| Ollama | Any | `ollama --version` to verify |
| Node.js | >=18.13.0 <=22.x.x | Only needed for source/dev builds |
| Python | 3.11+ | Only needed for `pip install` approach |

---

## Known Issues (Source Repo)

### `npm install` fails — peer dependency conflict
The `package.json` has a version mismatch between `@tiptap/core` (v3) and `@tiptap/extension-bubble-menu` (which requires `@tiptap/core` v2):

```
npm error ERESOLVE unable to resolve dependency tree
npm error Found: @tiptap/core@3.x
npm error peer @tiptap/core@"^2.7.0" from @tiptap/extension-bubble-menu@2.x
```

**Workaround** (source builds only):
```bash
npm install --legacy-peer-deps
```

### `brew install open-webui` — does not exist
There is no Homebrew formula for Open WebUI. This command will fail.

### `pip install open-webui` — requires Python 3.11
The system Python on macOS is 3.9, which is too old. You would need to install Python 3.11 separately (e.g., via `pyenv` or `brew install python@3.11`) before using this method.

---

## Recommended Setup: Docker

This is the simplest and most reliable approach. The container auto-connects to the Ollama instance running on your host machine.

### Start Open WebUI

```bash
docker run -d \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

- `--add-host=host.docker.internal:host-gateway` — allows the container to reach Ollama at `localhost:11434` on your Mac
- `-v open-webui:/app/backend/data` — persists your chat history, settings, and user data
- `--restart always` — container restarts automatically after system reboots

### Access the UI

Open [http://localhost:3000](http://localhost:3000) in your browser. On first launch, create an admin account.

---

## Day-to-Day Commands

```bash
# Check container status
docker ps --filter "name=open-webui"

# Stop
docker stop open-webui

# Start (after stopping)
docker start open-webui

# View logs
docker logs open-webui --tail 50

# Remove container (data volume is preserved)
docker rm open-webui
```

## Updating to the Latest Version

```bash
docker pull ghcr.io/open-webui/open-webui:main
docker stop open-webui && docker rm open-webui
docker run -d \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

---

## Alternative: pip install (Python 3.11 required)

If you prefer to run without Docker:

```bash
# Install Python 3.11 via brew first
brew install python@3.11

# Install open-webui
python3.11 -m pip install open-webui

# Run the server
open-webui serve
```

Access at [http://localhost:8080](http://localhost:8080).

---

## Alternative: Run from Source (Development)

```bash
cd open-webui/

# Install dependencies (legacy flag required due to tiptap peer dep conflict)
npm install --legacy-peer-deps

# Start dev server
npm run dev
```

Access at [http://localhost:5173](http://localhost:5173) (Vite default).

> The dev server also runs `pyodide:fetch` as a pre-step, which requires internet access to download Pyodide assets.

---

## Ollama Tips

```bash
# List downloaded models
ollama list

# Pull a model (e.g. llama3.2)
ollama pull llama3.2

# Run a model in terminal
ollama run llama3.2
```

Open WebUI will automatically discover all models available in your local Ollama instance.
