// HealthPanel — updates header badge dots from /health response
class HealthPanel {
  updateBadges(h) {
    const odooDot = $id('odoo-dot');
    const lpDot   = $id('lp-dot');
    if (odooDot) odooDot.className = 'dot ' + (h.odoo_reachable ? 'up' : (h.odoo_running ? 'warn' : 'down'));
    if (lpDot)   lpDot.className   = 'dot ' + (h.longpolling_running ? 'up' : 'down');
  }

  renderFields(h) {
    const box = $id('health-fields');
    if (!box) return;
    const row = (k, v, ok) =>
      `<div class="field-row"><span class="field-key">${esc(k)}</span>` +
      `<span class="field-val ${ok === undefined ? 'plain' : (ok ? 'ok' : 'bad')}">${esc(v)}</span></div>`;
    box.innerHTML =
      row('Odoo process (:8069)', h.odoo_running ? 'running' : 'stopped', !!h.odoo_running) +
      row('Odoo /web/health',     h.odoo_reachable ? 'reachable' : 'unreachable', !!h.odoo_reachable) +
      row('Longpolling (:8072)',  h.longpolling_running ? 'running' : 'stopped', !!h.longpolling_running) +
      row('Agent',                h.agent_running ? 'running' : 'down', !!h.agent_running) +
      row('Checked at',           h.timestamp || '—');
  }
}
window.HealthPanel = HealthPanel;
