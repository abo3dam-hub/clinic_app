// lib/core/database/database_helper.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static const String _dbName = 'clinic.db';
  static const int _dbVersion = 3; // bumped: v2→v3 adds procedure_materials

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;
  Completer<Database>? _dbCompleter;
  bool _ffiInitialized = false;

  // ─── Public access ───────────────────────────────────────────

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (_dbCompleter != null) return _dbCompleter!.future;

    _dbCompleter = Completer<Database>();
    try {
      _db = await _initDatabase();
      _dbCompleter!.complete(_db!);
    } catch (e, st) {
      _dbCompleter!.completeError(e, st);
      _dbCompleter = null;
      rethrow;
    }
    return _db!;
  }

  // ─── Initialization ──────────────────────────────────────────

  Future<Database> _initDatabase() async {
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
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final dataDir = Directory(p.join(exeDir, 'data'));
    if (!dataDir.existsSync()) dataDir.createSync(recursive: true);
    return dataDir.path;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[DB] Creating tables (version $version)');
    await _createAllTables(db);
    await _seedChartOfAccounts(db); // seed COA on fresh install
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading $oldVersion → $newVersion');
    if (oldVersion < 2) {
      // Add the three accounting tables and seed COA
      for (final sql in _accountingSchemaStatements()) {
        await db.execute(sql);
      }
      await _seedChartOfAccounts(db);
      debugPrint('[DB] Migration v1→v2 complete');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS procedure_materials (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          procedure_id  INTEGER NOT NULL,
          inventory_id  INTEGER NOT NULL,
          quantity      REAL NOT NULL DEFAULT 1.0,
          created_at    TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (procedure_id) REFERENCES procedures(id) ON DELETE CASCADE,
          FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE RESTRICT
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_proc_mat_proc  ON procedure_materials(procedure_id)');
      debugPrint('[DB] Migration v2→v3 complete (procedure_materials)');
    }
  }

  // ─── Schema ──────────────────────────────────────────────────

  Future<void> _createAllTables(Database db) async {
    for (final sql in [..._coreSchemaStatements(), ..._accountingSchemaStatements()]) {
      await db.execute(sql);
    }
    debugPrint('[DB] All tables created successfully');
  }

  List<String> _coreSchemaStatements() => [
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

        // ── PROCEDURE_MATERIALS ──
        '''
        CREATE TABLE IF NOT EXISTS procedure_materials (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          procedure_id  INTEGER NOT NULL,
          inventory_id  INTEGER NOT NULL,
          quantity      REAL NOT NULL DEFAULT 1.0,
          created_at    TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (procedure_id) REFERENCES procedures(id) ON DELETE CASCADE,
          FOREIGN KEY (inventory_id) REFERENCES inventory(id) ON DELETE RESTRICT
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_proc_mat_proc  ON procedure_materials(procedure_id)',

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
        'CREATE INDEX IF NOT EXISTS idx_audit_table     ON audit_log(table_name)',
        'CREATE INDEX IF NOT EXISTS idx_audit_record    ON audit_log(record_id)',
        'CREATE INDEX IF NOT EXISTS idx_audit_performed ON audit_log(performed_at)',
      ];

  // ── ACCOUNTING SCHEMA (v2) ────────────────────────────────────

  List<String> _accountingSchemaStatements() => [
        // ── CHART OF ACCOUNTS ──
        '''
        CREATE TABLE IF NOT EXISTS chart_of_accounts (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          code       TEXT NOT NULL UNIQUE,
          name       TEXT NOT NULL,
          type       TEXT NOT NULL
                         CHECK(type IN ('asset','liability','equity','revenue','expense')),
          is_active  INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_coa_code ON chart_of_accounts(code)',
        'CREATE INDEX IF NOT EXISTS idx_coa_type ON chart_of_accounts(type)',

        // ── JOURNAL ENTRIES (header) ──
        '''
        CREATE TABLE IF NOT EXISTS journal_entries (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          reference   TEXT,
          entry_date  TEXT NOT NULL,
          description TEXT NOT NULL,
          source_type TEXT CHECK(source_type IN ('invoice','payment','expense','manual')),
          source_id   INTEGER,
          created_at  TEXT NOT NULL DEFAULT (datetime('now'))
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_je_date   ON journal_entries(entry_date)',
        'CREATE INDEX IF NOT EXISTS idx_je_source ON journal_entries(source_type, source_id)',

        // ── JOURNAL ENTRY LINES (debit / credit) ──
        '''
        CREATE TABLE IF NOT EXISTS journal_entry_lines (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          entry_id    INTEGER NOT NULL,
          account_id  INTEGER NOT NULL,
          debit       REAL    NOT NULL DEFAULT 0.0,
          credit      REAL    NOT NULL DEFAULT 0.0,
          description TEXT,
          FOREIGN KEY (entry_id)   REFERENCES journal_entries(id)    ON DELETE CASCADE,
          FOREIGN KEY (account_id) REFERENCES chart_of_accounts(id)  ON DELETE RESTRICT
        )
        ''',
        'CREATE INDEX IF NOT EXISTS idx_jel_entry   ON journal_entry_lines(entry_id)',
        'CREATE INDEX IF NOT EXISTS idx_jel_account ON journal_entry_lines(account_id)',
      ];

  // ── Seed Chart of Accounts ────────────────────────────────────

  /// Seeds the standard COA for a medical clinic.
  /// Uses INSERT OR IGNORE — safe to call more than once.
  Future<void> _seedChartOfAccounts(Database db) async {
    const accounts = [
      // (code, name, type, sort_order)
      ('1100', 'الصندوق (نقدية)',             'asset',      10),
      ('1200', 'حسابات العملاء (مدينون)',     'asset',      20),
      ('1300', 'مخزون لوازم طبية',            'asset',      30),
      ('2100', 'حسابات الموردين (دائنون)',    'liability',  40),
      ('2200', 'مصروفات مستحقة',              'liability',  50),
      ('3000', 'حقوق الملكية',                'equity',     60),
      ('3100', 'الأرباح المحتجزة',            'equity',     70),
      ('4100', 'إيراد الخدمات الطبية',        'revenue',    80),
      ('4200', 'إيرادات أخرى',                'revenue',    90),
      ('5100', 'المصروفات التشغيلية',         'expense',   100),
      ('5200', 'مصروفات الرواتب',             'expense',   110),
      ('5300', 'مصروفات الإيجار',             'expense',   120),
      ('5400', 'مصروفات الكهرباء والمياه',    'expense',   130),
      ('5500', 'مصروفات المستلزمات الطبية',   'expense',   140),
      ('5600', 'مصروفات الصيانة',             'expense',   150),
      ('5900', 'مصروفات متنوعة',              'expense',   160),
    ];
    for (final (code, name, type, order) in accounts) {
      await db.insert(
        'chart_of_accounts',
        {
          'code': code, 'name': name,
          'type': type, 'sort_order': order, 'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    debugPrint('[DB] Chart of accounts seeded (${accounts.length} accounts)');
  }

  // ─── Generic CRUD helpers ─────────────────────────────────────

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    final db = await database;
    return db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    final copy = Map<String, dynamic>.of(values);
    copy['updated_at'] = DateTime.now().toIso8601String();
    return db.update(table, copy, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> execute(String sql, [List<Object?>? args]) async {
    final db = await database;
    await db.execute(sql, args);
  }

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  // ─── Audit Log ────────────────────────────────────────────────

  Future<void> writeAuditLog({
    required String tableName,
    required int recordId,
    required String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    try {
      await insert('audit_log', {
        'table_name':  tableName,
        'record_id':   recordId,
        'action':      action,
        'old_values':  oldValues != null ? jsonEncode(oldValues) : null,
        'new_values':  newValues != null ? jsonEncode(newValues) : null,
        'performed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[DB][AuditLog] Failed to write: $e');
    }
  }

  // ─── Backup & Restore ─────────────────────────────────────────

  Future<void> backupTo(String destPath) async {
    final db = await database;
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    await File(db.path).copy(destPath);
    debugPrint('[DB] Backup written to $destPath');
  }

  Future<void> restoreFrom(String sourcePath) async {
    final db = await database;
    final currentPath = db.path;
    await db.close();
    _db = null;
    _dbCompleter = null;
    await File(sourcePath).copy(currentPath);
    debugPrint('[DB] Restored from $sourcePath');
    _db = await _initDatabase();
    _dbCompleter = Completer<Database>()..complete(_db!);
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbCompleter = null;
      debugPrint('[DB] Database closed');
    }
  }
}
