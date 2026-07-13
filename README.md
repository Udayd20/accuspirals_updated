# ACCUSPIRALS — Tool & Consumables Inventory (Full Stack)

A complete inventory system for gear-cutting tools, in three parts that share one PostgreSQL database:

```
accuspirals/
├── db/         PostgreSQL schema + seed data
├── backend/    NestJS + TypeORM REST API
├── web/        XP-style HTML/JS app (with dark/light mode)
└── flutter/    Flutter app for all 10 screens (with dark/light mode)
```

The taxonomy and the **dynamic cutting-spec forms** (fields load by Tool Family + Subtype) come from the client's *Master Cutting Tool Specifications* document.

---

## 1. Database (PostgreSQL)

```bash
createdb accuspirals
psql -d accuspirals -f db/schema.sql
```

This creates all tables and seeds families, subtypes, dynamic spec fields (Hob / Worm / Broach fully seeded — extend `spec_field_def` for the rest), master data, users, and a few sample tools.

---

## 2. Backend (NestJS + TypeORM)

```bash
cd backend
cp .env.example .env        # edit DB_USER / DB_PASS if needed
npm install
npm run start:dev
# → API on http://localhost:3000/api
```

Key endpoints: `GET /families`, `GET /tools`, `GET /tools/:code`, `POST /tools`,
`POST /tools/:code/issue|return`, `GET /tools/regrind/jobs`, `POST /gate`, `GET /qc`,
`POST /qc/:id/accept|reject`, `GET /dashboard`, `GET /reports`,
`GET/POST/DELETE /admin/master`, `/admin/users`, `POST /admin/categories`.

`synchronize` is **off** — the schema is owned by `db/schema.sql` (safer for production).

---

## 3. Web app (HTML/XP)

Just open `web/index.html` in a browser — no build step. It currently runs on its own
in-memory data for demo/among-screens flow, and has a **Dark mode / Light mode** toggle in
the toolbar. (To point it at the live API instead of in-memory data, replace the JS data
layer with `fetch()` calls to the backend — the endpoints above match its actions.)

---

## 4. Flutter app

```bash
cd flutter
flutter pub get
flutter run          # choose a device / chrome / windows / macos
```

- All 10 screens are in `lib/screens/screens.dart`, navigable from the rail/drawer.
- **Dark/light** toggle is the moon/sun icon in the AppBar.
- API base is in `lib/api.dart` (`Api.base`). Use `http://localhost:3000/api` for
  web/desktop/iOS simulator, or **`http://10.0.2.2:3000/api`** for the Android emulator.

---

## What's fully wired vs. scaffolded

| Area | State |
|---|---|
| PostgreSQL schema + seed | Complete |
| Backend: all core endpoints | Complete (extend `spec_field_def` rows for full per-family field coverage) |
| Web app screens + dark mode | Complete (in-memory data; swap to API when ready) |
| Flutter: all 10 screens + dark mode + API calls | Complete; not compiled in this environment, so run `flutter pub get` and fix any version nits |

Because Flutter/NestJS can't be compiled here, expect minor `pub get` / `npm install`
adjustments on first run. Nothing uses external secrets.

## Suggested next steps
1. Seed `spec_field_def` for every family/subtype from the master spec doc.
2. Point the web app at the live API (replace in-memory layer with `fetch`).
3. Add authentication + role/permission enforcement (cost visibility, scrap approval).
4. QR / barcode scan for issue & return.
5. Report export (PDF / Excel).
