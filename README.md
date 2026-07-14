# ACCUSPIRALS — Tool & Consumables Inventory

A full-stack inventory system for gear-cutting tools (hobs, worms, broaches, shaper cutters, milling cutters, and consumables). It tracks a tool's entire lifecycle — gate receipt → inventory QC → storage → issue → return → regrind/repair → scrap — with **dynamic cutting-spec forms** whose fields change by Tool Family and Subtype.

The system has four parts that all share one PostgreSQL database:

```
accuspirals/
├── db/         PostgreSQL schema + seed data (schema.sql)
├── backend/    NestJS + TypeORM REST API   (serves the web app too)
├── web/        XP-style HTML/JS single-page app  (dark/light mode)
└── flutter/    Flutter client — same 10 screens, full parity with the web app
```

- **Backend** exposes a REST API at `http://localhost:3000/api` and also serves the web app at `http://localhost:3000/`.
- **Web app** and **Flutter app** are two independent clients that talk to the same API and behave identically (same screens, auth, permissions, dynamic spec fields).

---

## Contents

1. [Prerequisites](#1-prerequisites)
2. [Quick start (TL;DR)](#2-quick-start-tldr)
3. [Step 1 — Database (PostgreSQL)](#3-step-1--database-postgresql)
4. [Step 2 — Backend (NestJS API)](#4-step-2--backend-nestjs-api)
5. [Step 3 — Web app](#5-step-3--web-app)
6. [Step 4 — Flutter app](#6-step-4--flutter-app)
7. [Logins, roles & permissions](#7-logins-roles--permissions)
8. [Authentication & security notes](#8-authentication--security-notes)
9. [The 10 screens](#9-the-10-screens)
10. [Project structure](#10-project-structure)
11. [Troubleshooting](#11-troubleshooting)
12. [Known limitations](#12-known-limitations)
13. [Push to GitHub](#13-push-to-github)

---

## 1. Prerequisites

| Tool | Version | Check with |
|------|---------|-----------|
| PostgreSQL | 14+ | `psql --version` |
| Node.js | 18+ (LTS) | `node -v` |
| npm | 9+ | `npm -v` |
| Flutter SDK | 3.0+ (Dart 3.0+) | `flutter --version` |

Install the Flutter desktop/web/mobile toolchain as needed. Run `flutter doctor` and fix anything it flags for your target platform.

---

## 2. Quick start (TL;DR)

Three terminals, from the project root (`accuspirals/`):

```bash
# --- Terminal 1: database (once) ---
createdb accuspirals
psql -d accuspirals -f db/schema.sql

# --- Terminal 2: backend (leave running) ---
cd backend
cp .env.example .env          # edit DB_USER / DB_PASS if your Postgres differs
npm install
npm run start:dev             # API on http://localhost:3000/api
                              # web app on http://localhost:3000/

# --- Terminal 3: Flutter app ---
cd flutter
flutter pub get
flutter run -d linux          # or: -d chrome / -d windows / -d macos / -d <device>
```

Then log in with **`ADMIN01`** / **`accuspirals`** (see [logins](#7-logins-roles--permissions)).

---

## 3. Step 1 — Database (PostgreSQL)

```bash
createdb accuspirals
psql -d accuspirals -f db/schema.sql
```

This creates every table and seeds:

- Tool **families**, **subtypes**, and **dynamic spec-field definitions** (Hob / Worm / Broach are fully seeded; extend `spec_field_def` for the others, or add them live in **Admin ▸ Category specifications**).
- **Master data** — units, machines, employees, suppliers, storage locations.
- **Users** and **role permissions**.
- A few **sample tools** so the screens aren't empty on first run.

If your Postgres uses a non-default role/password, either create the matching role or set `DB_USER` / `DB_PASS` in the backend `.env` (next step). To start over:

```bash
dropdb accuspirals && createdb accuspirals && psql -d accuspirals -f db/schema.sql
```

> `synchronize` is **off** in TypeORM — the schema is owned by `db/schema.sql` (safer; the API never silently alters your tables).

---

## 4. Step 2 — Backend (NestJS API)

```bash
cd backend
cp .env.example .env
npm install
npm run start:dev     # watch mode (auto-restart on change)
# or: npm run start   # single run
# or: npm run build && npm run start:prod   # compiled production build
```

You should see:

```
ACCUSPIRALS API running on http://localhost:3000/api
ACCUSPIRALS web app served at http://localhost:3000/
```

### `.env` settings

```ini
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASS=postgres
DB_NAME=accuspirals
PORT=3000

AUTH_SECRET=change-me-to-a-long-random-string   # see security notes
AUTH_ENABLED=true                               # set false only to recover from a lockout
```

### Main endpoints (all prefixed with `/api`)

```
POST /auth/login                       { userId, password } → { ok, token, user }
GET  /families
GET  /tools?q=&status=&category=       GET /tools/:code       POST /tools
POST /tools/:code/issue                POST /tools/:code/return
GET  /tools/regrind/jobs               POST /tools/:code/regrind/receive   DELETE /tools/:code
POST /gate                             GET  /qc
POST /qc/:id/accept | reject | update
GET  /dashboard                        GET  /reports          GET /events
GET/POST/DELETE  /admin/master         /admin/users           POST /admin/categories
GET/POST         /admin/permissions    GET/POST/DELETE /admin/spec-fields
```

Every non-login request must carry `Authorization: Bearer <token>`. Both clients do this automatically after login.

---

## 5. Step 3 — Web app

The backend serves the web app, so the simplest path is:

1. Start the backend (Step 2).
2. Open **`http://localhost:3000/`** in a browser.

Because the page and the API share one origin, there are no CORS or mixed-content issues. Log in with any seeded account.

To reach it from another machine on the LAN, open `http://<server-lan-ip>:3000/`.

---

## 6. Step 4 — Flutter app

```bash
cd flutter
flutter pub get
flutter run -d linux        # pick your target (see below)
```

### Choose a target device

```bash
flutter devices             # list what's available
flutter run -d chrome       # web
flutter run -d linux        # Linux desktop
flutter run -d windows      # Windows desktop
flutter run -d macos        # macOS desktop
flutter run -d <deviceId>   # a connected phone / emulator
```

### Set the API base URL per platform

Open **`flutter/lib/api.dart`** and set the `base` constant to match where the backend is reachable **from the app's point of view**:

| Running the app on… | `base` value |
|---|---|
| Linux / Windows / macOS desktop | `http://localhost:3000/api` |
| Chrome (web) | `http://localhost:3000/api` |
| **Android emulator** | `http://10.0.2.2:3000/api` |
| **iOS simulator** | `http://localhost:3000/api` |
| **Physical phone (same Wi-Fi)** | `http://<your-computer-LAN-ip>:3000/api` |

`localhost` inside an Android emulator points at the emulator itself, which is why it needs `10.0.2.2`. For a physical device, find your computer's LAN IP (`ip a` / `ifconfig` / `ipconfig`) and make sure both are on the same network.

---

## 7. Logins, roles & permissions

All seeded accounts share the default password **`accuspirals`** on first run (see security notes to change them).

| Employee ID | Password | Role | Sees |
|---|---|---|---|
| `ADMIN01` | `accuspirals` | Admin | All 10 screens |
| `EMP102` | `accuspirals` | Gate staff | Gate Entry |
| `EMP087` | `accuspirals` | Inventory staff | QC, Tools, Detail, Issue, Return, Regrind |

Permissions are editable at runtime in **Admin ▸ Role permissions**; changes take effect the next time a user logs in.

---

## 8. Authentication & security notes

- **Password hashing** — passwords are stored as salted **scrypt** hashes (Node built-in, no external deps).
- **Tokens** — login returns an HMAC-SHA256 signed token (JWT-like), signed with `AUTH_SECRET`.
- **AUTH_SECRET** — if left as the placeholder, the backend auto-generates a strong random secret on first run and saves it to `backend/.auth-secret` so tokens survive restarts. For production, set your own long random string.
- **Default password warning** — on startup the backend logs which accounts still use `accuspirals`. Reset them in **Admin ▸ Users ▸ Reset password**.
- **AUTH_ENABLED=false** — a recovery escape hatch that disables auth entirely. Use only if you're locked out; set it back to `true` immediately after.
- **Optional HTTPS** — drop `server.key` + `server.crt` into `backend/certs/` and the API + web app serve over TLS automatically.

`backend/.env` and `backend/.auth-secret` are secrets — they're git-ignored (see `.gitignore`) and must **not** be committed.

---

## 9. The 10 screens

Both clients implement the same ten screens:

1. **Dashboard** — status cards, recent activity, and items needing attention.
2. **Gate Entry** — log an incoming delivery: invoice header + line items with dynamic spec, then send to QC.
3. **Inventory QC** — verify against invoice; accept (with partial quantities and ID generation), hold, or reject.
4. **Tools & Consumables** — searchable/filterable master list (category, status, location, employee, free-text incl. spec).
5. **Tool Details** — full identity, spec, commercial/lifecycle, movement & timing, and complete event timeline.
6. **Issue** — multi-select available tools and issue them to an employee/unit/machine/work-order.
7. **Return** — pick an issued tool and decide: reuse, regrind, repair, or scrap.
8. **Regrind / Repair** — track service jobs and receive them back (QC pass → available, fail → scrap).
9. **Reports** — inventory value, lifecycle cost, scrap value; breakdowns by category and by unit; demo export.
10. **Admin** — categories, spec-field manager, role permissions, users, master data, and supplier requests.

---

## 10. Project structure

```
accuspirals/
├── README.md
├── .gitignore
├── db/
│   └── schema.sql              # tables + seed data
├── backend/
│   ├── .env.example            # copy to .env
│   ├── package.json
│   └── src/
│       ├── main.ts             # bootstrap, CORS, /api prefix, serves web/
│       ├── app.module.ts
│       ├── auth.module.ts      # login, scrypt, token signing, guards
│       ├── entities.ts         # TypeORM entities
│       ├── catalog.module.ts   # /families
│       ├── receiving.module.ts # /gate, /qc
│       ├── tools.module.ts     # /tools ...
│       ├── dashboard.module.ts # /dashboard, /reports, /events
│       └── admin.module.ts     # /admin ...
├── web/
│   └── index.html              # XP-style SPA (served at :3000/)
├── flutter/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart           # shell: title bar, toolbar, sidebar, footer
│       ├── api.dart            # REST client (set `base` here)
│       ├── state.dart          # Session + AppData + AppNav (Provider)
│       ├── theme.dart          # XP light/dark theming
│       ├── widgets.dart        # shared XP widgets
│       └── screens/            # login, dashboard, gate, qc, tools, detail,
│                               # issue, returns, regrind, reports, admin, add_tool
└── docs/
    └── HANDOFF.md
```

---

## 11. Troubleshooting

**Login fails / "is the API running?" toast (Flutter)**
The backend isn't reachable at `api.dart`'s `base`. Confirm the backend terminal shows it's running, and that `base` matches your platform (see the table in Step 4). Test the API directly:
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"userId":"ADMIN01","password":"accuspirals"}'
```
You should get `{"ok":true,"token":"...","user":{...}}`.

**Backend won't start — DB connection error**
Check Postgres is running and `.env` credentials/`DB_NAME` are correct. Re-run the schema step if the database is empty.

**Android emulator can't reach the API**
Use `http://10.0.2.2:3000/api`, not `localhost`.

**Physical phone can't reach the API**
Use your computer's LAN IP, ensure both devices are on the same Wi-Fi, and that a firewall isn't blocking port 3000.

**Locked out of all accounts**
Set `AUTH_ENABLED=false` in `.env`, restart, fix users in Admin, then set it back to `true`.

**Flutter version note about `intl 0.19.0`**
Harmless — a newer version exists but the pinned one is fine. Not an error.

---

## 12. Known limitations

- **Invoice photo** on Gate Entry is a stub button (wiring it up needs the `image_picker` package).
- **Master-data deletes** in Admin are client-side only (they reappear on reload) — this mirrors the web app's current behavior. Adds do persist via the API.

---

## 13. Push to GitHub

From the project root (`accuspirals/`), with `README.md` and `.gitignore` in place:

```bash
cd ~/TOOL_INVENTORY/accuspirals

git init
git add .
git commit -m "ACCUSPIRALS: full-stack inventory (DB + NestJS API + web + Flutter)"
git branch -M main
```

Create an empty repo on GitHub (no README/license, to avoid conflicts), then:

```bash
git remote add origin https://github.com/<your-username>/accuspirals.git
git push -u origin main
```

If you prefer the GitHub CLI:

```bash
gh repo create accuspirals --private --source=. --remote=origin --push
```

> Make sure `backend/.env`, `backend/.auth-secret`, `node_modules/`, and Flutter build folders are **not** committed — the included `.gitignore` handles this. Verify with `git status` before your first commit.
