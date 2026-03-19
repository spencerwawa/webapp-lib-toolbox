#!/bin/sh
# ============================================================
# GitNexus Serve — Docker Entrypoint
# ============================================================
# Builds ~/.gitnexus/registry.json from environment variables
# that point to mounted .gitnexus/ index directories, then
# starts the HTTP server so gitnexus-web can connect.
#
# Environment variables:
#   GITNEXUS_SERVE_PORT  — port to listen on (default: 4747)
#   GITNEXUS_REPO_1      — absolute container path to a repo root
#   GITNEXUS_REPO_2      — (repeat for each repo, numbered 1..N)
#
# Each GITNEXUS_REPO_N must be a path where:
#   $path/.gitnexus/meta.json  exists (the index)
#   $path/.gitnexus/kuzu/      exists (the graph DB)
# ============================================================

set -e

REGISTRY_FILE="/root/.gitnexus/registry.json"
mkdir -p /root/.gitnexus

echo "[] "> "$REGISTRY_FILE"

# Collect repo paths from GITNEXUS_REPO_1, GITNEXUS_REPO_2, ...
i=1
ENTRIES="["
FIRST=1

while true; do
  VAR="GITNEXUS_REPO_${i}"
  REPO_PATH=$(eval "echo \"\$$VAR\"")
  [ -z "$REPO_PATH" ] && break

  META_FILE="${REPO_PATH}/.gitnexus/meta.json"
  if [ -f "$META_FILE" ]; then
    REPO_NAME=$(basename "$REPO_PATH")
    STORAGE_PATH="${REPO_PATH}/.gitnexus"
    INDEXED_AT=$(node -e "try{const m=require('$META_FILE');console.log(m.indexedAt||new Date().toISOString())}catch{console.log(new Date().toISOString())}" 2>/dev/null || echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)")

    if [ "$FIRST" = "0" ]; then
      ENTRIES="${ENTRIES},"
    fi
    ENTRIES="${ENTRIES}{\"name\":\"${REPO_NAME}\",\"path\":\"${REPO_PATH}\",\"storagePath\":\"${STORAGE_PATH}\",\"indexedAt\":\"${INDEXED_AT}\",\"lastCommit\":\"\"}"
    FIRST=0
    echo "  ✓ Registered repo: ${REPO_NAME} (${REPO_PATH})"
  else
    echo "  ✗ Skipping ${REPO_PATH} — no .gitnexus/meta.json found"
  fi

  i=$((i + 1))
done

ENTRIES="${ENTRIES}]"
echo "$ENTRIES" > "$REGISTRY_FILE"

REGISTERED=$(echo "$ENTRIES" | node -e "const d=require('/dev/stdin');process.stdout.write(String(d.length))" 2>/dev/null || echo "?")
echo "GitNexus registry: ${REGISTERED} repo(s) registered"
echo ""

PORT="${GITNEXUS_SERVE_PORT:-4747}"
echo "Starting GitNexus serve on 0.0.0.0:${PORT} ..."

exec node /app/dist/cli/index.js serve --host 0.0.0.0 --port "$PORT"
