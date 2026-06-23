#!/bin/bash
# start.sh — Start the odoo-agent uvicorn server inside myodoo-app on port 8896.
# Run INSIDE the container (by the container command or `docker exec`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Mirror logging ─────────────────────────────────────────────────────────────
_SELF_ABS="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
_BASE="$(basename "$_SELF_ABS")"; _EXT="${_BASE##*.}"; _STEM="${_BASE%.*}"
_REL_DIR="$(dirname "${_SELF_ABS#${CONTAINER_WORKDIR:-}/}")"
[ "$_REL_DIR" = "." ] && _REL_DIR="" || _REL_DIR="/$_REL_DIR"
LOG_FILE="${LOG_MIRROR_ROOT:-/tmp/logs}${_REL_DIR}/${_STEM}_${_EXT}.log"
mkdir -p "$(dirname "$LOG_FILE")" && export LOG_FILE
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush() }' | tee -a "$LOG_FILE") 2>&1
echo "[logging] → $LOG_FILE"
# ──────────────────────────────────────────────────────────────────────────────

echo "[start-odoo-agent] Starting odoo-agent startup sequence..."

# Self-bootstrap: if deps are missing (e.g. the container was recreated), install them.
if ! python3 -c 'import fastapi, uvicorn' 2>/dev/null; then
    echo "[start-odoo-agent] dependencies missing — running build.sh..."
    bash build.sh
fi

# Ensure agent.conf exists (build.sh creates it; copy from example if somehow absent).
[ -f agent.conf ] || cp agent.conf.example agent.conf 2>/dev/null || true

# Kill any existing odoo-agent uvicorn so a restart actually replaces it.
# This minimal image has no lsof/fuser/pkill/kill binary — scan /proc and use
# the bash `kill` builtin. (lsof was a silent no-op here, leaving stale procs.)
for _p in /proc/[0-9]*; do
    _cmd=$(tr '\0' ' ' < "$_p/cmdline" 2>/dev/null) || continue
    case "$_cmd" in
        *"uvicorn server:app"*) kill -9 "${_p#/proc/}" 2>/dev/null || true ;;
    esac
done

# uvicorn gets its own mirror log (survives after this script's tee pipe closes)
UVICORN_LOG="${LOG_MIRROR_ROOT:-/tmp/logs}/odoo-agent/server_py.log"
mkdir -p "$(dirname "$UVICORN_LOG")"

echo "[start-odoo-agent] Starting uvicorn on port 8896 (log → $UVICORN_LOG)..."
set -a; [ -f agent.conf ] && source agent.conf; set +a
uvicorn server:app --host 0.0.0.0 --port 8896 --workers 1 >> "$UVICORN_LOG" 2>&1 &
UVICORN_PID=$!
echo "[start-odoo-agent] uvicorn started (PID $UVICORN_PID)."
echo "[start-odoo-agent] Odoo agent is ready at http://localhost:8896"
