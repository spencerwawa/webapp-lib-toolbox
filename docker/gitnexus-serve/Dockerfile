# ============================================================
# GitNexus Serve — Docker Build
# ============================================================
# Builds the gitnexus CLI from the gitnexus/ source directory
# and runs `gitnexus serve --host 0.0.0.0` as an HTTP backend.
#
# The HTTP API (default port 4747) lets the gitnexus-web UI
# connect to pre-indexed repos without re-uploading code.
#
# Build context : webapp-ui-gitnexus/gitnexus  (set via GITNEXUS_CLI_PATH in .env)
# Dockerfile    : webapp-lib-toolbox/docker/gitnexus-serve/Dockerfile
#
# Repo indexes are supplied at runtime via bind mounts in docker-compose.yml.
# The host's ~/.gitnexus/registry.json is mounted at /root/.gitnexus so the
# serve process discovers which repos are available.
# ============================================================

# Single-stage build on full Debian node:20 — avoids cross-arch native binary
# mismatches that occur when copying node_modules between stages.
# python3/make/g++ are pre-installed so kuzu and tree-sitter compile correctly.
FROM node:20

WORKDIR /app

# Corporate proxy uses SSL inspection with a self-signed cert.
# Disable strict SSL for npm so registry requests succeed inside Docker.
RUN npm config set strict-ssl false

# Copy package files first for layer caching
COPY package.json package-lock.json* ./

# Install all deps. --ignore-scripts prevents tree-sitter/kuzu native addon
# post-install scripts from crashing npm on this platform.
# Then run ONLY kuzu's install.js manually — it generates kuzu.d.ts which tsc
# needs. tree-sitter's post-install is intentionally skipped (it crashes npm).
RUN npm install --ignore-scripts && \
    node node_modules/kuzu/install.js

# Copy source and compile TypeScript → dist/
# Call tsc via its full path since --ignore-scripts skips bin symlinking.
COPY . .
RUN node_modules/typescript/bin/tsc

# Ensure the global registry directory exists (will be replaced by the bind mount)
RUN mkdir -p /root/.gitnexus

# Health check — the /api/repos endpoint returns [] when no repos are indexed
HEALTHCHECK --interval=15s --timeout=5s --retries=5 --start-period=10s \
  CMD wget -qO- http://localhost:4747/api/repos > /dev/null || exit 1

EXPOSE 4747

CMD ["node", "/app/dist/cli/index.js", "serve", "--host", "0.0.0.0"]

