// lib/features/accounting/data/repositories/ledger_repository.dart
//
// Implements Chart of Accounts (COA), Journal Entries, and all
// read-side queries needed for Trial Balance, P&L, Balance Sheet,
// and Detailed Statement (كشف الحساب التفصيلي).

import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

enum AccountType { asset, liability, equity, revenue, expense }

extension AccountTypeX on AccountType {
  String get value => name;
  static AccountType fromString(String s) => AccountType.values
      .firstWhere((e) => e.name == s, orElse: () => AccountType.asset);

  bool get normalDebit =>
      this == AccountType.asset || this == AccountType.expense;
}

class Account {
  final int id;
  final String code;
  final String name;
  final AccountType type;
  final bool isActive;
  final int sortOrder;

  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.isActive = true,
    this.sortOrder = 0,
  });
}

class JournalEntry {
  final int? id;
  final String? reference;
  final String entryDate;
  final String description;
  final String? sourceType;
  final int? sourceId;
  final List<JournalLine> lines;

  const JournalEntry({
    this.id,
    this.reference,
    required this.entryDate,
    required this.description,
    this.sourceType,
    this.sourceId,
    this.lines = const [],
  });

  bool get isBalanced {
    final totalDebit = lines.fold(0.0, (s, l) => s + l.debit);
    final totalCredit = lines.fold(0.0, (s, l) => s + l.credit);
    return (totalDebit - totalCredit).abs() < 0.001;
  }
}

class JournalLine {
  final int? id;
  final int entryId;
  final int accountId;
  final double debit;
  final double credit;
  final String? description;

  const JournalLine({
    this.id,
    required this.entryId,
    required this.accountId,
    this.debit = 0.0,
    this.credit = 0.0,
    this.description,
  });
}

// ─── Ledger Balance ───────────────────────────────────────────────────────────

class LedgerBalance {
  final Account account;
  final double totalDebit;
  final double totalCredit;

  const LedgerBalance({
    required this.account,
    required this.totalDebit,
    required this.totalCredit,
  });

  double get balance => account.type.normalDebit
      ? totalDebit - totalCredit
      : totalCredit - totalDebit;
}

// ─── Detailed Statement Entities ─────────────────────────────────────────────

enum StatementEntryType { revenue, expense }

class StatementItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;

  const StatementItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.total,
  });
}

class StatementEntry {
  final int id;
  final String date;
  final StatementEntryType type;
  final double amount;
  final String description;

  // Revenue specific
  final String? patientName;
  final String? patientPhone;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? paymentMethod;
  final int? invoiceId;
  final double? invoiceGross;
  final double? invoiceDiscount;
  final double? invoiceNet;
  final String? invoiceStatus;
  final String? visitDiagnosis;
  final List<StatementItem> invoiceItems;

  // Expense specific
  final String? expenseCategory;

  // Common
  final String? notes;
  double runningBalance;

  StatementEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.patientName,
    this.patientPhone,
    this.doctorName,
    this.doctorSpecialty,
    this.paymentMethod,
    this.invoiceId,
    this.invoiceGross,
    this.invoiceDiscount,
    this.invoiceNet,
    this.invoiceStatus,
    this.visitDiagnosis,
    this.invoiceItems = const [],
    this.expenseCategory,
    this.notes,
    this.runningBalance = 0,
  });
}

class StatementFilter {
  final String fromDate;
  final String toDate;
  final int? patientId;
  final String? patientName;
  final int? doctorId;
  final String? doctorName;

  const StatementFilter({
    required this.fromDate,
    required this.toDate,
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
  });

  @override
  bool operator ==(Object o) =>
      o is StatementFilter &&
      o.fromDate == fromDate &&
      o.toDate == toDate &&
      o.patientId == patientId &&
      o.doctorId == doctorId;

  @override
  int get hashCode => Object.hash(fromDate, toDate, patientId, doctorId);
}

class DetailedStatement {
  final StatementFilter filter;
  final List<StatementEntry> entries;
  final double totalRevenue;
  final double totalExpenses;
  double get netBalance => totalRevenue - totalExpenses;
  int get totalTransactions => entries.length;

  const DetailedStatement({
    required this.filter,
    required this.entries,
    required this.totalRevenue,
    required this.totalExpenses,
  });

  Map<String, ({double revenue, double expense})> get dailyAggregates {
    final map = <String, ({double revenue, double expense})>{};
    for (final e in entries) {
      final existing = map[e.date] ?? (revenue: 0.0, expense: 0.0);
      if (e.type == StatementEntryType.revenue) {
        map[e.date] =
            (revenue: existing.revenue + e.amount, expense: existing.expense);
      } else {
        map[e.date] =
            (revenue: existing.revenue, expense: existing.expense + e.amount);
      }
    }
    return map;
  }
}

class FilterOption {
  final int id;
  final String name;
  const FilterOption({required this.id, required this.name});
}

// ─────────────────────────────────────────────────────────────────────────────

class LedgerRepository {
  final DatabaseHelper _db;

  LedgerRepository(this._db);

  static const String codeCash = '1100';
  static const String codeAccountsReceivable = '1200';
  static const String codeRevenue = '4100';
  static const String codeExpenses = '5100';
  static const String codeRetainedEarnings = '3000';

  // ─── COA ──────────────────────────────────────────────────────

  Future<List<Account>> getAccounts({AccountType? type}) async {
    final rows = await _db.query(
      'chart_of_accounts',
      where: type != null ? 'type = ? AND is_active = 1' : 'is_active = 1',
      whereArgs: type != null ? [type.value] : null,
      orderBy: 'sort_order ASC, code ASC',
    );
    return rows.map(_accountFromMap).toList();
  }

  Future<Account?> getAccountByCode(String code) async {
    final rows = await _db.query('chart_of_accounts',
        where: 'code = ?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : _accountFromMap(rows.first);
  }

  // ─── Journal Entry Write ──────────────────────────────────────

  Future<int> postEntry(JournalEntry entry) async {
    if (!entry.isBalanced) {
      throw ArgumentError(
          'قيد اليومية غير متوازن: المجموع المدين ≠ المجموع الدائن');
    }
    return _db.runTransaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final entryId = await txn.insert('journal_entries', {
        'reference': entry.reference,
        'entry_date': entry.entryDate,
        'description': entry.description,
        'source_type': entry.sourceType,
        'source_id': entry.sourceId,
        'created_at': now,
      });
      for (final line in entry.lines) {
        await txn.insert('journal_entry_lines', {
          'entry_id': entryId,
          'account_id': line.accountId,
          'debit': line.debit,
          'credit': line.credit,
          'description': line.description,
        });
      }
      debugPrint('[Ledger] Posted entry #$entryId — ${entry.description}');
      return entryId;
    });
  }

  Future<void> reverseEntry(int originalEntryId, String date) async {
    final rows = await _db.rawQuery('''
      SELECT jel.*, je.description, je.source_type, je.source_id
      FROM   journal_entry_lines jel
      JOIN   journal_entries     je ON je.id = jel.entry_id
      WHERE  jel.entry_id = ?
    ''', [originalEntryId]);
    if (rows.isEmpty) return;

    final desc = rows.first['description'] as String;
    final lines = rows
        .map((r) => JournalLine(
              entryId: 0,
              accountId: r['account_id'] as int,
              debit: (r['credit'] as num).toDouble(),
              credit: (r['debit'] as num).toDouble(),
            ))
        .toList();

    await postEntry(JournalEntry(
      entryDate: date,
      description: 'عكس: $desc',
      sourceType: 'manual',
      lines: lines,
    ));
    debugPrint('[Ledger] Reversed entry #$originalEntryId');
  }

  // ─── Trial Balance ────────────────────────────────────────────

  Future<List<LedgerBalance>> getTrialBalance({
    String? fromDate,
    String? toDate,
  }) async {
    final dateCond = _buildDateCondition(fromDate, toDate, 'je.entry_date');
    final args = _buildDateArgs(fromDate, toDate);

    final rows = await _db.rawQuery('''
      SELECT coa.id, coa.code, coa.name, coa.type, coa.sort_order,
             COALESCE(SUM(jel.debit),  0) AS total_debit,
             COALESCE(SUM(jel.credit), 0) AS total_credit
      FROM   chart_of_accounts      coa
      LEFT JOIN journal_entry_lines jel ON jel.account_id = coa.id
      LEFT JOIN journal_entries     je  ON je.id = jel.entry_id $dateCond
      WHERE  coa.is_active = 1
      GROUP  BY coa.id
      ORDER  BY coa.sort_order ASC, coa.code ASC
    ''', args);

    return rows
        .map((r) {
          final acct = _accountFromMap(r);
          return LedgerBalance(
            account: acct,
            totalDebit: (r['total_debit'] as num).toDouble(),
            totalCredit: (r['total_credit'] as num).toDouble(),
          );
        })
        .where((b) => b.totalDebit != 0 || b.totalCredit != 0)
        .toList();
  }

  // ─── Income Statement (P&L) ───────────────────────────────────

  Future<IncomeStatement> getIncomeStatement({
    required String fromDate,
    required String toDate,
  }) async {
    final balances = await getTrialBalance(fromDate: fromDate, toDate: toDate);

    final revenue = balances
        .where((b) => b.account.type == AccountType.revenue)
        .fold(0.0, (s, b) => s + b.balance);

    final expenses = balances
        .where((b) => b.account.type == AccountType.expense)
        .fold(0.0, (s, b) => s + b.balance);

    final revenueLines = balances
        .where((b) => b.account.type == AccountType.revenue)
        .map((b) => PLLine(
            accountId: b.account.id,
            accountName: b.account.name,
            amount: b.balance))
        .toList();

    final expenseLines = balances
        .where((b) => b.account.type == AccountType.expense)
        .map((b) => PLLine(
            accountId: b.account.id,
            accountName: b.account.name,
            amount: b.balance))
        .toList();

    return IncomeStatement(
      fromDate: fromDate,
      toDate: toDate,
      totalRevenue: revenue,
      totalExpenses: expenses,
      netIncome: revenue - expenses,
      revenueLines: revenueLines,
      expenseLines: expenseLines,
    );
  }

  // ─── Balance Sheet ────────────────────────────────────────────

  Future<BalanceSheet> getBalanceSheet(String asOfDate) async {
    final balances = await getTrialBalance(toDate: asOfDate);

    double assets = 0;
    double liabilities = 0;
    double equity = 0;

    final assetLines = <BSLine>[];
    final liabilityLines = <BSLine>[];
    final equityLines = <BSLine>[];

    for (final b in balances) {
      switch (b.account.type) {
        case AccountType.asset:
          assets += b.balance;
          assetLines
              .add(BSLine(accountName: b.account.name, amount: b.balance));
          break;
        case AccountType.liability:
          liabilities += b.balance;
          liabilityLines
              .add(BSLine(accountName: b.account.name, amount: b.balance));
          break;
        case AccountType.equity:
          equity += b.balance;
          equityLines
              .add(BSLine(accountName: b.account.name, amount: b.balance));
          break;
        default:
          break;
      }
    }

    final pl =
        await getIncomeStatement(fromDate: '2000-01-01', toDate: asOfDate);
    equity += pl.netIncome;

    return BalanceSheet(
      asOfDate: asOfDate,
      totalAssets: assets,
      totalLiabilities: liabilities,
      totalEquity: equity,
      assetLines: assetLines,
      liabilityLines: liabilityLines,
      equityLines: equityLines,
      netIncome: pl.netIncome,
    );
  }

  // ─── General Ledger ───────────────────────────────────────────

  Future<List<LedgerEntry>> getGeneralLedger({
    required int accountId,
    String? fromDate,
    String? toDate,
  }) async {
    final dateCond = _buildDateCondition(fromDate, toDate, 'je.entry_date');
    final rows = await _db.rawQuery('''
      SELECT je.entry_date, je.description, je.reference,
             jel.debit, jel.credit, jel.description AS line_desc
      FROM   journal_entry_lines jel
      JOIN   journal_entries     je  ON je.id = jel.entry_id
      WHERE  jel.account_id = ? $dateCond
      ORDER  BY je.entry_date ASC, je.id ASC
    ''', [accountId, ..._buildDateArgs(fromDate, toDate)]);

    double running = 0;
    return rows.map((r) {
      final debit = (r['debit'] as num).toDouble();
      final credit = (r['credit'] as num).toDouble();
      running += debit - credit;
      return LedgerEntry(
        date: r['entry_date'] as String,
        description: r['description'] as String,
        reference: r['reference'] as String?,
        debit: debit,
        credit: credit,
        runningBalance: running,
      );
    }).toList();
  }

  // ─── Detailed Statement (كشف الحساب التفصيلي) ────────────────

  Future<DetailedStatement> getDetailedStatement(StatementFilter filter) async {
    final entries = <StatementEntry>[];

    // 1. Revenue: Payments with full join details
    final revArgs = <Object?>[filter.fromDate, filter.toDate];
    var revWhere = 'p.payment_date BETWEEN ? AND ?';

    if (filter.patientId != null) {
      revWhere += ' AND inv.patient_id = ?';
      revArgs.add(filter.patientId!);
    }
    if (filter.doctorId != null) {
      revWhere += ' AND d.id = ?';
      revArgs.add(filter.doctorId!);
    }

    final revenueRows = await _db.rawQuery('''
      SELECT
        p.id               AS payment_id,
        p.payment_date,
        p.amount           AS payment_amount,
        p.method           AS payment_method,
        p.notes            AS payment_notes,
        pat.name           AS patient_name,
        pat.phone          AS patient_phone,
        d.name             AS doctor_name,
        d.specialty        AS doctor_specialty,
        p.invoice_id,
        inv.total_amount   AS invoice_gross,
        inv.discount       AS invoice_discount,
        inv.net_amount     AS invoice_net,
        inv.status         AS invoice_status,
        v.diagnosis        AS visit_diagnosis
      FROM payments p
      JOIN   invoices inv ON inv.id = p.invoice_id
      JOIN   patients pat ON pat.id = inv.patient_id
      LEFT JOIN visits  v ON v.id   = inv.visit_id
      LEFT JOIN doctors d ON d.id   = v.doctor_id
      WHERE $revWhere
      ORDER BY p.payment_date ASC, p.id ASC
    ''', revArgs);

    for (final r in revenueRows) {
      final invoiceId = r['invoice_id'] as int;
      final paymentMethod = r['payment_method'] as String? ?? 'cash';

      // Fetch invoice line items
      final itemRows = await _db.rawQuery('''
        SELECT description, quantity, unit_price, discount, total
        FROM   invoice_items
        WHERE  invoice_id = ?
        ORDER  BY id ASC
      ''', [invoiceId]);

      final items = itemRows
          .map((i) => StatementItem(
                description: i['description'] as String,
                quantity: (i['quantity'] as num).toInt(),
                unitPrice: (i['unit_price'] as num).toDouble(),
                discount: (i['discount'] as num).toDouble(),
                total: (i['total'] as num).toDouble(),
              ))
          .toList();

      final patientName = r['patient_name'] as String? ?? '—';
      final methodAr = _paymentMethodAr(paymentMethod);
      final desc = 'دفعة $methodAr — فاتورة رقم #$invoiceId — $patientName';

      entries.add(StatementEntry(
        id: r['payment_id'] as int,
        date: r['payment_date'] as String,
        type: StatementEntryType.revenue,
        amount: (r['payment_amount'] as num).toDouble(),
        description: desc,
        patientName: patientName,
        patientPhone: r['patient_phone'] as String?,
        doctorName: r['doctor_name'] as String?,
        doctorSpecialty: r['doctor_specialty'] as String?,
        paymentMethod: paymentMethod,
        invoiceId: invoiceId,
        invoiceGross: (r['invoice_gross'] as num?)?.toDouble(),
        invoiceDiscount: (r['invoice_discount'] as num?)?.toDouble(),
        invoiceNet: (r['invoice_net'] as num?)?.toDouble(),
        invoiceStatus: r['invoice_status'] as String?,
        visitDiagnosis: r['visit_diagnosis'] as String?,
        invoiceItems: items,
        notes: r['payment_notes'] as String?,
      ));
    }

    // 2. Expenses (clinic-level, no patient/doctor filter)
    if (filter.patientId == null && filter.doctorId == null) {
      final expenseRows = await _db.rawQuery('''
        SELECT id, expense_date, amount, category, description, notes
        FROM   expenses
        WHERE  expense_date BETWEEN ? AND ?
        ORDER  BY expense_date ASC, id ASC
      ''', [filter.fromDate, filter.toDate]);

      for (final r in expenseRows) {
        final category = r['category'] as String? ?? 'عام';
        final desc = r['description'] as String;
        entries.add(StatementEntry(
          id: r['id'] as int,
          date: r['expense_date'] as String,
          type: StatementEntryType.expense,
          amount: (r['amount'] as num).toDouble(),
          description: desc,
          expenseCategory: category,
          notes: r['notes'] as String?,
        ));
      }
    }

    // 3. Sort by date, revenue before expense on same day
    entries.sort((a, b) {
      final d = a.date.compareTo(b.date);
      if (d != 0) return d;
      if (a.type == StatementEntryType.revenue &&
          b.type == StatementEntryType.expense) return -1;
      if (a.type == StatementEntryType.expense &&
          b.type == StatementEntryType.revenue) return 1;
      return a.id.compareTo(b.id);
    });

    // 4. Running balance
    double running = 0;
    for (final e in entries) {
      running += e.type == StatementEntryType.revenue ? e.amount : -e.amount;
      e.runningBalance = running;
    }

    // 5. Totals
    final totalRevenue = entries
        .where((e) => e.type == StatementEntryType.revenue)
        .fold(0.0, (s, e) => s + e.amount);
    final totalExpenses = entries
        .where((e) => e.type == StatementEntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);

    debugPrint('[Ledger] DetailedStatement: ${entries.length} entries '
        'rev=$totalRevenue exp=$totalExpenses');

    return DetailedStatement(
      filter: filter,
      entries: entries,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
    );
  }

  // ── Filter helper lists ───────────────────────────────────────

  Future<List<FilterOption>> getPatientsForFilter() async {
    final rows = await _db.query('patients',
        where: 'is_active = 1', orderBy: 'name ASC');
    return rows
        .map((r) => FilterOption(id: r['id'] as int, name: r['name'] as String))
        .toList();
  }

  Future<List<FilterOption>> getDoctorsForFilter() async {
    final rows =
        await _db.query('doctors', where: 'is_active = 1', orderBy: 'name ASC');
    return rows
        .map((r) => FilterOption(id: r['id'] as int, name: r['name'] as String))
        .toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────

  String _buildDateCondition(String? from, String? to, String col) {
    if (from != null && to != null) return 'AND $col BETWEEN ? AND ?';
    if (from != null) return 'AND $col >= ?';
    if (to != null) return 'AND $col <= ?';
    return '';
  }

  List<Object?> _buildDateArgs(String? from, String? to) {
    if (from != null && to != null) return [from, to];
    if (from != null) return [from];
    if (to != null) return [to];
    return [];
  }

  Account _accountFromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as int,
        code: m['code'] as String,
        name: m['name'] as String,
        type: AccountTypeX.fromString(m['type'] as String),
        isActive: (m['is_active'] as int? ?? 1) == 1,
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  static String _paymentMethodAr(String method) => switch (method) {
        'cash' => 'نقدي',
        'card' => 'بطاقة',
        'transfer' => 'تحويل',
        _ => 'أخرى',
      };
}

// ─── Value Objects for Reports ────────────────────────────────────────────────

class PLLine {
  final int accountId;
  final String accountName;
  final double amount;
  const PLLine(
      {required this.accountId,
      required this.accountName,
      required this.amount});
}

class IncomeStatement {
  final String fromDate;
  final String toDate;
  final double totalRevenue;
  final double totalExpenses;
  final double netIncome;
  final List<PLLine> revenueLines;
  final List<PLLine> expenseLines;

  const IncomeStatement({
    required this.fromDate,
    required this.toDate,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netIncome,
    required this.revenueLines,
    required this.expenseLines,
  });
}

class BSLine {
  final String accountName;
  final double amount;
  const BSLine({required this.accountName, required this.amount});
}

class BalanceSheet {
  final String asOfDate;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final List<BSLine> assetLines;
  final List<BSLine> liabilityLines;
  final List<BSLine> equityLines;
  final double netIncome;

  const BalanceSheet({
    required this.asOfDate,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.assetLines,
    required this.liabilityLines,
    required this.equityLines,
    required this.netIncome,
  });

  bool get isBalanced =>
      (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01;
}

class LedgerEntry {
  final String date;
  final String description;
  final String? reference;
  final double debit;
  final double credit;
  final double runningBalance;

  const LedgerEntry({
    required this.date,
    required this.description,
    this.reference,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });
}
