#!/bin/bash
# upgrade_qms.sh — reload an Odoo module after you change its code/XML/data.
# Addons are bind-mounted, so Python/views are live on disk, but the RUNNING
# server still holds the OLD registry → you must upgrade the DB (-u) and restart.
#
# Run on the HOST:
#   bash upgrade_qms.sh            # upgrades 'qms' (default)
#   bash upgrade_qms.sh <module>   # upgrades any module by name
#
# Minimal 19 stack note: odoo-bin IS the container's main process (no agent to
# manage it), so the safe sequence is stop → upgrade in a one-off container →
# start, avoiding two odoo-bin processes touching odoo19 at once.
set -uo pipefail

# ── Mirror logging ──────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ────────────────────────────────────────────────────────────────────────────────

cd "$(dirname "${BASH_SOURCE[0]}")/.."   # dockerspace/ (compose + .env live here)

DB=odoo19
MODULE="${1:-qms}"

echo "==> [1/3] Stopping Odoo 19..."
docker compose stop odoo

echo "==> [2/3] Upgrading module '$MODULE' on DB '$DB' (loads code + new deps)..."
if docker compose run --rm odoo ./odoo-bin -d "$DB" -u "$MODULE" --stop-after-init; then
    echo "==> Module '$MODULE' upgraded."
else
    echo "!! Upgrade FAILED — check the output above. Restarting with existing code." >&2
fi

echo "==> [3/3] Bringing Odoo 19 back up..."
docker compose up -d
echo "==> Done. http://localhost:8079"
