from odoo import api, fields, models


class QmsTicket(models.Model):
    # TicketModel, from the "Model Definition" spec page:
    #   tid, quid (-> queue), ticket_name, ticket_description,
    #   customer_id (-> the end customer), created_at, updated_at.
    # Operational fields (state, position, notified) are added to support the
    # core concept: notify a customer just before their turn.
    _name = "qms.ticket"
    _description = "QMS Ticket"
    _rec_name = "ticket_name"
    _order = "tid desc"

    tid = fields.Integer(
        string="Ticket ID", required=True, copy=False, index=True,
        help="Unique id for the ticket.",
    )
    # The spec field "quid" is the link to the QueueModel; here it's the Many2one.
    quid = fields.Many2one(
        "qms.queue", string="Queue", required=True, ondelete="cascade", index=True,
    )
    ticket_name = fields.Char(string="Name")
    ticket_description = fields.Char(string="Description")
    # The end customer who booked the ticket (a person, reusing res.partner).
    customer_id = fields.Many2one("res.partner", string="Customer")

    created_at = fields.Datetime(string="Created At", default=fields.Datetime.now, readonly=True)
    updated_at = fields.Datetime(string="Updated At", readonly=True)

    # --- Operational fields (queue management + notify-before-turn) ---
    state = fields.Selection(
        selection=[
            ("waiting", "Waiting"),
            ("called", "Called"),
            ("serving", "Serving"),
            ("done", "Done"),
            ("cancelled", "Cancelled"),
        ],
        default="waiting", required=True, index=True,
    )
    # How many waiting tickets are ahead in the same queue (1 = next up).
    position = fields.Integer(string="Position", compute="_compute_position")
    notified = fields.Boolean(string="Notified", default=False)

    _sql_constraints = [
        ("tid_unique", "unique(tid)", "Ticket ID (tid) must be unique."),
    ]

    @api.depends("quid", "state", "created_at")
    def _compute_position(self):
        for ticket in self:
            if ticket.state == "waiting" and ticket.quid:
                ahead = self.search_count([
                    ("quid", "=", ticket.quid.id),
                    ("state", "=", "waiting"),
                    ("created_at", "<", ticket.created_at or fields.Datetime.now()),
                ])
                ticket.position = ahead + 1
            else:
                ticket.position = 0

    @api.model_create_multi
    def create(self, vals_list):
        # Auto-assign tid = highest existing + 1.
        now = fields.Datetime.now()
        last = self.search([], order="tid desc", limit=1)
        next_tid = (last.tid + 1) if last else 1
        for vals in vals_list:
            if not vals.get("tid"):
                vals["tid"] = next_tid
                next_tid += 1
            vals.setdefault("created_at", now)
            vals.setdefault("updated_at", now)
        return super().create(vals_list)

    def write(self, vals):
        vals.setdefault("updated_at", fields.Datetime.now())
        return super().write(vals)
