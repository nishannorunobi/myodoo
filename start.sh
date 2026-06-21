#!/bin/bash
# start.sh — Start Odoo (Community). Reuses the existing mypostgresql_db container.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; BOLD="\033[1m"; RESET="\033[0m"

[ -f ".env" ] || { echo -e "${RED}[ERROR]${RESET} .env not found."; exit 1; }
source .env

# ── Preflight: shared network must exist (created by mypostgresql_db/start.sh) ──
if ! docker network inspect my_docker_network &>/dev/null; then
    echo -e "${RED}[ERROR]${RESET} Docker network 'my_docker_network' not found."
    echo -e "        Start the Postgres project first: ${BOLD}projectspace/mypostgresql_db/dockerspace/host_scripts/start.sh${RESET}"
    exit 1
fi

# ── Preflight: Postgres container must be running ───────────────────────────────
if ! docker inspect -f '{{.State.Running}}' mypostgresql_db-container 2>/dev/null | grep -q '^true$'; then
    echo -e "${RED}[ERROR]${RESET} mypostgresql_db-container is not running. Start it before Odoo."
    exit 1
fi

# ── Ensure the mirror log dir exists and is writable by the odoo user (uid 101) ─
LOG_DIR="$_WS_ROOT/mountspace/logs/myworkspace/projectspace/myodoo"
mkdir -p "$LOG_DIR"
chmod 777 "$LOG_DIR" 2>/dev/null || true

echo -e "${BOLD}==> Starting Odoo ${ODOO_VERSION}...${RESET}"
docker compose up -d

echo ""
echo -e "${GREEN}${BOLD}==> Odoo is starting${RESET}"
echo -e "    Web UI    : ${BOLD}http://localhost:${ODOO_PORT}${RESET}"
echo -e "    Database  : ${BOLD}${DB_USER}@mypostgresql_db-container:${DB_PORT}${RESET} (over my_docker_network)"
echo ""
echo -e "    ${YELLOW}First run:${RESET} create the 'odoo' Postgres role first (see readme.md), then open the"
echo -e "    web UI to create a database and install the ${BOLD}Website${RESET} + ${BOLD}eCommerce${RESET} apps."
echo ""
echo -e "    ${BOLD}./logs.sh${RESET}    — tail logs"
echo -e "    ${BOLD}./status.sh${RESET}  — container status"
echo -e "    ${BOLD}./stop.sh${RESET}    — stop (data preserved)"
echo -e "    ${BOLD}./destroy.sh${RESET} — stop + wipe Odoo filestore volume"
