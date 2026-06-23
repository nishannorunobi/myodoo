#!/bin/bash
# start.sh — Start the Odoo 17 service (odoo-bin) inside myodoo-app.
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

ODOO_HOME="${ODOO_HOME:-/myodoo/odoo}"
ODOO_PORT="${ODOO_PORT:-8069}"
PID_FILE="/tmp/odoo.pid"

# Already up? (port is the source of truth — Odoo may have been started by the
# container command rather than this script).
if (exec 3<>/dev/tcp/127.0.0.1/${ODOO_PORT}) 2>/dev/null; then
    exec 3>&- 2>/dev/null || true
    echo "[odoo] already listening on :${ODOO_PORT} — nothing to do."
    exit 0
fi

# Odoo's own log goes to the mirror tree so it shows up in the log stack.
ODOO_LOG="${LOG_MIRROR_ROOT:-/tmp/logs}/odoo_log.log"
mkdir -p "$(dirname "$ODOO_LOG")"

cd "$ODOO_HOME"
echo "[odoo] launching odoo-bin (ODOO_RC=${ODOO_RC:-<default>}, log → $ODOO_LOG)..."
./odoo-bin >> "$ODOO_LOG" 2>&1 &
echo $! > "$PID_FILE"
echo "[odoo] started (PID $(cat "$PID_FILE")). Web UI: http://localhost:${ODOO_PORT}"
