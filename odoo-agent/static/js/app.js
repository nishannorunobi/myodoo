// OdooApp — nav routing, panel wiring, auto-refresh
class OdooApp {
  constructor() {
    this.log    = new LogPanel();
    this.health = new HealthPanel();
    this.stack  = new StackPanel(this.log);   // generic tool manager (Odoo service)
    this.chat   = new ChatPanel();
    window._app = this;
  }

  switchSection(name) {
    document.querySelectorAll('.section-panel').forEach(el => {
      el.style.display = el.dataset.section === name ? '' : 'none';
    });
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.section === name);
    });
    if (name === 'service') this.stack.render();
  }

  async refresh() {
    try {
      const h = await Api.get('/health');
      this.health.updateBadges(h);
      this.health.renderFields(h);
      this.stack.render();
    } catch (_) {}
  }

  start() {
    this.switchSection('service');
    this.refresh();
    setInterval(() => this.refresh(), 15000);
    this.log._applyState();
  }
}

document.addEventListener('DOMContentLoaded', () => new OdooApp().start());
