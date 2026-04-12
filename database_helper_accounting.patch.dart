// PATCH FILE: lib/core/database/database_helper.dart
//
// Changes from original:
//   1. _dbVersion bumped from 1 → 2
//   2. _schemaStatements() gains 3 new tables:
//        chart_of_accounts, journal_entries, journal_entry_lines
//   3. _onUpgrade() runs _seedChartOfAccounts() for v1→v2
//   4. _onCreate()  calls _seedChartOfAccounts() after table creation
//   5. New method: _seedChartOfAccounts(Database db)
//
// ─── DIFF — replace the sections below in your existing file ─────────────────

// ── 1. Bump version ──────────────────────────────────────────────────────────
// BEFORE:  static const int _dbVersion = 1;
// AFTER:
//   static const int _dbVersion = 2;

// ── 2. _onCreate: also seed COA ──────────────────────────────────────────────
// BEFORE:
//   Future<void> _onCreate(Database db, int version) async {
//     debugPrint('[DB] Creating tables (version $version)');
//     await _createAllTables(db);
//   }
//
// AFTER:
//   Future<void> _onCreate(Database db, int version) async {
//     debugPrint('[DB] Creating tables (version $version)');
//     await _createAllTables(db);
//     await _seedChartOfAccounts(db);
//   }

// ── 3. _onUpgrade: migrate v1→v2 ─────────────────────────────────────────────
// BEFORE:
//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     debugPrint('[DB] Upgrading from $oldVersion to $newVersion');
//     // Future migrations go here
//   }
//
// AFTER:
//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     debugPrint('[DB] Upgrading from $oldVersion to $newVersion');
//     if (oldVersion < 2) {
//       // Add accounting tables
//       for (final sql in _accountingSchemaStatements()) {
//         await db.execute(sql);
//       }
//       await _seedChartOfAccounts(db);
//     }
//   }

// ── 4. Split _schemaStatements — extract accounting into own method ───────────
// Add the following method alongside _schemaStatements():

/*
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

  // ── JOURNAL ENTRIES ──
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
  'CREATE INDEX IF NOT EXISTS idx_je_date        ON journal_entries(entry_date)',
  'CREATE INDEX IF NOT EXISTS idx_je_source      ON journal_entries(source_type, source_id)',

  // ── JOURNAL ENTRY LINES ──
  '''
  CREATE TABLE IF NOT EXISTS journal_entry_lines (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    entry_id    INTEGER NOT NULL,
    account_id  INTEGER NOT NULL,
    debit       REAL    NOT NULL DEFAULT 0.0,
    credit      REAL    NOT NULL DEFAULT 0.0,
    description TEXT,
    FOREIGN KEY (entry_id)   REFERENCES journal_entries(id)    ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES chart_of_accounts(id) ON DELETE RESTRICT
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_jel_entry   ON journal_entry_lines(entry_id)',
  'CREATE INDEX IF NOT EXISTS idx_jel_account ON journal_entry_lines(account_id)',
];
*/

// ── 5. Seed Chart of Accounts ─────────────────────────────────────────────────
// Add this method to DatabaseHelper:

/*
/// Seeds the standard Chart of Accounts for a medical clinic.
/// Uses INSERT OR IGNORE so it is safe to call multiple times.
Future<void> _seedChartOfAccounts(Database db) async {
  const accounts = [
    // code, name, type, sort_order
    ('1100', 'الصندوق (نقدية)',            'asset',     10),
    ('1200', 'حسابات العملاء (مدينون)',    'asset',     20),
    ('1300', 'مخزون لوازم طبية',           'asset',     30),
    ('2100', 'حسابات الموردين (دائنون)',   'liability', 40),
    ('2200', 'مصروفات مستحقة',             'liability', 50),
    ('3000', 'حقوق الملكية',               'equity',    60),
    ('3100', 'الأرباح المحتجزة',           'equity',    70),
    ('4100', 'إيراد الخدمات الطبية',       'revenue',   80),
    ('4200', 'إيرادات أخرى',               'revenue',   90),
    ('5100', 'المصروفات التشغيلية',        'expense',  100),
    ('5200', 'مصروفات الرواتب',            'expense',  110),
    ('5300', 'مصروفات الإيجار',            'expense',  120),
    ('5400', 'مصروفات الكهرباء والمياه',   'expense',  130),
    ('5500', 'مصروفات المستلزمات الطبية',  'expense',  140),
    ('5600', 'مصروفات الصيانة',            'expense',  150),
    ('5900', 'مصروفات متنوعة',             'expense',  160),
  ];
  for (final (code, name, type, order) in accounts) {
    await db.insert(
      'chart_of_accounts',
      {
        'code':       code,
        'name':       name,
        'type':       type,
        'sort_order': order,
        'is_active':  1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  debugPrint('[DB] Chart of accounts seeded (${accounts.length} accounts)');
}
*/

// ── 6. Call _accountingSchemaStatements from _schemaStatements ────────────────
// In _schemaStatements(), at the END of the list, add:
//   ..._accountingSchemaStatements(),

// ─── COMPLETE REPLACEMENT of the three modified methods ──────────────────────
// Copy the three methods below verbatim into database_helper.dart to replace
// the originals.

// Method 1: _onCreate
// ---------------------
// Future<void> _onCreate(Database db, int version) async {
//   debugPrint('[DB] Creating tables (version $version)');
//   await _createAllTables(db);
//   await _seedChartOfAccounts(db);  // ← NEW
// }

// Method 2: _onUpgrade
// ---------------------
// Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//   debugPrint('[DB] Upgrading from $oldVersion to $newVersion');
//   if (oldVersion < 2) {
//     for (final sql in _accountingSchemaStatements()) {
//       await db.execute(sql);
//     }
//     await _seedChartOfAccounts(db);
//   }
// }

// Method 3: _schemaStatements
// ----------------------------
// Append at the end of the list return value:
//   ..._accountingSchemaStatements(),

// ─────────────────────────────────────────────────────────────────────────────
// Below is the COMPLETE updated _schemaStatements() and new methods as a
// drop-in replacement section you can paste into database_helper.dart:

const String _databaseHelperAccountingPatch = '''
  // ── bump version ──────────────────────────────────────────
  static const int _dbVersion = 2;   // was 1

  // ── updated _onCreate ─────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    debugPrint("[DB] Creating tables (version \$version)");
    await _createAllTables(db);
    await _seedChartOfAccounts(db);        // ← NEW
  }

  // ── updated _onUpgrade ────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint("[DB] Upgrading from \$oldVersion to \$newVersion");
    if (oldVersion < 2) {
      for (final sql in _accountingSchemaStatements()) {
        await db.execute(sql);
      }
      await _seedChartOfAccounts(db);
    }
  }

  // ── accounting schema statements ──────────────────────────
  List<String> _accountingSchemaStatements() => [
    """
    CREATE TABLE IF NOT EXISTS chart_of_accounts (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      code       TEXT NOT NULL UNIQUE,
      name       TEXT NOT NULL,
      type       TEXT NOT NULL
                     CHECK(type IN ("asset","liability","equity","revenue","expense")),
      is_active  INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime("now"))
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_coa_code ON chart_of_accounts(code)",
    "CREATE INDEX IF NOT EXISTS idx_coa_type ON chart_of_accounts(type)",

    """
    CREATE TABLE IF NOT EXISTS journal_entries (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      reference   TEXT,
      entry_date  TEXT NOT NULL,
      description TEXT NOT NULL,
      source_type TEXT CHECK(source_type IN ("invoice","payment","expense","manual")),
      source_id   INTEGER,
      created_at  TEXT NOT NULL DEFAULT (datetime("now"))
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_je_date   ON journal_entries(entry_date)",
    "CREATE INDEX IF NOT EXISTS idx_je_source ON journal_entries(source_type, source_id)",

    """
    CREATE TABLE IF NOT EXISTS journal_entry_lines (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      entry_id    INTEGER NOT NULL,
      account_id  INTEGER NOT NULL,
      debit       REAL    NOT NULL DEFAULT 0.0,
      credit      REAL    NOT NULL DEFAULT 0.0,
      description TEXT,
      FOREIGN KEY (entry_id)   REFERENCES journal_entries(id)    ON DELETE CASCADE,
      FOREIGN KEY (account_id) REFERENCES chart_of_accounts(id) ON DELETE RESTRICT
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_jel_entry   ON journal_entry_lines(entry_id)",
    "CREATE INDEX IF NOT EXISTS idx_jel_account ON journal_entry_lines(account_id)",
  ];

  // ── seed COA ──────────────────────────────────────────────
  Future<void> _seedChartOfAccounts(Database db) async {
    const accounts = [
      ("1100", "الصندوق (نقدية)",             "asset",      10),
      ("1200", "حسابات العملاء (مدينون)",     "asset",      20),
      ("1300", "مخزون لوازم طبية",            "asset",      30),
      ("2100", "حسابات الموردين (دائنون)",    "liability",  40),
      ("2200", "مصروفات مستحقة",              "liability",  50),
      ("3000", "حقوق الملكية",                "equity",     60),
      ("3100", "الأرباح المحتجزة",            "equity",     70),
      ("4100", "إيراد الخدمات الطبية",        "revenue",    80),
      ("4200", "إيرادات أخرى",                "revenue",    90),
      ("5100", "المصروفات التشغيلية",         "expense",   100),
      ("5200", "مصروفات الرواتب",             "expense",   110),
      ("5300", "مصروفات الإيجار",             "expense",   120),
      ("5400", "مصروفات الكهرباء والمياه",    "expense",   130),
      ("5500", "مصروفات المستلزمات الطبية",   "expense",   140),
      ("5600", "مصروفات الصيانة",             "expense",   150),
      ("5900", "مصروفات متنوعة",              "expense",   160),
    ];
    for (final (code, name, type, order) in accounts) {
      await db.insert(
        "chart_of_accounts",
        {"code": code, "name": name, "type": type,
         "sort_order": order, "is_active": 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    debugPrint("[DB] Chart of accounts seeded (\${accounts.length} accounts)");
  }
''';
