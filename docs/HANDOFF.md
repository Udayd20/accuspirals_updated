# ACCUSPIRALS Tool & Consumables Inventory — Handoff

**What it is:** Inventory system for ACCUSPIRALS (gear-cutting-tool maker, Peenya/Bangalore).
Stack: **PostgreSQL 14 + NestJS (Node) backend + XP-styled HTML/JS web app + Flutter app (outdated)**.
Runs locally on Ubuntu 22.04 at `~/TOOL_INVENTORY/accuspirals/`.

## Run (daily)
```bash
cd ~/TOOL_INVENTORY/accuspirals/backend && npm run start:dev
```
Then open **http://localhost:3000/** (backend serves the web app too). Login: `ADMIN01` / `accuspirals`.

## Run (after re-unzipping a new build)
```bash
cd ~/TOOL_INVENTORY && rm -rf accuspirals && unzip -o accuspirals-project.zip -d accuspirals
cd accuspirals && sudo -u postgres psql -d accuspirals < db/schema.sql
cd backend && npm install && npm run start:dev
```
- `rm -rf` deletes `node_modules`, so **`npm install` is required after every re-unzip**.
- Schema reload **resets data to seed**.
- Port busy: `kill -9 $(sudo lsof -t -i :3000)`.

## Default logins (all password `accuspirals`)
- `ADMIN01` — Admin
- `EMP102` — Gate staff
- `EMP087` — Inventory staff

Startup prints a SECURITY warning until these are reset (Admin → Users & Roles → Reset password).

## Features built (working, web-tested)
- **Auth & security:** password login (scrypt-hashed); token required on every API call (401 without); admin-only endpoints (403 for others); role tied to account. `AUTH_SECRET` auto-generates to `backend/.auth-secret`. Escape hatch: `AUTH_ENABLED=false` in `backend/.env` disables all auth.
- **Admin permissions matrix** (roles x 10 screens); access driven by login. Defaults: Gate staff -> Gate Entry only; Inventory staff -> QC/Tools/Detail/Issue/Return/Regrind; Admin -> all.
- **Admin Category Specifications manager:** add/delete spec fields per family/type; **dual-unit Module/DP** field type. Research-seeded defaults + type-specific fields across all 10 families incl. 13 hob types.
- **Gate Entry:** dynamic specs by category; invoice capture + photo; drafts; **per-line Edit**; Tool-name removed (auto-derived); **Manufacturer = supplier dropdown** with "Other -> admin approves once" (deduped).
- **Pending QC:** supplier column; inspect/accept; add-to-QC / add-existing.
- **Tools & Details:** filters; spec-search; **Movement & timing** (issued-by, issue date, timestamps, **issued-from unit/shelf**).
- **Issue** (multi-select, issued-by, issue date) / **Return** (shows full spec + who issued it) / **Regrind**.
- **UX:** full-height layout; dark mode; live clock; **searchable dropdowns**; **Delete buttons + confirmation popups** (replaced x icons); HTTPS support via `backend/gen-cert.sh`.

## Open items / gaps
- **Flutter app is well behind the web app** — no login, so it hits 401s against the secured backend. To demo now: set `AUTH_ENABLED=false`. **Recommended next task: rebuild Flutter to match web (with login).**
- Still HTTP on LAN (fine locally; run `backend/gen-cert.sh <LAN-IP>` for HTTPS if other machines connect).
- Not yet done: split "issued-from" into structured **unit + shelf**; Reports PDF/Excel are demo stubs; Return "received by" hardcoded EMP087; reset the 3 default passwords + set a real `AUTH_SECRET`.
- **Caveat:** web is automated-tested (Playwright); backend verified by inspection + live testing on the shop PC.

## Environment note for the assistant
Cannot run Postgres/Node/Flutter in-session — backend changes are inspection-only; web is Playwright-tested. Always take the rigorous/reproducible approach (config-driven, pinned versions/hashes, no shortcuts).

## Project layout
```
db/schema.sql            PostgreSQL schema + seed (drops+recreates on load)
backend/src/*.ts         NestJS: app, main, entities, auth, catalog, tools, receiving, admin, dashboard
backend/gen-cert.sh      self-signed TLS cert generator (optional HTTPS)
backend/.env.example     DB + AUTH_SECRET + AUTH_ENABLED
web/index.html           the web app (served by backend at / ; also opens standalone)
flutter/                 Flutter app (outdated; lib/ + pubspec only until `flutter create .`)
```
