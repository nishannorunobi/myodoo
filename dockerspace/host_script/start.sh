#!/bin/bash
# start.sh — build the Odoo image, initialize the DB on first run (-i base),
# then bring the stack up. Reuses the already-running mypostgresql_db container.
set -euo pipefail

# ── Mirror logging ──────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ────────────────────────────────────────────────────────────────────────────────

cd "$(dirname "${BASH_SOURCE[0]}")/.."   # dockerspace/ (compose + .env live here)
DB=myodoo

# Preflight: Odoo reuses the running Postgres over my_docker_network.
docker network inspect my_docker_network >/dev/null 2>&1 \
    || { echo "[ERROR] my_docker_network not found — start mypostgresql_db first."; exit 1; }
docker inspect -f '{{.State.Running}}' mypostgresql_db-container 2>/dev/null | grep -q true \
    || { echo "[ERROR] mypostgresql_db-container is not running."; exit 1; }

echo "==> Building image..."
docker compose build

# First run only: if the DB has no Odoo schema, install base to create the tables.
if ! docker exec mypostgresql_db-container psql -U postgres -d "$DB" -tAc \
        "select to_regclass('public.ir_module_module')" 2>/dev/null | grep -q ir_module_module; then
    echo "==> Initializing $DB (-i base)..."
    docker compose run --rm odoo ./odoo-bin -d "$DB" -i base --stop-after-init
fi

echo "==> Starting Odoo..."
docker compose up -d
echo "==> http://localhost:8069"
