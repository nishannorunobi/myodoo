from odoo import api, fields, models


class QmsService(models.Model):
    # A Service is a buyer company's PURCHASED subscription to a service plan,
    # which it then offers to its own customers. It consists of one or more
    # queues (per the spec: "a service consists of single or multiple queues").
    # Hierarchy:  Service Plan (product) → Service (purchase) → Queue → Ticket.
    _name = "qms.service"
    _description = "QMS Service"
    _order = "sequence, name"

    name = fields.Char(required=True)
    code = fields.Char(help="Short prefix, e.g. 'B' for Billing.")

    # The plan (product) bought from the QMS provider.
    plan_id = fields.Many2one("qms.service.plan", string="Service Plan")

    # The buyer/tenant company that purchased this service. We reuse Odoo's
    # res.partner (is_company) rather than reinventing a company model.
    customer_company_id = fields.Many2one(
        "res.partner", string="Buyer Company",
        domain=[("is_company", "=", True)],
        help="The company that bought this service from the QMS provider.",
    )

    # Subscription lifecycle of the purchase.
    state = fields.Selection(
        selection=[("draft", "Draft"), ("running", "Running"), ("expired", "Expired")],
        default="draft", required=True,
    )
    date_start = fields.Date(string="Start Date")
    date_end = fields.Date(string="End Date")

    sequence = fields.Integer(default=10)
    active = fields.Boolean(default=True)
    color = fields.Integer(string="Color Index")
    description = fields.Text()

    queue_ids = fields.One2many("qms.queue", "service_id", string="Queues")
    queue_count = fields.Integer(string="# Queues", compute="_compute_queue_count")

    @api.depends("queue_ids")
    def _compute_queue_count(self):
        grouped = self.env["qms.queue"].read_group(
            domain=[("service_id", "in", self.ids)],
            fields=["service_id"], groupby=["service_id"],
        )
        counts = {g["service_id"][0]: g["service_id_count"] for g in grouped}
        for service in self:
            service.queue_count = counts.get(service.id, 0)
