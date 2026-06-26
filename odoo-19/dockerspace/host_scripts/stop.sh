#!/bin/bash
# stop.sh — stop the Odoo 19 stack (container myodoo19-app). Data is preserved:
# the odoo19 database lives in the external mypostgresql_db, and the filestore
# lives under mountspace — `compose down` only removes this stack's container.
set -euo pipefail

# ── Mirror logging ──────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ────────────────────────────────────────────────────────────────────────────────

cd "$(dirname "${BASH_SOURCE[0]}")/.."   # dockerspace/ (compose + .env live here)

GREEN="\033[32m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"

echo -e "${YELLOW}==> Stopping Odoo 19 (docker compose down)...${RESET}"
docker compose down
echo -e "${GREEN}    Odoo 19 stopped. Data preserved (odoo19 DB + filestore).${RESET}"
echo -e "    Run ${BOLD}start.sh${RESET} to bring it back up."
