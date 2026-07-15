-- ============================================================
-- ACCUSPIRALS Tool & Consumables Inventory — PostgreSQL schema
-- ============================================================
-- Design notes:
--  * tool_family + tool_subtype model the taxonomy from the client's
--    "Master Cutting Tool Specifications" document.
--  * spec_field_def stores the DYNAMIC form fields per family/subtype
--    (so forms load only relevant cutting specs — no universal form).
--  * tool stores physical, individually-tracked instances; captured
--    cutting-spec values live in tool.spec (JSONB) validated against
--    spec_field_def.
--  * event is an append-only timeline powering tool history + dashboard.
-- ============================================================

DROP TABLE IF EXISTS event, qc_queue, gate_line, gate_entry, stock,
  tool, spec_field_def, tool_subtype, tool_family,
  master_data, app_user, role_perm CASCADE;

-- ---------- taxonomy ----------
CREATE TABLE tool_family (
  id            SERIAL PRIMARY KEY,
  name          TEXT UNIQUE NOT NULL,
  id_prefix     TEXT NOT NULL,               -- e.g. GT-HOB
  tracking      TEXT NOT NULL DEFAULT 'individual'
                 CHECK (tracking IN ('individual','quantity','batch')),
  seq           INT  NOT NULL DEFAULT 0      -- running counter for ID generation
);

CREATE TABLE tool_subtype (
  id            SERIAL PRIMARY KEY,
  family_id     INT NOT NULL REFERENCES tool_family(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  UNIQUE(family_id, name)
);

-- Dynamic cutting-spec field definitions (drives the Add Tool form).
-- subtype_id NULL = applies to whole family; otherwise subtype-specific.
CREATE TABLE spec_field_def (
  id            SERIAL PRIMARY KEY,
  family_id     INT NOT NULL REFERENCES tool_family(id) ON DELETE CASCADE,
  subtype_id    INT REFERENCES tool_subtype(id) ON DELETE CASCADE,
  label         TEXT NOT NULL,
  input_type    TEXT NOT NULL DEFAULT 'text'  -- text | number | select | dualunit
                 CHECK (input_type IN ('text','number','select','dualunit')),
  unit          TEXT,                          -- mm, °, DP, ...
  options       JSONB,                         -- for select: ["RH","LH"]
  mandatory     BOOLEAN NOT NULL DEFAULT false,
  sort_order    INT NOT NULL DEFAULT 0
);

-- ---------- physical inventory ----------
CREATE TABLE tool (
  id            SERIAL PRIMARY KEY,
  code          TEXT UNIQUE NOT NULL,          -- GT-HOB-000124
  family_id     INT REFERENCES tool_family(id),
  subtype_id    INT REFERENCES tool_subtype(id),
  category      TEXT NOT NULL,                 -- "Hob Cutter ▸ Standard"
  name          TEXT NOT NULL,
  manufacturer  TEXT,
  supplier_code TEXT,
  material      TEXT,
  cost          NUMERIC(12,2) NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'AVAILABLE'
                 CHECK (status IN ('AVAILABLE','ISSUED','REGRINDING','REPAIR',
                                   'SCRAP','REJECTED','HOLD')),
  location      TEXT,
  unit          TEXT,
  issued_to     TEXT,
  machine       TEXT,
  work_order    TEXT,
  expected_return DATE,
  issued_by     TEXT,
  issued_date   DATE,
  issued_at     TIMESTAMPTZ,
  returned_at   TIMESTAMPTZ,
  issued_from   TEXT,
  condition     TEXT DEFAULT 'Good',
  regrind_cost  NUMERIC(12,2) NOT NULL DEFAULT 0,
  times_issued  INT NOT NULL DEFAULT 0,
  times_reground INT NOT NULL DEFAULT 0,
  spec          JSONB NOT NULL DEFAULT '{}',   -- captured dynamic cutting spec
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_tool_status ON tool(status);
CREATE INDEX idx_tool_family ON tool(family_id);

-- quantity-tracked consumables
CREATE TABLE stock (
  id            SERIAL PRIMARY KEY,
  category      TEXT NOT NULL,
  name          TEXT NOT NULL,
  qty           INT NOT NULL DEFAULT 0,
  cost          NUMERIC(12,2) NOT NULL DEFAULT 0,
  location      TEXT
);

-- ---------- receiving ----------
CREATE TABLE gate_entry (
  id            SERIAL PRIMARY KEY,
  gate_no       TEXT UNIQUE NOT NULL,          -- GE-2026-0418
  supplier      TEXT,
  received_by   TEXT,
  invoice_no    TEXT,
  invoice_date  DATE,
  invoice_value NUMERIC(12,2) DEFAULT 0,
  invoice_photo TEXT,                          -- base64 data URL (prototype)
  unit          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE gate_line (
  id            SERIAL PRIMARY KEY,
  gate_id       INT NOT NULL REFERENCES gate_entry(id) ON DELETE CASCADE,
  category      TEXT, name TEXT, manufacturer TEXT,
  qty           INT DEFAULT 1, cost NUMERIC(12,2) DEFAULT 0,
  condition     TEXT, gate_qc TEXT              -- Pass | Hold | Reject
);

CREATE TABLE qc_queue (
  id            SERIAL PRIMARY KEY,
  gate_no       TEXT, category TEXT, name TEXT, manufacturer TEXT,
  qty           INT DEFAULT 1, cost NUMERIC(12,2) DEFAULT 0, condition TEXT,
  spec          JSONB NOT NULL DEFAULT '{}',
  supplier      TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- timeline ----------
CREATE TABLE event (
  id            SERIAL PRIMARY KEY,
  tool_code     TEXT,                          -- may be '—' for non-tool events
  type          TEXT NOT NULL,                 -- gate|qc|accept|store|issue|return|regrind|scrap|admin
  text          TEXT NOT NULL,
  ts            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_event_code ON event(tool_code);

-- ---------- master + users ----------
CREATE TABLE master_data (
  id            SERIAL PRIMARY KEY,
  kind          TEXT NOT NULL,                 -- units|machines|employees|suppliers|locations
  value         TEXT NOT NULL,
  UNIQUE(kind, value)
);

CREATE TABLE app_user (
  id            SERIAL PRIMARY KEY,
  user_id       TEXT UNIQUE NOT NULL,
  name          TEXT,
  role          TEXT NOT NULL CHECK (role IN ('Admin','Gate staff','Inventory staff')),
  scope         TEXT NOT NULL DEFAULT '',
  password_hash TEXT
);

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO tool_family (name, id_prefix, tracking, seq) VALUES
 ('Hob Cutter','GT-HOB','individual',131),
 ('Gear Shaper — Disc','GT-SHD','individual',31),
 ('Gear Shaper — Shank','GT-SHS','individual',0),
 ('Broaching Tool','GT-BRC','individual',9),
 ('Thread Milling Cutter','GT-TMC','individual',21),
 ('Thread Whirling Insert','GT-TWI','individual',0),
 ('Worm Hob','GT-WRM','individual',7),
 ('Straight Bevel Tool','GT-SBV','individual',0),
 ('Spiral Bevel Tool','GT-SPB','individual',0),
 ('Other Consumables','CONS','quantity',0);

-- subtypes
INSERT INTO tool_subtype (family_id, name)
SELECT f.id, s.name FROM tool_family f JOIN (VALUES
 ('Hob Cutter','Finisher Hob'),
 ('Hob Cutter','Roughing Hob'),
 ('Hob Cutter','Semi-Finisher Hob'),
 ('Hob Cutter','PG Hob (Protuberance)'),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)'),
 ('Hob Cutter','Worm Hob'),
 ('Hob Cutter','Sprocket Hob'),
 ('Hob Cutter','Timing Pulley Hob'),
 ('Hob Cutter','Module Hob'),
 ('Hob Cutter','DP Hob'),
 ('Hob Cutter','Spline Hob'),
 ('Hob Cutter','Serration Hob'),
 ('Hob Cutter','Special Profile Hob'),
 ('Gear Shaper — Disc','Spur'),
 ('Gear Shaper — Disc','Helical'),
 ('Gear Shaper — Shank','Spur'),
 ('Gear Shaper — Shank','Helical'),
 ('Broaching Tool','Spline'),
 ('Broaching Tool','Keyway'),
 ('Broaching Tool','Square'),
 ('Broaching Tool','D-Type'),
 ('Broaching Tool','Helical'),
 ('Broaching Tool','Miscellaneous'),
 ('Thread Milling Cutter','Single-Form'),
 ('Thread Milling Cutter','Multi-Form'),
 ('Thread Whirling Insert','Full'),
 ('Thread Whirling Insert','Partial'),
 ('Thread Whirling Insert','Custom Profile'),
 ('Worm Hob','ZA'),
 ('Worm Hob','ZN'),
 ('Worm Hob','ZI'),
 ('Worm Hob','ZK'),
 ('Worm Hob','ZC'),
 ('Worm Hob','Custom'),
 ('Straight Bevel Tool','Two-Blade'),
 ('Straight Bevel Tool','CONIFLEX-type'),
 ('Spiral Bevel Tool','Face Hobbing / Spiral Hob'),
 ('Spiral Bevel Tool','Solid / Full-Body Cutter'),
 ('Spiral Bevel Tool','Cutter Head'),
 ('Spiral Bevel Tool','Cutter Blades')
) AS s(fam,name) ON f.name = s.fam;

-- dynamic spec fields (Hob Cutter shown fully; others summarised — extend as needed)
INSERT INTO spec_field_def (family_id, label, input_type, unit, options, sort_order)
SELECT f.id, d.label, d.itype, d.unit, CASE WHEN d.opts='' THEN NULL ELSE d.opts::jsonb END, d.so
FROM tool_family f JOIN (VALUES
 ('Hob Cutter','Module / DP','dualunit','','["Module (mm)", "DP (per inch)"]',1),
 ('Hob Cutter','Pressure Angle','number','°','',2),
 ('Hob Cutter','Bore / ID','number','mm','',3),
 ('Hob Cutter','Outside Diameter (OD)','number','mm','',4),
 ('Hob Cutter','Overall Length','number','mm','',5),
 ('Hob Cutter','Number of Starts','number','','',6),
 ('Hob Cutter','Number of Gashes','number','','',7),
 ('Hob Cutter','Hand','select','','["RH", "LH"]',8),
 ('Hob Cutter','Class','select','','["AA", "AAA"]',9),
 ('Hob Cutter','Material','select','','["HSS", "PM-HSS", "Carbide"]',10),
 ('Hob Cutter','Coating','select','','["Uncoated", "TiN", "TiCN", "TiAlN", "AlCrN", "AlTiN"]',11),
 ('Gear Shaper — Disc','Module / DP','dualunit','','["Module (mm)", "DP (per inch)"]',1),
 ('Gear Shaper — Disc','Pressure Angle','number','°','',2),
 ('Gear Shaper — Disc','Number of Teeth on Cutter','number','','',3),
 ('Gear Shaper — Disc','Pitch Diameter','number','mm','',4),
 ('Gear Shaper — Disc','Bore / ID','number','mm','',5),
 ('Gear Shaper — Disc','Outside Diameter','number','mm','',6),
 ('Gear Shaper — Disc','Face Width / Thickness','number','mm','',7),
 ('Gear Shaper — Disc','Hand','select','','["RH", "LH", "Straight"]',8),
 ('Gear Shaper — Disc','Class','select','','["AA", "A", "B"]',9),
 ('Gear Shaper — Disc','Material','select','','["HSS", "PM-HSS", "Carbide"]',10),
 ('Gear Shaper — Disc','Coating','select','','["Uncoated", "TiN", "TiCN", "TiAlN", "AlCrN", "AlTiN"]',11),
 ('Gear Shaper — Shank','Module / DP','dualunit','','["Module (mm)", "DP (per inch)"]',1),
 ('Gear Shaper — Shank','Pressure Angle','number','°','',2),
 ('Gear Shaper — Shank','Number of Teeth on Cutter','number','','',3),
 ('Gear Shaper — Shank','Pitch Diameter','number','mm','',4),
 ('Gear Shaper — Shank','Shank Diameter','number','mm','',5),
 ('Gear Shaper — Shank','Shank / Taper Type','select','','["MT1", "MT2", "MT3", "Straight"]',6),
 ('Gear Shaper — Shank','Overall Length','number','mm','',7),
 ('Gear Shaper — Shank','Cutting Length','number','mm','',8),
 ('Gear Shaper — Shank','Hand','select','','["RH", "LH", "Straight"]',9),
 ('Gear Shaper — Shank','Class','select','','["AA", "A", "B"]',10),
 ('Gear Shaper — Shank','Material','select','','["HSS", "PM-HSS", "Carbide"]',11),
 ('Gear Shaper — Shank','Coating','select','','["Uncoated", "TiN", "TiCN", "TiAlN", "AlCrN", "AlTiN"]',12),
 ('Broaching Tool','Overall Length','number','mm','',1),
 ('Broaching Tool','Cut / Effective Length','number','mm','',2),
 ('Broaching Tool','Pull or Push','select','','["Pull", "Push"]',3),
 ('Broaching Tool','Number of Teeth','number','','',4),
 ('Broaching Tool','Rise Per Tooth','number','mm','',5),
 ('Broaching Tool','Pitch (Tooth Spacing)','number','mm','',6),
 ('Broaching Tool','Pilot Diameter','number','mm','',7),
 ('Broaching Tool','Shank / Pull-End Diameter','number','mm','',8),
 ('Broaching Tool','Material','select','','["HSS", "PM-HSS", "Carbide"]',9),
 ('Broaching Tool','Coating','select','','["Uncoated", "TiN", "TiAlN"]',10),
 ('Broaching Tool','Construction','select','','["Solid", "Assembled/Modular"]',11),
 ('Thread Milling Cutter','Thread Standard / Profile','select','','["UN", "Metric", "NPT", "BSP", "ACME", "Whitworth", "Custom"]',1),
 ('Thread Milling Cutter','Pitch or TPI','dualunit','','["mm", "per inch"]',2),
 ('Thread Milling Cutter','Thread Diameter Range','text','','',3),
 ('Thread Milling Cutter','Cutting Diameter','number','mm','',4),
 ('Thread Milling Cutter','Number of Flutes','number','','',5),
 ('Thread Milling Cutter','Shank Diameter','number','mm','',6),
 ('Thread Milling Cutter','Overall Length','number','mm','',7),
 ('Thread Milling Cutter','Cutting Length','number','mm','',8),
 ('Thread Milling Cutter','Hand','select','','["RH", "LH"]',9),
 ('Thread Milling Cutter','Internal or External','select','','["Internal", "External", "Both"]',10),
 ('Thread Milling Cutter','Material','select','','["Carbide", "HSS", "PM-HSS"]',11),
 ('Thread Milling Cutter','Coating','select','','["Uncoated", "TiN", "TiAlN", "AlCrN"]',12),
 ('Thread Whirling Insert','Thread Profile / Form','select','','["ACME", "Buttress", "UN 60\u00b0", "Metric 60\u00b0", "Trapezoidal", "Worm", "Bone Screw", "Custom"]',1),
 ('Thread Whirling Insert','Pitch / Lead','dualunit','','["mm", "per inch"]',2),
 ('Thread Whirling Insert','Number of Starts','number','','',3),
 ('Thread Whirling Insert','Ring / Holder Size','text','','',4),
 ('Thread Whirling Insert','Number of Inserts in Ring','select','','["3", "5", "6", "8", "9", "12"]',5),
 ('Thread Whirling Insert','Cutting Edges per Insert','select','','["2", "3"]',6),
 ('Thread Whirling Insert','Hand','select','','["RH", "LH"]',7),
 ('Thread Whirling Insert','Material','select','','["Carbide"]',8),
 ('Thread Whirling Insert','Coating','select','','["Uncoated", "TiN", "TiAlN", "PVD"]',9),
 ('Worm Hob','Axial Module','number','mm','',1),
 ('Worm Hob','Normal Module','number','mm','',2),
 ('Worm Hob','Worm OD to Match','number','mm','',3),
 ('Worm Hob','Lead','number','mm','',4),
 ('Worm Hob','Lead Angle','number','°','',5),
 ('Worm Hob','Number of Threads / Starts','number','','',6),
 ('Worm Hob','Axial Pressure Angle','number','°','',7),
 ('Worm Hob','Normal Pressure Angle','number','°','',8),
 ('Worm Hob','Bore / ID','number','mm','',9),
 ('Worm Hob','Outside Diameter','number','mm','',10),
 ('Worm Hob','Hand','select','','["RH", "LH"]',11),
 ('Worm Hob','Class','select','','["AA", "A", "B"]',12),
 ('Worm Hob','Material','select','','["HSS", "PM-HSS", "Carbide"]',13),
 ('Worm Hob','Coating','select','','["Uncoated", "TiN", "TiAlN", "AlCrN"]',14),
 ('Straight Bevel Tool','Module / DP','dualunit','','["Module (mm)", "DP (per inch)"]',1),
 ('Straight Bevel Tool','Pressure Angle','select','','["20\u00b0", "22.5\u00b0", "25\u00b0"]',2),
 ('Straight Bevel Tool','Nominal Cutter Diameter','dualunit','','["inch", "mm"]',3),
 ('Straight Bevel Tool','Mounting Bore','number','mm','',4),
 ('Straight Bevel Tool','Hand','select','','["RH", "LH"]',5),
 ('Straight Bevel Tool','Material','select','','["HSS", "PM-HSS", "Carbide", "ASP2023", "S390"]',6),
 ('Straight Bevel Tool','Coating','select','','["Uncoated", "TiN", "TiAlN", "AlCrN"]',7),
 ('Spiral Bevel Tool','Item Type','select','','["Cutter Head/Body", "Cutter Blades", "Solid-Body Cutter"]',1),
 ('Spiral Bevel Tool','Manufacturer / System','select','','["Gleason", "Klingelnberg", "Oerlikon", "WMW", "Other"]',2),
 ('Spiral Bevel Tool','Process Type','select','','["Face Milling", "Face Hobbing"]',3),
 ('Spiral Bevel Tool','Nominal Cutter Diameter','dualunit','','["inch", "mm"]',4),
 ('Spiral Bevel Tool','Hand','select','','["RH", "LH"]',5),
 ('Spiral Bevel Tool','Material','select','','["HSS M2", "HSS M35", "ASP30", "Carbide"]',6),
 ('Spiral Bevel Tool','Coating','select','','["Uncoated", "TiN", "AlTiN", "AlCrN"]',7),
 ('Other Consumables','Description','text','','',1),
 ('Other Consumables','Unit of Measure','select','','["piece", "set", "box", "pack", "litre", "kg", "metre"]',2),
 ('Other Consumables','Reorder Level','number','','',3),
 ('Other Consumables','Location / Bin','text','','',4)
) AS d(fam,label,itype,unit,opts,so) ON f.name=d.fam;

INSERT INTO spec_field_def (family_id, subtype_id, label, input_type, unit, options, sort_order)
SELECT f.id, s.id, d.label, d.itype, d.unit, CASE WHEN d.opts='' THEN NULL ELSE d.opts::jsonb END, d.so
FROM tool_family f JOIN tool_subtype s ON s.family_id=f.id
JOIN (VALUES
 ('Hob Cutter','Finisher Hob','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping"]',1),
 ('Hob Cutter','Finisher Hob','Finish Stock Left on Gear','number','mm','',2),
 ('Hob Cutter','Finisher Hob','Single or Multi Start','select','','["Single", "Multi"]',3),
 ('Hob Cutter','Finisher Hob','Tip Radius','number','mm','',4),
 ('Hob Cutter','Finisher Hob','Profile Modification','select','','["None", "Tip Relief", "Crowning"]',5),
 ('Hob Cutter','Roughing Hob','Stock Left for Finishing','number','mm','',1),
 ('Hob Cutter','Roughing Hob','Root Type','select','','["Full Fillet", "Flat Root"]',2),
 ('Hob Cutter','Roughing Hob','Number of Cuts Intended','select','','["Single-cut", "Two-cut"]',3),
 ('Hob Cutter','Roughing Hob','Tip Relief Provided','select','','["Yes", "No"]',4),
 ('Hob Cutter','Semi-Finisher Hob','Finish Stock Left on Flank','number','mm','',1),
 ('Hob Cutter','Semi-Finisher Hob','Protuberance Provided','select','','["Yes", "No"]',2),
 ('Hob Cutter','Semi-Finisher Hob','Root Type','select','','["Full Fillet", "Flat Root"]',3),
 ('Hob Cutter','Semi-Finisher Hob','Tip Radius','number','mm','',4),
 ('Hob Cutter','PG Hob (Protuberance)','Protuberance Amount','number','mm','',1),
 ('Hob Cutter','PG Hob (Protuberance)','Protuberance Angle','number','°','',2),
 ('Hob Cutter','PG Hob (Protuberance)','Grinding Stock Left','number','mm','',3),
 ('Hob Cutter','PG Hob (Protuberance)','Tip Radius','number','mm','',4),
 ('Hob Cutter','PG Hob (Protuberance)','Root Type','select','','["Undercut", "Full Fillet"]',5),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)','Protuberance Amount','number','mm','',1),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)','Protuberance Angle','number','°','',2),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)','Grinding Stock Left','number','mm','',3),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)','Chamfer / Semi-Topping','select','','["None", "Chamfer", "Semi-Topping"]',4),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)','Tip Radius','number','mm','',5),
 ('Hob Cutter','PGP Hob (Protuberance + Pre-Grind)','Small (Protuberance) Pressure Angle','number','°','',6),
 ('Hob Cutter','Worm Hob','Axial Module','number','mm','',1),
 ('Hob Cutter','Worm Hob','Worm OD to Match','number','mm','',2),
 ('Hob Cutter','Worm Hob','Lead','number','mm','',3),
 ('Hob Cutter','Worm Hob','Number of Threads / Starts','number','','',4),
 ('Hob Cutter','Worm Hob','Lead Angle','number','°','',5),
 ('Hob Cutter','Worm Hob','Worm Profile','select','','["ZA", "ZN", "ZI", "ZK", "ZC"]',6),
 ('Hob Cutter','Sprocket Hob','Chain Pitch','dualunit','','["inch", "mm"]',1),
 ('Hob Cutter','Sprocket Hob','Roller Diameter','number','mm','',2),
 ('Hob Cutter','Sprocket Hob','Chain Standard','select','','["ANSI", "BS", "DIN", "JIS"]',3),
 ('Hob Cutter','Sprocket Hob','Number of Strands','select','','["Single", "Double", "Triple"]',4),
 ('Hob Cutter','Sprocket Hob','Single or Multi Start','select','','["Single", "Multi"]',5),
 ('Hob Cutter','Timing Pulley Hob','Belt Profile','select','','["MXL", "XL", "L", "H", "XH", "XXH", "T2.5", "T5", "T10", "AT5", "AT10", "HTD 3M", "HTD 5M", "HTD 8M", "HTD 14M", "GT2", "GT3"]',1),
 ('Hob Cutter','Timing Pulley Hob','Belt Pitch','dualunit','','["mm", "inch"]',2),
 ('Hob Cutter','Timing Pulley Hob','Groove/Tooth Form','select','','["Trapezoidal", "Curvilinear"]',3),
 ('Hob Cutter','Timing Pulley Hob','Single or Multi Start','select','','["Single", "Multi"]',4),
 ('Hob Cutter','Module Hob','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping"]',1),
 ('Hob Cutter','Module Hob','Stage','select','','["Roughing", "Semi-Finish", "Finish"]',2),
 ('Hob Cutter','Module Hob','Single or Multi Start','select','','["Single", "Multi"]',3),
 ('Hob Cutter','Module Hob','Tip Radius','number','mm','',4),
 ('Hob Cutter','DP Hob','Diametral Pitch','number','per inch','',1),
 ('Hob Cutter','DP Hob','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping"]',2),
 ('Hob Cutter','DP Hob','Stage','select','','["Roughing", "Semi-Finish", "Finish"]',3),
 ('Hob Cutter','DP Hob','Single or Multi Start','select','','["Single", "Multi"]',4),
 ('Hob Cutter','Spline Hob','Spline Standard','select','','["ANSI B92.1", "ANSI B92.2M", "DIN 5480", "DIN 5482", "ISO 4156", "SAE", "JIS"]',1),
 ('Hob Cutter','Spline Hob','Number of Spline Teeth','number','','',2),
 ('Hob Cutter','Spline Hob','Major Diameter','number','mm','',3),
 ('Hob Cutter','Spline Hob','Minor Diameter','number','mm','',4),
 ('Hob Cutter','Spline Hob','Fit Type','select','','["Side Fit", "Major Diameter Fit", "Minor Diameter Fit"]',5),
 ('Hob Cutter','Spline Hob','Root Type','select','','["Flat Root", "Full Fillet"]',6),
 ('Hob Cutter','Serration Hob','Serration Angle','select','','["25\u00b0", "30\u00b0", "37.5\u00b0", "45\u00b0", "60\u00b0", "90\u00b0"]',1),
 ('Hob Cutter','Serration Hob','Serration Standard','select','','["DIN 5481", "ANSI B92.1", "SAE", "Custom"]',2),
 ('Hob Cutter','Serration Hob','Number of Serrations','number','','',3),
 ('Hob Cutter','Serration Hob','Major Diameter','number','mm','',4),
 ('Hob Cutter','Serration Hob','Minor Diameter','number','mm','',5),
 ('Hob Cutter','Special Profile Hob','Profile Description','text','','',1),
 ('Hob Cutter','Special Profile Hob','Drawing / Reference Number','text','','',2),
 ('Hob Cutter','Special Profile Hob','Number of Form Rows','number','','',3),
 ('Hob Cutter','Special Profile Hob','Max Form Depth','number','mm','',4),
 ('Hob Cutter','Special Profile Hob','Single or Multi Start','select','','["Single", "Multi"]',5),
 ('Gear Shaper — Disc','Spur','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping", "Protuberance"]',1),
 ('Gear Shaper — Disc','Spur','Internal or External Gear','select','','["External", "Internal"]',2),
 ('Gear Shaper — Disc','Spur','Profile Modification','select','','["None", "Tip Relief", "Crowning"]',3),
 ('Gear Shaper — Disc','Helical','Helix Angle','number','°','',1),
 ('Gear Shaper — Disc','Helical','Helix Hand','select','','["RH", "LH"]',2),
 ('Gear Shaper — Disc','Helical','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping", "Protuberance"]',3),
 ('Gear Shaper — Disc','Helical','Internal or External Gear','select','','["External", "Internal"]',4),
 ('Gear Shaper — Shank','Spur','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping"]',1),
 ('Gear Shaper — Shank','Spur','Internal or External Gear','select','','["Internal", "External"]',2),
 ('Gear Shaper — Shank','Spur','Fluted for Rigidity','select','','["Yes", "No"]',3),
 ('Gear Shaper — Shank','Helical','Helix Angle','number','°','',1),
 ('Gear Shaper — Shank','Helical','Helix Hand','select','','["RH", "LH"]',2),
 ('Gear Shaper — Shank','Helical','Tooth Profile','select','','["Full Fillet", "Flat Root", "Semi-Topping", "Topping"]',3),
 ('Gear Shaper — Shank','Helical','Internal or External Gear','select','','["Internal", "External"]',4),
 ('Broaching Tool','Spline','Spline Standard','select','','["ANSI B92.1", "DIN 5480", "ISO 4156", "SAE", "JIS"]',1),
 ('Broaching Tool','Spline','Number of Spline Teeth','number','','',2),
 ('Broaching Tool','Spline','Major Diameter','number','mm','',3),
 ('Broaching Tool','Spline','Minor Diameter','number','mm','',4),
 ('Broaching Tool','Spline','Pressure Angle','number','°','',5),
 ('Broaching Tool','Spline','Fit Type','select','','["Side Fit", "Major Diameter Fit"]',6),
 ('Broaching Tool','Keyway','Keyway Width','number','mm','',1),
 ('Broaching Tool','Keyway','Keyway Depth','number','mm','',2),
 ('Broaching Tool','Keyway','Bushing / Horn Size','number','mm','',3),
 ('Broaching Tool','Keyway','Shim Plates Included','select','','["Yes", "No"]',4),
 ('Broaching Tool','Square','Across-Flats Size','number','mm','',1),
 ('Broaching Tool','Square','Corner Radius','number','mm','',2),
 ('Broaching Tool','Square','Starting Hole Diameter','number','mm','',3),
 ('Broaching Tool','D-Type','Flat Width','number','mm','',1),
 ('Broaching Tool','D-Type','Bore Diameter','number','mm','',2),
 ('Broaching Tool','D-Type','Flat Depth (Chord)','number','mm','',3),
 ('Broaching Tool','Helical','Helix Angle','number','°','',1),
 ('Broaching Tool','Helical','Helix Hand','select','','["RH", "LH"]',2),
 ('Broaching Tool','Helical','Lead','number','mm','',3),
 ('Broaching Tool','Helical','Spline / Form Profile','select','','["Involute Spline", "Straight Spline", "Serration"]',4),
 ('Broaching Tool','Helical','Number of Teeth on Part','number','','',5),
 ('Broaching Tool','Miscellaneous','Form Description','text','','',1),
 ('Broaching Tool','Miscellaneous','Drawing / Reference Number','text','','',2),
 ('Broaching Tool','Miscellaneous','Across-Form Size','number','mm','',3),
 ('Broaching Tool','Miscellaneous','Starting Hole Diameter','number','mm','',4),
 ('Thread Milling Cutter','Single-Form','Pitch Range Covered','text','','',1),
 ('Thread Milling Cutter','Single-Form','Reduced/Necked Shank','select','','["Yes", "No"]',2),
 ('Thread Milling Cutter','Single-Form','Max Thread Depth Reach','number','mm','',3),
 ('Thread Milling Cutter','Single-Form','Point / Single Tooth','select','','["Single Point", "Single Row"]',4),
 ('Thread Milling Cutter','Multi-Form','Number of Tooth Rows','number','','',1),
 ('Thread Milling Cutter','Multi-Form','Fixed Pitch','dualunit','','["mm", "per inch"]',2),
 ('Thread Milling Cutter','Multi-Form','Coolant-Through','select','','["Yes", "No"]',3),
 ('Thread Milling Cutter','Multi-Form','Full Thread in One Pass','select','','["Yes", "No"]',4),
 ('Thread Whirling Insert','Full','Full Thread Profile Depth','number','mm','',1),
 ('Thread Whirling Insert','Full','Insert Width','number','mm','',2),
 ('Thread Whirling Insert','Full','Insert Corner Radius','number','mm','',3),
 ('Thread Whirling Insert','Full','Single-Pass Capable','select','','["Yes", "No"]',4),
 ('Thread Whirling Insert','Partial','Roughing / Finishing Role','select','','["Roughing", "Finishing"]',1),
 ('Thread Whirling Insert','Partial','Insert Position in Ring','text','','',2),
 ('Thread Whirling Insert','Partial','Rough:Finish Insert Ratio','text','','',3),
 ('Thread Whirling Insert','Partial','Stock Left for Finish Inserts','number','mm','',4),
 ('Thread Whirling Insert','Custom Profile','Profile Description','text','','',1),
 ('Thread Whirling Insert','Custom Profile','Drawing / Reference Number','text','','',2),
 ('Thread Whirling Insert','Custom Profile','Insert Width','number','mm','',3),
 ('Thread Whirling Insert','Custom Profile','Cutting Point Offset','number','mm','',4),
 ('Worm Hob','ZA','Profile Straight In','select','','["Axial Section"]',1),
 ('Worm Hob','ZA','Oversize vs Worm','number','mm','',2),
 ('Worm Hob','ZA','Protuberance Provided','select','','["Yes", "No"]',3),
 ('Worm Hob','ZN','Profile Straight In','select','','["Normal Section"]',1),
 ('Worm Hob','ZN','Oversize vs Worm','number','mm','',2),
 ('Worm Hob','ZN','Protuberance Provided','select','','["Yes", "No"]',3),
 ('Worm Hob','ZI','Base Circle Diameter','number','mm','',1),
 ('Worm Hob','ZI','Profile Type','select','','["Involute Helicoid"]',2),
 ('Worm Hob','ZI','Oversize vs Worm','number','mm','',3),
 ('Worm Hob','ZK','Generating Cutter/Wheel Diameter','number','mm','',1),
 ('Worm Hob','ZK','Profile Type','select','','["Milled/Ground Convex"]',2),
 ('Worm Hob','ZK','Oversize vs Worm','number','mm','',3),
 ('Worm Hob','ZC','Profile Radius','number','mm','',1),
 ('Worm Hob','ZC','Mean Diameter','number','mm','',2),
 ('Worm Hob','ZC','Profile Type','select','','["Concave Circular Arc (Cavex)"]',3),
 ('Worm Hob','Custom','Profile Description','text','','',1),
 ('Worm Hob','Custom','Drawing / Reference Number','text','','',2),
 ('Worm Hob','Custom','Oversize vs Worm','number','mm','',3),
 ('Straight Bevel Tool','Two-Blade','Number of Blades','number','','',1),
 ('Straight Bevel Tool','Two-Blade','Blade Type','select','','["Roughing", "Finishing"]',2),
 ('Straight Bevel Tool','Two-Blade','Blade Group Arrangement','text','','',3),
 ('Straight Bevel Tool','Two-Blade','Point Width','number','mm','',4),
 ('Straight Bevel Tool','CONIFLEX-type','Interlocking Pair','select','','["Yes (two cutters)", "No"]',1),
 ('Straight Bevel Tool','CONIFLEX-type','Number of Blades per Cutter','number','','',2),
 ('Straight Bevel Tool','CONIFLEX-type','Upper/Lower Flank','select','','["Upper", "Lower", "Both"]',3),
 ('Straight Bevel Tool','CONIFLEX-type','Cutter Reference Height','number','mm','',4),
 ('Straight Bevel Tool','CONIFLEX-type','Blade Material','select','','["ASP2023", "S390", "HSS M2", "HSS M35"]',5),
 ('Spiral Bevel Tool','Face Hobbing / Spiral Hob','Number of Blade Groups','number','','',1),
 ('Spiral Bevel Tool','Face Hobbing / Spiral Hob','Blades per Set (total)','number','','',2),
 ('Spiral Bevel Tool','Face Hobbing / Spiral Hob','Spiral Angle','number','°','',3),
 ('Spiral Bevel Tool','Face Hobbing / Spiral Hob','Mounting Bore','number','mm','',4),
 ('Spiral Bevel Tool','Face Hobbing / Spiral Hob','Module / DP','dualunit','','["Module (mm)", "DP (per inch)"]',5),
 ('Spiral Bevel Tool','Solid / Full-Body Cutter','Cutter Diameter','dualunit','','["inch", "mm"]',1),
 ('Spiral Bevel Tool','Solid / Full-Body Cutter','Mounting Bore','number','mm','',2),
 ('Spiral Bevel Tool','Solid / Full-Body Cutter','Module or DP it Cuts','dualunit','','["Module (mm)", "DP (per inch)"]',3),
 ('Spiral Bevel Tool','Solid / Full-Body Cutter','Number of Cutting Teeth','number','','',4),
 ('Spiral Bevel Tool','Cutter Head','Number of Blade Slots','number','','',1),
 ('Spiral Bevel Tool','Cutter Head','Blade System Accepted','select','','["Alternate (2-blade)", "Triplex (3-blade)", "Single-sided"]',2),
 ('Spiral Bevel Tool','Cutter Head','Mounting Bore','number','mm','',3),
 ('Spiral Bevel Tool','Cutter Head','Spindle Mount / Keyway Type','text','','',4),
 ('Spiral Bevel Tool','Cutter Head','Body Height / Thickness','number','mm','',5),
 ('Spiral Bevel Tool','Cutter Blades','Blade Type','select','','["RIDG-AC", "ROUGH-AC", "WEDG-AC", "Soft-Body", "HARDAC", "Helixform", "Alternate STD", "Kurvex", "AMK 5L/5R", "Spiromatic", "Konvoid"]',1),
 ('Spiral Bevel Tool','Cutter Blades','Roughing or Finishing','select','','["Roughing", "Finishing"]',2),
 ('Spiral Bevel Tool','Cutter Blades','Inside or Outside','select','','["Inside (IB)", "Outside (OB)", "Matched Set"]',3),
 ('Spiral Bevel Tool','Cutter Blades','Blade Point Width','dualunit','','["mm", "inch"]',4),
 ('Spiral Bevel Tool','Cutter Blades','Point Width Letter Code','text','','',5),
 ('Spiral Bevel Tool','Cutter Blades','Pressure Angle','number','°','',6),
 ('Spiral Bevel Tool','Cutter Blades','TOPREM (Tip Relief)','select','','["With TOPREM", "Without"]',7),
 ('Spiral Bevel Tool','Cutter Blades','Blades per Set','number','','',8)
) AS d(fam,sub,label,itype,unit,opts,so) ON d.fam=f.name AND d.sub=s.name;

-- master data
INSERT INTO master_data (kind, value) VALUES
 ('units','Unit 1'),('units','Unit 2'),('units','Unit 3'),
 ('machines','HOB-01'),('machines','HOB-03'),('machines','GRIND-02'),('machines','CNC-05'),
 ('employees','EMP245 — R. Kumar'),('employees','EMP198 — S. Rao'),('employees','EMP311 — M. Iqbal'),
 ('suppliers','LMT Tools'),('suppliers','Star'),('suppliers','Sandvik'),('suppliers','Miranda'),
 ('locations','Rack G2 / Shelf 4'),('locations','Rack G1 / Shelf 2'),('locations','C1 / S1'),('locations','Quarantine');

INSERT INTO app_user (user_id, name, role, scope) VALUES
 ('ADMIN01','Site Admin','Admin','All'),
 ('EMP102','Gate Keeper','Gate staff','Gate'),
 ('EMP087','Crib In-charge','Inventory staff','Inventory');

CREATE TABLE role_perm (
  role    TEXT PRIMARY KEY,
  screens JSONB NOT NULL DEFAULT '[]'
);
INSERT INTO role_perm (role, screens) VALUES
 ('Gate staff', '["gate"]'),
 ('Inventory staff', '["qc","tools","detail","issue","return","regrind"]'),
 ('Admin', '["dash","gate","qc","tools","detail","issue","return","regrind","reports","admin"]');

-- seed tools
INSERT INTO tool (code, category, name, manufacturer, material, cost, status, location, unit,
                  issued_to, machine, work_order, expected_return, regrind_cost, times_issued, times_reground, spec)
VALUES
 ('GT-HOB-000124','Hob Cutter ▸ Standard','Module Hob m3 20° PA','LMT','HSS',38000,'ISSUED','—','Unit 2',
   'EMP245 — R. Kumar','HOB-03','WO-5521','2026-07-12',3200,4,1,
   '{"Gear System":"Metric","Module":"3.0 mm","Pressure Angle":"20 °","Number of Starts":"1","Hob Hand":"RH"}'),
 ('GT-HOB-000131','Hob Cutter ▸ Topping','Topping Hob m2.5','Star','PM-HSS',41000,'AVAILABLE','Rack G2 / Shelf 4','—',
   '—','—','—',NULL,0,2,0,'{"Gear System":"Metric","Module":"2.5 mm","Hob Hand":"RH"}'),
 ('GT-SHD-000031','Gear Shaper — Disc ▸ Spur','Disc Shaper Cutter m2','Sandvik','PM-HSS',22500,'REGRINDING','@ vendor','—',
   '—','—','—',NULL,2800,6,2,'{"Module / DP":"m2","Pressure Angle":"20 °"}'),
 ('GT-BRC-000009','Broaching Tool ▸ Spline','Involute Spline Broach 6T','Miranda','HSS',64000,'AVAILABLE','Rack G1 / Shelf 2','—',
   '—','—','—',NULL,0,1,0,'{"Broach Operation":"Internal","Spline Type":"Involute"}');

INSERT INTO stock (category, name, qty, cost, location) VALUES
 ('Other Consumables','Cutting fluid (drum 208 L)',14,9800,'C1 / S1');

INSERT INTO event (tool_code, type, text) VALUES
 ('GT-HOB-000124','gate','Entered gate'),
 ('GT-HOB-000124','qc','Gate QC passed · EMP102'),
 ('GT-HOB-000124','accept','Inventory accepted · EMP087'),
 ('GT-HOB-000124','issue','Issued to EMP245 · HOB-03 · Unit 2');
