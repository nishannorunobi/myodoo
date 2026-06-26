# Odoo Core — The Remember Map

> One page to "grab all of Odoo." Everything below hangs off **ONE idea**. Learn the idea,
> and every feature becomes an obvious consequence of it.

---

## ⭐ THE ONE IDEA (memorize this first)

```
            EVERYTHING IS A RECORD,
        and ONE GENERIC ENGINE INTERPRETS RECORDS into a running app.

   You don't build an app. You DECLARE records (in files).
   Odoo stores them, and a generic ORM + generic web client RUN them.
```

From this single idea, everything else is a consequence:
- A **model** is a record (`ir_model`). A **view** is a record (`ir_ui_view`). A **menu**, an
  **action**, a **field**, even a **translation** — all rows in the database.
- Because the *app itself* is data, **one** web client can render **any** module without custom code.
- The developer's job = **write declarative data** + **a little Python logic**. Odoo does the rest.

---

## 🌳 THE CORE, AS A TREE (the mind-map)

```
                                   ODOO CORE
                                       │
        ┌───────────────┬──────────────┼───────────────┬───────────────┐
        ▼               ▼              ▼               ▼               ▼
   1. MODULES      2. DATA LAYER   3. LOGIC        4. PRESENTATION  5. ACCESS
   (packaging)     (ORM)           (behavior)      (views)         (routing+security)
        │               │              │               │               │
   __manifest__    models.Model    methods         QWeb (server)    controllers (@http.route)
   depends         fields.*        @api.depends     OWL  (client)    actions (window/client)
   data files      recordsets      compute          views: list/    menus (ir_ui_menu)
   assets bundles  env / cursor    constraints       form/kanban/…   groups + ir.model.access
   ir_model_data   search/read/    create/write     templates        record rules (row-level)
   (xml_id→id)     write/create    onchange         widgets/fields   auth (public/user)
```

Below each branch is "what Odoo takes care of for you" — that's the whole framework.

---

## 🔌 THE SPINE — the one through-line that connects everything

```
  FILES ──install──► REGISTRY (RAM) + DATABASE (rows) ──ORM──► RPC (JSON) ──► OWL ──► HTML
   .py/.xml           code+metadata    data+UI-config    serialize  string   compile  DOM

  Source of truth = REGISTRY (Python) + DATABASE (Postgres).  Everything else is a projection.
```

If you remember only one line, remember the spine. Every question ("how does X work?")
is just "where on the spine does X live?"

---

## 🧠 "HOW DOES ODOO TAKE CARE OF ___ ?" (the cheat-sheet)

| Concern | Odoo's mechanism | Lives where |
|---|---|---|
| **Define data** | `models.Model` + `fields.*` in a `.py` | registry (RAM) + DB columns |
| **Store data** | the ORM auto-creates/updates tables | PostgreSQL |
| **Query data** | `env[model].search(domain) / read / browse` | server (Python) |
| **Save data** | `create()` / `write()` (override for logic) | server → DB |
| **Derived values** | `compute=` + `@api.depends` (stored or not) | server (run on read) |
| **Rules/validation** | `models.Constraint` (SQL) + `@api.constrains` (Python) | server / DB |
| **Reactive form behavior** | `@api.onchange` | server, called per edit |
| **Build the UI** | declarative **views** (`<list>/<form>/<search>`) = records | DB (`ir_ui_view`) |
| **Render backend UI** | **OWL** compiles arch → DOM (client-side) | browser |
| **Render public pages/reports** | **QWeb** renders HTML (server-side) | server |
| **Navigate** | **menus** → **actions** (`act_window` / client action) | DB records |
| **Talk to server (data)** | **JSON-RPC** `call_kw` (`orm` service) | network |
| **Real-time push** | **WebSocket** bus (`bus.bus._sendone`) | network (:8072) |
| **Public web routes** | `@http.route(type="http")` controllers | server |
| **Who can see/do what** | **groups** + `ir.model.access` (CRUD) + **record rules** (rows) | DB, enforced by ORM |
| **Multi-company / multi-user** | the **environment** (`env`) carries user + context | server |
| **Translations** | `_t()` (JS) / `_()` (Python) + `.po` files | both |
| **Reports (PDF)** | QWeb report templates → wkhtmltopdf | server |
| **Wire it together** | shared **names** + **XML-ids** (`ir_model_data`) | DB |
| **Package & ship** | an **addon** with `__manifest__.py` | files → install |

> Read this table top-to-bottom once and you have seen *all* of Odoo's core responsibilities.

---

## 🗄️ THE META-TABLES (Odoo describing itself)

Odoo stores its **own structure** as data. These `ir_*` tables ARE the framework:

```
 ir_model            → "what models exist"        (qms.queue is a row here)
 ir_model_fields     → "what fields exist"        (q_name, quid… rows)
 ir_ui_view          → "the views"  (arch_db = your XML as TEXT)
 ir_ui_menu          → "the menus"
 ir_actions_act_window / ir_actions_client → "the actions"
 ir_model_data       → "xml_id → row id"  (the GLUE that links files & records)
 ir_model_access     → "group CRUD permissions"
 ir_rule             → "row-level record rules"
 ir_cron             → "scheduled jobs"
 ir_attachment       → "files/blobs + generated asset bundles"
```

**Insight:** when you "create a model/view/menu," you are **inserting rows into these tables.**
That is why a generic engine can run any app — it just reads these rows.

---

## 🔁 THE REQUEST LIFECYCLE (compact, the runtime loop)

```
 1. Browser sends HTTP  →  werkzeug  →  ir_http._dispatch       (routing by URL)
 2. Auth check (public/user) + session
 3a. type="http"  → controller returns HTML/file/redirect       (website pages, reports)
 3b. type="jsonrpc" /web/dataset/call_kw → call_kw(model,method) (backend data; RPC)
        └─ get_public_method (no leading "_") → getattr(model, method)
        └─ ORM runs: search/read/write/compute + SECURITY (ACL + record rules)
 4. Result serialized to JSON  →  back to browser
 5. OWL updates the reactive model → re-renders the DOM
 (parallel) WebSocket bus pushes live events when the server calls _sendone
```

---

## ✍️ DEVELOPER WRITES  →  WHAT IT BECOMES

```
 _name = "qms.queue"              → a model in registry + table qms_queue + ir_model row
 q_name = fields.Char()           → a column + ir_model_fields row + view metadata
 def create(self): ...            → business logic run on every insert
 <list><field name="q_name"/>     → ir_ui_view.arch_db (TEXT) → OWL component at runtime
 <record id="action_qms_queue">   → ir_actions_act_window row + ir_model_data('…')
 <menuitem action="…">            → ir_ui_menu row
 @http.route("/qms/book")         → a URL in the routing map → returns QWeb HTML
 "assets": {"web.assets_backend":…}→ your JS/CSS bundled into the page
 depends = ["base","website"]     → install order + available features
```

> **The whole craft of Odoo dev = choosing the right declarative record + a little Python.**

---

## 🧭 THE TWO RENDERING ENGINES (don't confuse them)

```
 SERVER-SIDE  (SSR)         CLIENT-SIDE (CSR)
 ─────────────────         ──────────────────
 Engine : QWeb (Python)    Engine : OWL (JavaScript, @odoo/owl)
 For    : website pages,   For    : the backend web client,
          reports, email            all backend views
 Output : HTML string       Output: live, reactive DOM
 Trigger: request.render()   Trigger: mountComponent()
 Same t-esc/t-if/t-foreach syntax — but QWeb runs ONCE on the server,
 OWL runs reactively in the browser (and has t-on-click events).
```

---

## 🌐 THE THREE WAYS BROWSER ↔ SERVER TALK (chosen by NEED, not by UI)

```
 NEED a full page      →  plain HTTP GET/POST   →  server-rendered HTML   (website)
 NEED data on demand   →  JSON-RPC (call_kw)    →  request/response       (backend + website)
 NEED a live push      →  WebSocket (bus)       →  server → browser       (Discuss, livechat)

 NOT REST. Odoo is RPC ("call a method on a model"), not resource URLs.
```

---

## 🎯 THE MNEMONIC (carry this in your head)

> **"Declare records, ORM serves them, one client renders them."**

Or the spine:

> **Files → Registry + DB → ORM → RPC → OWL → DOM.**

Everything in Odoo is one of:
1. a **record** you declared (model/view/menu/action),
2. a bit of **Python logic** on a model,
3. the **generic engine** (ORM + web client) that interprets 1 and runs 2.

When confused, ask: *"Is this a record, logic, or the engine? And where on the spine does it live —
registry, DB, network, or browser?"* That question answers almost everything.

---

## 📚 Companion doc

See `odoo_rendering_pipeline.md` (same folder) for the **deep, file:line-grounded trace** of how
one `<field>` becomes an HTML `<td>` — the detailed version of "the spine."
```
```
