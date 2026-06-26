from odoo import http
from odoo.http import request


class QmsPublicController(http.Controller):
    """FEATURE 8 — Public website page (Category 7).

    Customers subscribe to a queue remotely (the core QMS concept): they pick a
    queue, leave their name/phone, and get a ticket number — before arriving on
    site. Rendered server-side via Python QWeb, no login required.
    """

    @http.route("/qms/book", type="http", auth="public", website=True, methods=["GET"])
    def qms_book_form(self, **kw):
        # Anonymous visitors can't read qms.queue (group_user only) → sudo().
        queues = request.env["qms.queue"].sudo().search(
            [], order="service_id, quid",
        )
        return request.render("qms.qms_book_form", {
            "queues": queues,
            "error": kw.get("error"),
        })

    @http.route("/qms/book/submit", type="http", auth="public", website=True,
                methods=["POST"])
    def qms_book_submit(self, **post):
        quid = post.get("quid")
        name = (post.get("customer_name") or "").strip()
        phone = (post.get("customer_phone") or "").strip()

        if not quid:
            return request.redirect("/qms/book?error=Please%20choose%20a%20queue")

        queue = request.env["qms.queue"].sudo().browse(int(quid)).exists()
        if not queue:
            return request.redirect("/qms/book?error=Invalid%20queue")

        # Reuse res.partner for the customer: find by phone, else create one.
        Partner = request.env["res.partner"].sudo()
        partner = Partner.search([("phone", "=", phone)], limit=1) if phone else Partner
        if not partner:
            partner = Partner.create({
                "name": name or "Queue Customer",
                "phone": phone or False,
            })

        # sudo(): public users have no create right on qms.ticket. tid is
        # auto-assigned by the model's create() override.
        ticket = request.env["qms.ticket"].sudo().create({
            "quid": queue.id,
            "customer_id": partner.id,
            "ticket_name": name or partner.name,
        })
        return request.render("qms.qms_book_success", {"ticket": ticket})
