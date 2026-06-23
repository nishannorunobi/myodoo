from odoo import fields, models


class QmsServicePlan(models.Model):
    # The QMS provider's catalogue of sellable services ("service as a product").
    # A buyer company purchases a plan; that purchase is a qms.service record.
    # Provider tier ("Me" / the datacenter) is Odoo's own res.company.
    _name = "qms.service.plan"
    _description = "QMS Service Plan"
    _order = "name"

    name = fields.Char(required=True)
    code = fields.Char(help="Short product code.")
    description = fields.Text()
    # What a buyer company pays the QMS provider for this plan.
    price = fields.Float(string="Price")
    active = fields.Boolean(default=True)

    # All buyer subscriptions (qms.service) bought against this plan.
    service_ids = fields.One2many("qms.service", "plan_id", string="Subscriptions")
