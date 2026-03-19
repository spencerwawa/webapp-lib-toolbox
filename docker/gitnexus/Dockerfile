# ============================================================
# GitNexus Web UI — Docker Build
# ============================================================
# Multi-stage build:
#   Stage 1 (builder) — installs deps and builds the Vite/React app
#   Stage 2 (serve)   — serves static output from nginx
#
# Build context: the gitnexus-web directory
# Dockerfile path: specified via `dockerfile:` in docker-compose.yml
# so it can live outside the build context in webapp-lib-toolbox.
#
# The nginx config is written inline (heredoc) so this Dockerfile
# remains self-contained regardless of where it lives on disk.
# ============================================================

# --- Stage 1: Build ----------------------------------------
FROM node:20-alpine AS builder

WORKDIR /app

# Corporate proxy uses SSL inspection — disable strict SSL so npm registry works
RUN npm config set strict-ssl false

# Copy package files first for better layer caching
COPY package.json ./

# Install dependencies fresh (no lock file — avoids macOS vs Linux arm64 native
# binary mismatch with @rollup/rollup-linux-arm64-musl and similar optional deps).
# --ignore-scripts skips post-install native binary compilation, which stalls on Alpine arm64.
RUN npm install --ignore-scripts

# Copy the rest of the source
COPY . .

# Build the static site
RUN npm run build

# --- Stage 2: Serve ----------------------------------------
FROM nginx:alpine AS serve

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Write the nginx config inline.
# COOP + COEP headers are REQUIRED for KuzuDB WASM / SharedArrayBuffer.
RUN printf '%s\n' \
  'server {' \
  '    listen 80;' \
  '    server_name _;' \
  '    root /usr/share/nginx/html;' \
  '    index index.html;' \
  '    add_header Cross-Origin-Opener-Policy "same-origin" always;' \
  '    add_header Cross-Origin-Embedder-Policy "require-corp" always;' \
  '    location ~* \.(js|css|wasm|woff2?|ttf|svg|png|ico|json)$ {' \
  '        expires 1y;' \
  '        add_header Cache-Control "public, immutable";' \
  '        add_header Cross-Origin-Opener-Policy "same-origin" always;' \
  '        add_header Cross-Origin-Embedder-Policy "require-corp" always;' \
  '        try_files $uri =404;' \
  '    }' \
  '    location / {' \
  '        try_files $uri $uri/ /index.html;' \
  '    }' \
  '}' \
  > /etc/nginx/conf.d/gitnexus.conf

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
