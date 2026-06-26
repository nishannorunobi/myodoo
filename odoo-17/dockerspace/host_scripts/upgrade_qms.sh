#!/bin/bash
# upgrade_qms.sh — upgrade an Odoo module in the running myodoo container.
# Reloads new model/controller/view code AND installs any new dependencies
# (e.g. 'website'). Addons are bind-mounted, so no image rebuild is needed.
#
# Run on the HOST:
#   bash upgrade_qms.sh            # upgrades the 'qms' module (default)
#   bash upgrade_qms.sh <module>   # upgrades any module by name
#
# Odoo is briefly stopped during the upgrade, then restarted via the agent's
# own start.sh so it always comes back up (even if the upgrade errors).
set -uo pipefail

CONTAINER="myodoo-app"
DB="myodoo"                      # no db_name in odoo.conf, so pass it explicitly
MODULE="${1:-qms}"

restart_odoo() {
    echo "==> Restarting Odoo..."
    docker exec -d "$CONTAINER" bash /myodoo/odoo-agent/tools/odoo/start.sh
}

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "!! $CONTAINER is not running — start it first (host_scripts/start.sh)." >&2
    exit 1
fi

echo "==> [1/3] Stopping Odoo..."
docker exec "$CONTAINER" bash /myodoo/odoo-agent/tools/odoo/stop.sh || true
sleep 2

echo "==> [2/3] Upgrading module '$MODULE' on DB '$DB' (loads code + installs new deps)..."
if docker exec "$CONTAINER" bash -c "cd /myodoo/odoo && ./odoo-bin -d $DB -u $MODULE --stop-after-init"; then
    echo "==> Module '$MODULE' upgraded."
else
    echo "!! Upgrade FAILED — check the output above. Restarting Odoo with existing code." >&2
fi

echo "==> [3/3] Bringing Odoo back up..."
restart_odoo
sleep 3
echo "==> Done. Try: http://localhost:8069/qms/register"
