-- ============================================================
-- CLINIC MANAGEMENT SYSTEM - SQLite Schema
-- ============================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ============================================================
-- MEDICAL MODULE
-- ============================================================

CREATE TABLE IF NOT EXISTS patients (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    phone       TEXT,
    email       TEXT,
    birth_date  TEXT,
    gender      TEXT CHECK(gender IN ('male', 'female')),
    address     TEXT,
    notes       TEXT,
    is_active   INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_patients_phone ON patients(phone);
CREATE INDEX IF NOT EXISTS idx_patients_name  ON patients(name);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS doctors (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    specialty       TEXT,
    phone           TEXT,
    commission_pct  REAL NOT NULL DEFAULT 0.0,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS procedures (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    description TEXT,
    default_price REAL NOT NULL DEFAULT 0.0,
    is_active   INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS appointments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id      INTEGER NOT NULL,
    doctor_id       INTEGER NOT NULL,
    scheduled_at    TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK(status IN ('pending','confirmed','cancelled','completed')),
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT,
    FOREIGN KEY (doctor_id)  REFERENCES doctors(id)  ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_appointments_patient   ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor    ON appointments(doctor_id);
CREATE INDEX IF NOT EXISTS idx_appointments_scheduled ON appointments(scheduled_at);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS visits (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id      INTEGER NOT NULL,
    doctor_id       INTEGER NOT NULL,
    appointment_id  INTEGER,
    visit_date      TEXT NOT NULL DEFAULT (date('now')),
    diagnosis       TEXT,
    notes           TEXT,
    is_locked       INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (patient_id)     REFERENCES patients(id)      ON DELETE RESTRICT,
    FOREIGN KEY (doctor_id)      REFERENCES doctors(id)       ON DELETE RESTRICT,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)  ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_visits_patient ON visits(patient_id);
CREATE INDEX IF NOT EXISTS idx_visits_doctor  ON visits(doctor_id);
CREATE INDEX IF NOT EXISTS idx_visits_date    ON visits(visit_date);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS visit_procedures (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id     INTEGER NOT NULL,
    procedure_id INTEGER NOT NULL,
    quantity     INTEGER NOT NULL DEFAULT 1,
    unit_price   REAL    NOT NULL,
    discount     REAL    NOT NULL DEFAULT 0.0,
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (visit_id)     REFERENCES visits(id)     ON DELETE CASCADE,
    FOREIGN KEY (procedure_id) REFERENCES procedures(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_visit_procedures_visit ON visit_procedures(visit_id);

-- ============================================================
-- ACCOUNTING MODULE
-- ============================================================

CREATE TABLE IF NOT EXISTS invoices (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id        INTEGER,
    patient_id      INTEGER NOT NULL,
    invoice_date    TEXT NOT NULL DEFAULT (date('now')),
    total_amount    REAL NOT NULL DEFAULT 0.0,
    discount        REAL NOT NULL DEFAULT 0.0,
    net_amount      REAL NOT NULL DEFAULT 0.0,
    paid_amount     REAL NOT NULL DEFAULT 0.0,
    status          TEXT NOT NULL DEFAULT 'unpaid'
                        CHECK(status IN ('unpaid','partial','paid','cancelled')),
    notes           TEXT,
    is_locked       INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (visit_id)   REFERENCES visits(id)   ON DELETE SET NULL,
    FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_invoices_patient ON invoices(patient_id);
CREATE INDEX IF NOT EXISTS idx_invoices_date    ON invoices(invoice_date);
CREATE INDEX IF NOT EXISTS idx_invoices_status  ON invoices(status);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS invoice_items (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id   INTEGER NOT NULL,
    description  TEXT NOT NULL,
    quantity     INTEGER NOT NULL DEFAULT 1,
    unit_price   REAL    NOT NULL,
    discount     REAL    NOT NULL DEFAULT 0.0,
    total        REAL    NOT NULL,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payments (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id   INTEGER NOT NULL,
    amount       REAL    NOT NULL CHECK(amount > 0),
    payment_date TEXT NOT NULL DEFAULT (date('now')),
    method       TEXT NOT NULL DEFAULT 'cash'
                     CHECK(method IN ('cash','card','transfer','other')),
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_date    ON payments(payment_date);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS expenses (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    category     TEXT NOT NULL,
    description  TEXT NOT NULL,
    amount       REAL NOT NULL CHECK(amount > 0),
    expense_date TEXT NOT NULL DEFAULT (date('now')),
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);

-- ============================================================
-- INVENTORY MODULE
-- ============================================================

CREATE TABLE IF NOT EXISTS items (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT NOT NULL,
    unit         TEXT,
    min_quantity REAL NOT NULL DEFAULT 0.0,
    quantity     REAL NOT NULL DEFAULT 0.0,
    unit_cost    REAL NOT NULL DEFAULT 0.0,
    is_active    INTEGER NOT NULL DEFAULT 1,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stock_movements (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id      INTEGER NOT NULL,
    type         TEXT NOT NULL CHECK(type IN ('in','out','adjustment')),
    quantity     REAL NOT NULL,
    unit_cost    REAL,
    reference    TEXT,
    notes        TEXT,
    movement_date TEXT NOT NULL DEFAULT (date('now')),
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_item ON stock_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(movement_date);

-- ============================================================
-- CASH BOX
-- ============================================================

CREATE TABLE IF NOT EXISTS cash_box (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    box_date        TEXT NOT NULL UNIQUE,
    opening_balance REAL NOT NULL DEFAULT 0.0,
    closing_balance REAL,
    is_closed       INTEGER NOT NULL DEFAULT 0,
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_cash_box_date ON cash_box(box_date);

-- ============================================================
-- AUDIT LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,
    record_id   INTEGER NOT NULL,
    action      TEXT NOT NULL CHECK(action IN ('INSERT','UPDATE','DELETE')),
    old_values  TEXT,
    new_values  TEXT,
    performed_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_table    ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record   ON audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_performed ON audit_log(performed_at);
