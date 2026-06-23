#!/bin/bash
# upgrade.sh — upgrade the qms Odoo module (reload code + install new deps like
# 'website'). Runs INSIDE myodoo-app, invoked by the odoo-agent (⬆ Upgrade button).
# Stops Odoo, runs the upgrade, then restarts it via the sibling start.sh so it
# always comes back up — even if the upgrade itself errors.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="${ODOO_DB:-myodoo}"            # no db_name in odoo.conf → pass it explicitly
MODULE="${QMS_MODULE:-qms}"
ODOO_HOME="${ODOO_HOME:-/myodoo/odoo}"

echo "[upgrade] stopping Odoo..."
bash "$SCRIPT_DIR/stop.sh" || true
sleep 2

echo "[upgrade] upgrading module '$MODULE' on DB '$DB' (loads code + installs new deps)..."
cd "$ODOO_HOME"
if ./odoo-bin -d "$DB" -u "$MODULE" --stop-after-init; then
    echo "[upgrade] module '$MODULE' upgraded."
else
    echo "[upgrade] FAILED — see output above. Restarting Odoo with existing code." >&2
fi

echo "[upgrade] restarting Odoo..."
bash "$SCRIPT_DIR/start.sh"
echo "[upgrade] done — try http://localhost:8069/qms/register"
