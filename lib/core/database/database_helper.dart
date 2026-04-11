// lib/core/database/database_helper.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Singleton database helper for the clinic management system.
/// Uses sqflite_common_ffi for Windows/Desktop support.
class DatabaseHelper {
  static const String _dbName = 'clinic.db';
  static const int _dbVersion = 1;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  // FIX #1 – Race-condition guard: prevents concurrent calls to _initDatabase()
  // when multiple awaits hit `get database` before the first one completes.
  Completer<Database>? _dbCompleter;

  // FIX #8 – Prevent sqfliteFfiInit() from being called more than once
  // (e.g. after a database restore that calls _initDatabase() again).
  bool _ffiInitialized = false;

  // ─── Public access ───────────────────────────────────────────

  Future<Database> get database async {
    if (_db != null) return _db!;
    // If another caller already started initialisation, wait for it.
    if (_dbCompleter != null) return _dbCompleter!.future;

    _dbCompleter = Completer<Database>();
    try {
      _db = await _initDatabase();
      _dbCompleter!.complete(_db!);
    } catch (e, st) {
      _dbCompleter!.completeError(e, st);
      _dbCompleter = null; // allow retry on next call
      rethrow;
    }
    return _db!;
  }

  // ─── Initialization ──────────────────────────────────────────

  Future<Database> _initDatabase() async {
    // FIX #8 – Guard FFI initialisation so it only runs once per process.
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }

    final dbPath = await _resolveDatabasePath();
    debugPrint('[DB] Opening database at: $dbPath');

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<String> _resolveDatabasePath() async {
    final dir = await _getDatabaseDirectory();
    return p.join(dir, _dbName);
  }

  Future<String> _getDatabaseDirectory() async {
    // On Windows, store alongside the executable
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final dataDir = Directory(p.join(exeDir, 'data'));
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }
    return dataDir.path;
  }

  /// Enable foreign key enforcement for every connection.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB] Creating tables (version $version)');
    await _createAllTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading from $oldVersion to $newVersion');
    // Future migrations go here
  }

  // ─── Schema ──────────────────────────────────────────────────

  Future<void> _createAllTables(Database db) async {
    final statements = _schemaStatements();
    for (final sql in statements) {
      await db.execute(sql);
    }
    debugPrint('[DB] All tables created successfully');
  }

  List<String> _schemaStatements() => [
        // ── PATIENTS ──
        '''
        CREATE TABLE IF NOT EXISTS patients (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          name        TEXT NOT NULL,
          phone       TEXT,
          email       TEXT,
          birth_date  TEXT,
          gender      TEXT CHECK(gender IN ('male','female')),
          address     TEXT,
          notes       TEXT,
          is_active   INTEGER NOT NULL DEFAULT 1,
          created_at  TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_patients_phone ON patients(phone)',
        'CREATE INDEX IF NOT EXISTS idx_patients_name  ON patients(name)',

        // ── DOCTORS ──
        '''
        CREATE TABLE IF NOT EXISTS doctors (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          name            TEXT NOT NULL,
          specialty       TEXT,
          phone           TEXT,
          commission_pct  REAL NOT NULL DEFAULT 0.0,
          is_active       INTEGER NOT NULL DEFAULT 1,
          created_at      TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',

        // ── PROCEDURES ──
        '''
        CREATE TABLE IF NOT EXISTS procedures (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          name          TEXT NOT NULL,
          description   TEXT,
          default_price REAL NOT NULL DEFAULT 0.0,
          is_active     INTEGER NOT NULL DEFAULT 1,
          created_at    TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',

        // ── APPOINTMENTS ──
        '''
        CREATE TABLE IF NOT EXISTS appointments (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id    INTEGER NOT NULL,
          doctor_id     INTEGER NOT NULL,
          scheduled_at  TEXT NOT NULL,
          status        TEXT NOT NULL DEFAULT 'pending'
                            CHECK(status IN ('pending','confirmed','cancelled','completed')),
          notes         TEXT,
          created_at    TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at    TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT,
          FOREIGN KEY (doctor_id)  REFERENCES doctors(id)  ON DELETE RESTRICT
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_appt_patient   ON appointments(patient_id)',
        'CREATE INDEX IF NOT EXISTS idx_appt_doctor    ON appointments(doctor_id)',
        'CREATE INDEX IF NOT EXISTS idx_appt_scheduled ON appointments(scheduled_at)',

        // ── VISITS ──
        '''
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
          FOREIGN KEY (patient_id)     REFERENCES patients(id)     ON DELETE RESTRICT,
          FOREIGN KEY (doctor_id)      REFERENCES doctors(id)      ON DELETE RESTRICT,
          FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_visits_patient ON visits(patient_id)',
        'CREATE INDEX IF NOT EXISTS idx_visits_doctor  ON visits(doctor_id)',
        'CREATE INDEX IF NOT EXISTS idx_visits_date    ON visits(visit_date)',

        // ── VISIT_PROCEDURES ──
        '''
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
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_vp_visit ON visit_procedures(visit_id)',

        // ── INVOICES ──
        '''
        CREATE TABLE IF NOT EXISTS invoices (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          visit_id     INTEGER,
          patient_id   INTEGER NOT NULL,
          invoice_date TEXT NOT NULL DEFAULT (date('now')),
          total_amount REAL NOT NULL DEFAULT 0.0,
          discount     REAL NOT NULL DEFAULT 0.0,
          net_amount   REAL NOT NULL DEFAULT 0.0,
          paid_amount  REAL NOT NULL DEFAULT 0.0,
          status       TEXT NOT NULL DEFAULT 'unpaid'
                           CHECK(status IN ('unpaid','partial','paid','cancelled')),
          notes        TEXT,
          is_locked    INTEGER NOT NULL DEFAULT 0,
          created_at   TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at   TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (visit_id)   REFERENCES visits(id)   ON DELETE SET NULL,
          FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE RESTRICT
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_invoices_patient ON invoices(patient_id)',
        'CREATE INDEX IF NOT EXISTS idx_invoices_visit   ON invoices(visit_id)',
        'CREATE INDEX IF NOT EXISTS idx_invoices_date    ON invoices(invoice_date)',
        'CREATE INDEX IF NOT EXISTS idx_invoices_status  ON invoices(status)',

        // ── INVOICE_ITEMS ──
        '''
        CREATE TABLE IF NOT EXISTS invoice_items (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id  INTEGER NOT NULL,
          description TEXT NOT NULL,
          quantity    INTEGER NOT NULL DEFAULT 1,
          unit_price  REAL    NOT NULL,
          discount    REAL    NOT NULL DEFAULT 0.0,
          total       REAL    NOT NULL,
          created_at  TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_items_invoice ON invoice_items(invoice_id)',

        // ── PAYMENTS ──
        '''
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
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id)',
        'CREATE INDEX IF NOT EXISTS idx_payments_date    ON payments(payment_date)',

        // ── EXPENSES ──
        '''
        CREATE TABLE IF NOT EXISTS expenses (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          category     TEXT NOT NULL,
          description  TEXT NOT NULL,
          amount       REAL NOT NULL CHECK(amount > 0),
          expense_date TEXT NOT NULL DEFAULT (date('now')),
          notes        TEXT,
          created_at   TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date)',

        // ── ITEMS (Inventory) ──
        '''
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
        )
        ''',

        // ── STOCK_MOVEMENTS ──
        '''
        CREATE TABLE IF NOT EXISTS stock_movements (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id       INTEGER NOT NULL,
          type          TEXT NOT NULL CHECK(type IN ('in','out','adjustment')),
          quantity      REAL NOT NULL,
          unit_cost     REAL,
          reference     TEXT,
          notes         TEXT,
          movement_date TEXT NOT NULL DEFAULT (date('now')),
          created_at    TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_stock_item ON stock_movements(item_id)',
        'CREATE INDEX IF NOT EXISTS idx_stock_date ON stock_movements(movement_date)',

        // ── CASH_BOX ──
        '''
        CREATE TABLE IF NOT EXISTS cash_box (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          box_date        TEXT NOT NULL UNIQUE,
          opening_balance REAL NOT NULL DEFAULT 0.0,
          closing_balance REAL,
          is_closed       INTEGER NOT NULL DEFAULT 0,
          notes           TEXT,
          created_at      TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_cash_box_date ON cash_box(box_date)',

        // ── AUDIT_LOG ──
        '''
        CREATE TABLE IF NOT EXISTS audit_log (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name   TEXT NOT NULL,
          record_id    INTEGER NOT NULL,
          action       TEXT NOT NULL CHECK(action IN ('INSERT','UPDATE','DELETE')),
          old_values   TEXT,
          new_values   TEXT,
          performed_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_audit_table    ON audit_log(table_name)',
        'CREATE INDEX IF NOT EXISTS idx_audit_record   ON audit_log(record_id)',
        'CREATE INDEX IF NOT EXISTS idx_audit_performed ON audit_log(performed_at)',
      ];

  // ─── Generic CRUD helpers ─────────────────────────────────────

  /// Insert a row and return its new id.
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    final db = await database;
    return db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  /// Query rows from [table] with optional [where] clause.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Update rows and return the number of affected rows.
  /// FIX #2 – Copies [values] before injecting updated_at so the caller's
  /// map literal is never mutated as a side-effect.
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    // Use a copy so the original map passed by the caller is never modified.
    final copy = Map<String, dynamic>.of(values);
    copy['updated_at'] = DateTime.now().toIso8601String();
    return db.update(table, copy, where: where, whereArgs: whereArgs);
  }

  /// Delete rows and return the number of affected rows.
  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Execute a raw SQL query that returns rows.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  /// Execute a raw SQL statement (no return value).
  Future<void> execute(String sql, [List<Object?>? args]) async {
    final db = await database;
    await db.execute(sql, args);
  }

  // ─── Transaction helpers ──────────────────────────────────────

  /// Run [action] inside a database transaction.
  /// Rolls back automatically on exception.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  // ─── Audit Log ────────────────────────────────────────────────

  /// Write an audit entry (fire-and-forget; errors are logged but not thrown).
  Future<void> writeAuditLog({
    required String tableName,
    required int recordId,
    required String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    try {
      await insert('audit_log', {
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        // FIX #3 – Use dart:convert jsonEncode instead of a hand-rolled
        // serialiser that wrapped all values in quotes (broke numbers/booleans).
        'old_values': oldValues != null ? jsonEncode(oldValues) : null,
        'new_values': newValues != null ? jsonEncode(newValues) : null,
        'performed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[DB][AuditLog] Failed to write: $e');
    }
  }

  // ─── Backup & Restore ─────────────────────────────────────────

  /// Copy the current database file to [destPath].
  Future<void> backupTo(String destPath) async {
    final db = await database;
    // Close WAL checkpoint before copying
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    final src = File(db.path);
    await src.copy(destPath);
    debugPrint('[DB] Backup written to $destPath');
  }

  /// Close the current DB and replace it with [sourcePath], then re-open.
  /// FIX #8 – Resets the completer so the next `get database` call re-enters
  /// the guarded initialisation path cleanly.
  Future<void> restoreFrom(String sourcePath) async {
    final db = await database;
    final currentPath = db.path;
    await db.close();
    _db = null;
    _dbCompleter = null; // reset so next caller re-initialises properly
    await File(sourcePath).copy(currentPath);
    debugPrint('[DB] Restored from $sourcePath');
    // Re-open (FFI guard prevents double-init of sqfliteFfi).
    _db = await _initDatabase();
    _dbCompleter = Completer<Database>()..complete(_db!);
  }

  // ─── Utilities ───────────────────────────────────────────────

  /// Close the database (call on app dispose).
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbCompleter = null;
      debugPrint('[DB] Database closed');
    }
  }
}
