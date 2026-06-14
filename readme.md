# myodoo

Odoo **Community** edition for building a company website + eCommerce store.
Runs as a single `odoo` container that **reuses the existing PostgreSQL container**
(`mypostgresql_db-container`) over the shared `ums-network` Docker network.

## Architecture

```
┌─────────────────┐         ums-network          ┌──────────────────────────┐
│  myodoo-app     │ ───────────────────────────► │ mypostgresql_db-container │
│  (odoo:17)      │   db_host=mypostgresql_db     │   (postgres:16)           │
│  :8069 web      │   db_user=odoo                │   role: odoo (CREATEDB)   │
│  :8072 longpoll │                               │   db: myodoo              │
└─────────────────┘                               └──────────────────────────┘
```

- No second Postgres container — one cluster to run and back up.
- Odoo creates its **own** database (`myodoo`) in that cluster; it never touches the UMS tables.
- `dbfilter = ^myodoo.*$` in `config/odoo.conf` keeps the UMS DB out of Odoo's database manager.

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | The `odoo` service; attaches to external `ums-network` |
| `.env` | Odoo version + host ports (DB creds reference only) |
| `config/odoo.conf` | Server config — **DB credentials live here** (single source of truth) |
| `addons/` | Drop custom / OCA modules here (mounted at `/mnt/extra-addons`) |
| `start.sh` / `stop.sh` | Bring the stack up / down (data preserved on stop) |
| `status.sh` / `logs.sh` / `health.sh` | Status, tail logs, liveness check |
| `destroy.sh` | Stop + delete the Odoo filestore volume (does NOT drop the DB) |

## First-time setup

### 1. Create the Odoo Postgres role + database (one-time)

All DB operations are scripted under `mypostgresql_db/myodoo/` (same pattern as
`umsdb` / `mydocsdb`). Run inside the Postgres container:

```bash
docker exec -it mypostgresql_db-container bash -lc \
  '/mypostgresql_db/myodoo/scripts/startdb.sh --prepare-only'
```

This creates the `odoo` role **with `CREATEDB`**, the `myodoo` database (owned by
`odoo`), and the `unaccent` extension. Credentials live in
`mypostgresql_db/myodoo/.env` and must match `config/odoo.conf`.

- Prefer Odoo's web "Create Database" wizard instead? Run with `--role-only` and
  let Odoo create the DB itself (name it `myodoo` to match the `dbfilter`).
- Other ops: `scripts/connect.sh` (psql shell), `scripts/reset_db.sh` (drop +
  recreate), `scripts/cleandb.sh` (drop role + DB).

### 2. Allow the connection in `pg_hba.conf`

Odoo connects from another container over `ums-network` (not localhost), so the
Postgres cluster must accept that. Ensure `pg_hba.conf` has a line allowing the
Docker subnet, e.g.:

```
host    all    odoo    172.16.0.0/12    scram-sha-256
```

Reload Postgres after editing: `docker exec mypostgresql_db-container pg_ctl reload`
(or `SELECT pg_reload_conf();`).

### 3. Start Odoo

```bash
./start.sh
```

Then open **http://localhost:8069**:
- Create the database (name it `myodoo` to match `dbfilter`), set the admin login/password.
- Go to **Apps** and install **Website** and **eCommerce**.
- Build the store: pick a theme, add products, set a payment method (manual/wire
  transfer is free) and a shipping method (flat rate is free).

## Daily use

```bash
./start.sh     # start
./status.sh    # is it up?
./logs.sh      # tail logs
./stop.sh      # stop (DB + filestore preserved)
```

## Notes

- **Backups:** add the `myodoo` database to the db-agent backup list in
  `mypostgresql_db` so it's covered alongside UMS.
- **Logs:** Odoo writes to `mountspace/logs/myworkspace/projectspace/myodoo/odoo_log.log`
  (mirror-logging convention; Promtail → Loki → Grafana picks it up).
- **Security:** change `admin_passwd` in `config/odoo.conf` and the DB password
  before exposing this beyond localhost.
- **Prereq:** the Postgres project must be started first (it creates `ums-network`
  and runs the DB). `start.sh` checks for both and exits with guidance if missing.
