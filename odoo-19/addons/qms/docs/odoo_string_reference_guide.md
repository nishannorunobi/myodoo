# Odoo String Reference Guide — "where does this string point?"

> Superpower: every string in a `.xml` / `.py` / controller belongs to **one of ~9 namespaces**,
> and each namespace has **one resolver**. Categorize the string → you instantly know where it is
> **defined** and who **references** it. This is how to read any Odoo file with X-ray vision.

---

## 🔑 THE 9 NAMESPACES (the whole game)

| # | Namespace | Looks like | DEFINED by | RESOLVED by | Referenced by |
|---|---|---|---|---|---|
| 1 | **Model name** | `qms.queue` | `_name="qms.queue"` | the **registry** (`ir_model`) | view `model`, action `res_model`, `env[...]`, `Many2one(...)`, `_inherit` |
| 2 | **Field name** | `q_name` | `q_name = fields.Char()` | the model's **fields** (`ir_model_fields`) | `<field name="...">`, domains, `group_by`, `_rec_name`, `@api.depends`, `order`, `related` |
| 3 | **XML-id** | `action_qms_queue` | `id="..."` on a record | **`ir_model_data`** (`xml_id→row id`) | `ref="..."`, `<menuitem action>`, `search_view_id`, `parent_id`, `groups`, `t-call` |
| 4 | **Method name** | `_compute_ticket_count`, `create` | `def ...()` on the class | **`getattr`** on the model | `compute=`, button `name=`, RPC `call_kw` (public only) |
| 5 | **Widget name** | `handle`, `statusbar` | JS, in the web addon | the **JS fields registry** | `widget="..."` |
| 6 | **Template id** | `website.layout`, `qms.qms_book_form` | `<template id=...>` (qweb view) | XML-id (`ir_model_data`) | `t-call`, `request.render(...)` |
| 7 | **URL / route** | `/qms/book` | `@http.route("/qms/book")` | the **routing map** | `<form action>`, links, `website.menu.url`, redirects |
| 8 | **Context var** | `queues`, `error` | the controller's dict / parent scope | the **render context** (that render only) | QWeb `t-foreach`, `t-if`, `t-esc` |
| 9 | **View type** | `list`, `form`, `search` | JS views registry | `view_mode`, `<list>/<form>` tag | the action / the arch |
| — | **Free text** | `string="Name"`, `help`, `<field name="name">qms.queue.form</field>` | nowhere — it's a **label** | nobody | (CSS `class="..."` is the exception → resolved in CSS bundles) |

> **Predict in 2 steps:** (a) which of the 9 is it? (b) use that row's "defined / referenced" columns.

---

## 🧭 THE FOUR "HUB" STRINGS (most connections flow through these)

```
 MODEL NAME  "qms.queue"   ← the biggest hub
     defines: the table, the registry class
     pulled by: view.model, action.res_model, env["qms.queue"], Many2one("qms.queue"),
                One2many(...,...), _inherit, _name everywhere

 FIELD NAME  "q_name"
     defines: a column + metadata
     pulled by: <field name="q_name"/>, domain [("q_name","=",..)], _rec_name="q_name",
                @api.depends("q_name"), order="q_name", related="...q_name"

 XML-ID  "action_qms_queue"   (resolved via ir_model_data)
     defines: a named pointer to a row
     pulled by: ref="action_qms_queue", <menuitem action="action_qms_queue">,
                search_view_id ref, parent_id ref, groups="module.group_xxx"

 URL  "/qms/book"   (resolved via the routing map)
     defines: an endpoint
     pulled by: <form action="/qms/book/submit">, website.menu url, <a href>, redirects
```

If a string isn't one of these four, it's usually a **method**, **widget**, **template id**,
**context var**, **view type**, or **free text** — check the table.

---

## 📄 WALKTHROUGH 1 — `qms_queue_views.xml` (every string annotated)

```xml
<record id="view_qms_queue_form"          <!-- ③ XML-id   → ir_model_data (referenced by menus/actions) -->
        model="ir.ui.view">               <!-- ① model    → which model this RECORD is created in -->
    <field name="name">qms.queue.form</field>   <!-- FREE TEXT → just a label, references nothing -->
    <field name="model">qms.queue</field>       <!-- ① model name → registry (this view is FOR qms.queue) -->
    <field name="arch" type="xml">
        <form>                            <!-- ⑨ view type → JS views registry (FormRenderer) -->
            <field name="q_name"/>        <!-- ② field name → resolved on qms.queue (must exist) -->
            <field name="quid" readonly="1"/>   <!-- ② field + attr override -->
            <field name="service_id"/>    <!-- ② field (Many2one → its relation points to ①qms.service) -->
        </form>
    </field>
</record>

<record id="action_qms_queue" model="ir.actions.act_window">   <!-- ③ XML-id + ① model -->
    <field name="res_model">qms.queue</field>          <!-- ① model name → what the action opens -->
    <field name="view_mode">list,form</field>          <!-- ⑨ view types -->
    <field name="search_view_id" ref="view_qms_queue_search"/>  <!-- ③ XML-id REFERENCE → ir_model_data -->
</record>
```
Search-view extras:
```xml
<filter name="group_service" context="{'group_by': 'service_id'}"/>
        <!--  name=… is a filter id (local)   ;  'service_id' inside context = ② field name  -->
```

---

## 📄 WALKTHROUGH 2 — `qms_queue.py` (every string annotated)

```python
_name = "qms.queue"                 # ① DEFINES the model-name hub (everything points here)
_rec_name = "q_name"                # ② field name (which field is the display name)
_order = "quid"                     # ② field name (sort)

q_name = fields.Char(string="Name") # field NAME=q_name (②) ; string="Name" = FREE TEXT label
service_id = fields.Many2one("qms.service")   # ① references ANOTHER model name
ticket_ids = fields.One2many("qms.ticket", "quid")  # ① model + ② inverse field name on qms.ticket
ticket_count = fields.Integer(compute="_compute_ticket_count")  # ④ METHOD name (string)

@api.depends("ticket_ids")          # ② field name(s) that trigger recompute
def _compute_ticket_count(self):    # ④ method DEFINITION (private "_" → NOT RPC-callable)
    for q in self: q.ticket_count = len(q.ticket_ids)

def create(self, vals_list):        # ④ public method → IS an RPC endpoint (call_kw)
    last = self.search([], order="quid desc", limit=1)  # ② field name in order
    ...
```

---

## 📄 WALKTHROUGH 3 — `controllers/main.py` (every string annotated)

```python
@http.route("/qms/book",            # ⑦ URL → registered in the routing map
            type="http",            # request type (http = returns HTML)
            auth="public",          # auth mode (public = anonymous allowed)
            website=True,           # website integration
            methods=["GET"])        # HTTP verb(s)
def qms_book_form(self, **kw):
    queues = request.env["qms.queue"].sudo().search([])   # ① model name → registry
    return request.render(
        "qms.qms_book_form",        # ⑥ TEMPLATE id → a qweb ir.ui.view (via ir_model_data)
        { "queues": queues,         # ⑧ CONTEXT VAR "queues" → used by t-foreach="queues"
          "error": kw.get("error")},#    "error" → used by t-if="error" in the template
    )
```
And in the template (`qms_public_templates.xml`):
```xml
<t t-call="website.layout">                 <!-- ⑥ template id REFERENCE → website addon -->
<t t-foreach="queues" t-as="queue">         <!-- ⑧ context var "queues" (from the dict above) -->
    <option t-att-value="queue.id">         <!-- queue.id → ② field on the looped record -->
<form action="/qms/book/submit" ...>        <!-- ⑦ URL → matches another @http.route -->
```

---

## 🧠 THE PREDICTION ALGORITHM (apply to any string)

```
  See a string in an Odoo file. Ask, in order:

  1. Is it dotted lowercase like "a.b"?          → ① MODEL NAME   (registry / ir_model)
  2. Is it inside name="..." on <field>,          → ② FIELD NAME   (the current model's fields)
     or in a domain/order/depends/group_by?
  3. Is it an id="..." or a ref="..."/action=/     → ③ XML-ID       (ir_model_data)
     parent_id/groups/search_view_id?
  4. Is it in compute=/ a button name=/ called     → ④ METHOD       (getattr on the model)
     via call_kw?
  5. Is it in widget="..."?                         → ⑤ WIDGET       (JS fields registry)
  6. Is it in t-call / request.render(...)?         → ⑥ TEMPLATE ID  (qweb view, ir_model_data)
  7. Does it start with "/"?                        → ⑦ URL          (routing map)
  8. Is it a t-foreach/t-if/t-esc variable?         → ⑧ CONTEXT VAR  (the render dict / scope)
  9. Is it list/form/kanban/search?                 → ⑨ VIEW TYPE    (views registry)
  else (string=, help=, a <field name="name"> label)→ FREE TEXT      (a label; references nothing)

  Then: "DEFINED by" + "Referenced by" come straight from the namespace's table row.
```

---

## ⚡ DIRECTION CHEAT (refers-TO vs referred-BY)

```
 _name="qms.queue"            ── is referred BY ──► views, actions, relations, env[...]
 <field name="model">qms.queue── refers TO ──────► the model _name
 id="action_qms_queue"        ── is referred BY ──► menus, ref=, search_view_id
 ref="view_qms_queue_search"  ── refers TO ──────► the id="view_qms_queue_search"
 compute="_compute_x"         ── refers TO ──────► def _compute_x on the same class
 request.render("qms.tmpl",{k})── refers TO ──────► template id "qms.tmpl"; k = vars for it
 @http.route("/x")            ── is referred BY ──► forms/links/menus that point to /x
```

---

## ✅ The takeaway

There is no mystery string in Odoo. Each one is in **exactly one namespace**, resolved by **exactly
one mechanism** (registry, `ir_model_data`, the model's fields, the routing map, a JS registry, or
the render scope). Memorize the **9 namespaces** + the **4 hubs** (model name, field name, XML-id,
URL), and you can trace any identifier in any `.xml`/`.py`/controller to both ends of its link.
```
```
