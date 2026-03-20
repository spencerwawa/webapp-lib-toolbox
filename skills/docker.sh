#!/bin/sh
# DOCKER COMPOSE ALIASES
# Shortcuts for common docker compose commands, all prefixed with 'dc'
# Source this file or add to your shell configuration

# ── Core lifecycle ─────────────────────────────────────────────────────────────
alias dcup="docker compose up -d"                        # start all services (detached)
alias dcupf="docker compose up"                          # start all services (foreground/logs visible)
alias dcdown="docker compose down"                       # stop all services (volumes preserved)
alias dcdownv="docker compose down -v"                   # stop all + delete volumes ⚠️  destructive
alias dcrestart="docker compose restart"                 # restart all services
alias dcstop="docker compose stop"                       # stop without removing containers
alias dcstart="docker compose start"                     # start stopped containers

# ── Build ──────────────────────────────────────────────────────────────────────
alias dcb="docker compose build"                         # build all images
alias dcbnc="docker compose build --no-cache"            # build all, ignore cache
alias dcbup="docker compose build && docker compose up -d" # build then start

# ── Single service shortcuts ───────────────────────────────────────────────────
# Usage: dcups <service>   e.g. dcups ollama
alias dcups="docker compose up -d"                       # start a specific service (pass name)
alias dcbs="docker compose build"                        # build a specific service (pass name)
alias dcrs="docker compose restart"                      # restart a specific service (pass name)

# ── Logs ───────────────────────────────────────────────────────────────────────
alias dcl="docker compose logs -f"                       # tail all logs
alias dcls="docker compose logs -f --tail=50"            # tail last 50 lines, all services
# Usage: dcll <service>   e.g. dcll ollama
alias dcll="docker compose logs -f --tail=50"            # tail logs for a specific service (pass name)

# ── Status & inspection ────────────────────────────────────────────────────────
alias dcps="docker compose ps"                           # list running services
alias dctop="docker compose top"                         # show running processes inside containers
alias dcconfig="docker compose config"                   # validate and print resolved compose config

# ── Exec & shell ───────────────────────────────────────────────────────────────
# Usage: dcsh <service>   e.g. dcsh ollama
dcsh() {
    if [ -z "$1" ]; then
        echo "Usage: dcsh <service>" >&2
        echo "Example: dcsh ollama" >&2
        return 1
    fi
    docker compose exec "$1" sh
}

# Usage: dcbash <service>   e.g. dcbash open-webui
dcbash() {
    if [ -z "$1" ]; then
        echo "Usage: dcbash <service>" >&2
        echo "Example: dcbash open-webui" >&2
        return 1
    fi
    docker compose exec "$1" bash
}

# Usage: dcrun <service> <command>   e.g. dcrun ollama ollama list
dcrun() {
    if [ -z "$1" ]; then
        echo "Usage: dcrun <service> <command>" >&2
        echo "Example: dcrun ollama ollama list" >&2
        return 1
    fi
    docker compose exec "$@"
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
alias dcprune="docker system prune -f"                   # remove stopped containers, unused networks, dangling images
alias dcprunea="docker system prune -af"                 # remove everything unused (including unused images) ⚠️
alias dcrmi="docker compose down --rmi local"            # stop and remove locally built images

# ── Pull ───────────────────────────────────────────────────────────────────────
alias dcpull="docker compose pull"                       # pull latest versions of all images
alias dcupdate="docker compose pull && docker compose up -d" # pull latest then restart

# ── Ollama shortcuts (within docker compose stack) ────────────────────────────
alias ollist="docker exec ollama ollama list"            # list downloaded models
alias olpull="docker exec ollama ollama pull"            # pull a model  e.g. olpull llama3.2
alias olrm="docker exec ollama ollama rm"                # remove a model  e.g. olrm llama3.2
alias olrun="docker exec -it ollama ollama run"          # run a model in terminal  e.g. olrun llama3.2
