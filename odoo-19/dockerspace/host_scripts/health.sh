#!/bin/bash
# health.sh — exit 0 if Odoo 19 (myodoo19-app) is running AND its web endpoint
# answers; exit 1 otherwise. Mirrors the compose healthcheck (curl /web/health).
set -uo pipefail

# ── Mirror logging ──────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ────────────────────────────────────────────────────────────────────────────────

CONTAINER=myodoo19-app
PORT=8079   # host port mapped to the container's 8069

running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)"
if [ "$running" != "true" ]; then
    echo "[health] ✗ $CONTAINER is NOT running"
    exit 1
fi
echo "[health] ✓ $CONTAINER is running"

if curl -fsS "http://localhost:${PORT}/web/health" >/dev/null 2>&1; then
    echo "[health] ✓ web responding on http://localhost:${PORT}/web/health"
    exit 0
fi
echo "[health] ✗ container up but /web/health not responding on :${PORT}"
exit 1
