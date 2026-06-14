#!/bin/bash
# destroy.sh — Stop Odoo AND delete its filestore volume (full reset of Odoo state).
# WARNING: This deletes the Odoo filestore (attachments, sessions).
# NOTE: This does NOT drop the Odoo database in mypostgresql_db-container — drop
#       that manually if you want a truly clean slate (see readme.md).
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

RED="\033[31m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"

echo -e "${RED}${BOLD}WARNING: This will delete the Odoo filestore volume.${RESET}"
echo -e "${YELLOW}The Odoo database in mypostgresql_db-container is NOT touched by this script.${RESET}"
read -r -p "Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo -e "${YELLOW}==> Stopping Odoo and removing its volume...${RESET}"
docker compose down -v --remove-orphans
echo -e "${RED}    Odoo filestore deleted.${RESET}"
echo -e "    Run ${BOLD}./start.sh${RESET} to start fresh."
