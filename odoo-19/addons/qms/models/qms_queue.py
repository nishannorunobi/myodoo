from odoo import api, fields, models


class QmsQueue(models.Model):
    # QueueModel, exactly as defined on the "Model Definition" spec page:
    #   quid, q_name, q_description, created_at, updated_at.
    # A queue belongs to a Service (which belongs to a Customer Company).
    _name = "qms.queue"
    _description = "QMS Queue"
    _rec_name = "q_name"          # use q_name as the display name
    _order = "quid"

    quid = fields.Integer(
        string="Queue ID", required=True, copy=False, index=True,
        help="Unique id for the object.",
    )
    q_name = fields.Char(string="Name", required=True)
    q_description = fields.Char(string="Description")
    # Spec uses created_at/updated_at (distinct from Odoo's create_date/write_date).
    created_at = fields.Datetime(string="Created At", default=fields.Datetime.now, readonly=True)
    updated_at = fields.Datetime(string="Updated At", readonly=True)

    service_id = fields.Many2one(
        "qms.service", string="Service", required=True, ondelete="cascade",
    )
    ticket_ids = fields.One2many("qms.ticket", "quid", string="Tickets")
    ticket_count = fields.Integer(string="# Tickets", compute="_compute_ticket_count")

    # Odoo 19: the _sql_constraints list is replaced by models.Constraint attributes.
    _quid_unique = models.Constraint(
        "unique(quid)",
        "Queue ID (quid) must be unique.",
    )

    @api.depends("ticket_ids")
    def _compute_ticket_count(self):
        # Odoo 19 removed read_group; counting the One2many is simpler and version-safe.
        for queue in self:
            queue.ticket_count = len(queue.ticket_ids)

    @api.model_create_multi
    def create(self, vals_list):
        # Auto-assign quid = highest existing + 1 (spec: "unique id for the object").
        now = fields.Datetime.now()
        last = self.search([], order="quid desc", limit=1)
        next_quid = (last.quid + 1) if last else 1
        for vals in vals_list:
            if not vals.get("quid"):
                vals["quid"] = next_quid
                next_quid += 1
            vals.setdefault("created_at", now)
            vals.setdefault("updated_at", now)
        return super().create(vals_list)

    def write(self, vals):
        vals.setdefault("updated_at", fields.Datetime.now())
        return super().write(vals)
