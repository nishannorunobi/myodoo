{
    "name": "Queue Management System",
    "version": "17.0.1.0.0",
    "summary": "Queue Management System — a learning tour of Odoo UI rendering",
    "category": "Services",
    "author": "Norun Nabi",
    "license": "LGPL-3",
    "depends": ["base", "website"],
    "data": [
        # Load order: security → views that define actions → menus → website.
        "security/ir.model.access.csv",
        "views/qms_service_plan_views.xml",
        "views/qms_service_views.xml",
        "views/qms_queue_views.xml",
        "views/qms_ticket_views.xml",
        "views/qms_menus.xml",
        "views/qms_public_templates.xml",
    ],
    "assets": {
        "web.assets_backend": [
            "qms/static/src/css/qms_console.css",
            "qms/static/src/js/qms_console.js",
            "qms/static/src/xml/qms_console.xml",
        ],
    },
    "application": True,
    "installable": True,
}
