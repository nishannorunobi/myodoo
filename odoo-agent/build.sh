#!/bin/bash
# build.sh — Install the odoo-agent Python dependencies INSIDE myodoo-app.
# myodoo uses a global pip (python:3.11-slim, Odoo deps installed globally), so
# the agent installs globally too — no venv (follow the project's convention).
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED="\033[31m"; GREEN="\033[32m"; CYAN="\033[36m"; RESET="\033[0m"
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[ OK ]${RESET}  $*"; }

info "Installing odoo-agent Python dependencies (global pip)..."
# --root-user-action=ignore: silence pip's "running as root" warning. It's safe
# here — this runs inside the odoo container, an isolated environment by design.
pip install --quiet --root-user-action=ignore --upgrade pip
pip install --quiet --root-user-action=ignore -r requirements.txt
success "Python dependencies installed."

# ── agent.conf ────────────────────────────────────────────────────────────────
if [ ! -f "agent.conf" ]; then
    cp agent.conf.example agent.conf
    echo -e "${RED}[ACTION REQUIRED]${RESET} Edit agent.conf and set your ANTHROPIC_API_KEY"
else
    success "agent.conf exists."
fi

mkdir -p memory
success "Build complete. Start the agent with: bash start.sh"
