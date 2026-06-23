#!/bin/bash
# health.sh — Check the Odoo 17 service inside myodoo-app.
# Managed as a tool by the odoo-agent. Run INSIDE the container.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_SELF_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
_BASE="$(basename "$_SELF_ABS")"; _EXT="${_BASE##*.}"; _STEM="${_BASE%.*}"
_REL_DIR="$(dirname "${_SELF_ABS#${CONTAINER_WORKDIR:-}/}")"
[ "$_REL_DIR" = "." ] && _REL_DIR="" || _REL_DIR="/$_REL_DIR"
LOG_FILE="${LOG_MIRROR_ROOT:-/tmp/logs}${_REL_DIR}/${_STEM}_${_EXT}.log"
mkdir -p "$(dirname "$LOG_FILE")" && export LOG_FILE
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush() }' | tee -a "$LOG_FILE") 2>&1
echo "[logging] → $LOG_FILE"
# ──────────────────────────────────────────────────────────────────────────────

ODOO_PORT="${ODOO_PORT:-8069}"

if curl -fsS "http://localhost:${ODOO_PORT}/web/health" >/dev/null 2>&1; then
    echo "[ OK ] Odoo responding on :${ODOO_PORT} (/web/health 200)"
    exit 0
fi
echo "[FAIL] Odoo not responding on :${ODOO_PORT}"
exit 1
