#!/bin/bash
# download_src.sh — fetch the Odoo 19.0 source into ./odoo (parallel to the
# Odoo 17 setup one level up). odoo.conf is kept OUTSIDE this dir (../odoo.conf,
# mounted in via compose) so re-downloading the source never wipes the config.
set -euo pipefail

# ── Mirror logging ──────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ────────────────────────────────────────────────────────────────────────────────

cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION=19.0
rm -rf odoo
wget https://github.com/odoo/odoo/archive/refs/heads/${VERSION}.tar.gz -O odoo-${VERSION}.tar.gz
mkdir -p odoo
tar -xzf odoo-${VERSION}.tar.gz -C odoo --strip-components=1
rm odoo-${VERSION}.tar.gz
echo "==> Odoo ${VERSION} source ready in ./odoo"
