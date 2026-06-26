/** @odoo-module **/

import { registry } from "@web/core/registry";
import { useService } from "@web/core/utils/hooks";
import { Component, useState, onWillStart } from "@odoo/owl";

/**
 * QMS Console — a client action (Category 4) that gives the app a collapsible
 * left sidebar instead of a crowded top menu bar. Clicking a sidebar item
 * launches that model's standard list/form view via the action service.
 */
export class QmsConsole extends Component {
    setup() {
        this.action = useService("action");
        this.orm = useService("orm");
        this.state = useState({ collapsed: false, stats: {} });
        onWillStart(() => this.loadStats());
    }

    // Sidebar navigation — extend this list as the app grows; the top bar
    // stays clean because nav lives here, not in menus.
    get navItems() {
        return [
            { label: "Tickets", icon: "fa-ticket", action: "qms.action_qms_ticket" },
            { label: "Queues", icon: "fa-list-ol", action: "qms.action_qms_queue" },
            { label: "Service Plans", icon: "fa-cubes", action: "qms.action_qms_service_plan" },
            { label: "Services", icon: "fa-briefcase", action: "qms.action_qms_service" },
        ];
    }

    async loadStats() {
        const [waiting, serving, queues, services, plans] = await Promise.all([
            this.orm.searchCount("qms.ticket", [["state", "=", "waiting"]]),
            this.orm.searchCount("qms.ticket", [["state", "=", "serving"]]),
            this.orm.searchCount("qms.queue", []),
            this.orm.searchCount("qms.service", []),
            this.orm.searchCount("qms.service.plan", []),
        ]);
        this.state.stats = { waiting, serving, queues, services, plans };
    }

    toggle() {
        this.state.collapsed = !this.state.collapsed;
    }

    openAction(xmlid) {
        // doAction resolves the act_window by its XML id and opens it in the
        // main area (full standard CRUD views).
        this.action.doAction(xmlid);
    }
}

QmsConsole.template = "qms.QmsConsole";

registry.category("actions").add("qms_console", QmsConsole);
