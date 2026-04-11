// lib/features/accounting/data/repositories/ledger_repository.dart
//
// Implements Chart of Accounts (COA), Journal Entries, and all
// read-side queries needed for Trial Balance, P&L, and Balance Sheet.
// Every financial mutation in the app routes through JournalService
// which calls this repository.

import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

enum AccountType { asset, liability, equity, revenue, expense }

extension AccountTypeX on AccountType {
  String get value => name;
  static AccountType fromString(String s) =>
      AccountType.values.firstWhere((e) => e.name == s,
          orElse: () => AccountType.asset);

  /// Normal balance side for this account type.
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
  final String? sourceType; // 'invoice'|'payment'|'expense'|'manual'
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

  /// Validates that debits == credits (double-entry invariant).
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

// ─── Ledger Balance (aggregated per account) ──────────────────────────────────

class LedgerBalance {
  final Account account;
  final double totalDebit;
  final double totalCredit;

  const LedgerBalance({
    required this.account,
    required this.totalDebit,
    required this.totalCredit,
  });

  /// Net balance in normal direction (positive = healthy).
  double get balance => account.type.normalDebit
      ? totalDebit - totalCredit   // Asset / Expense: DR normal
      : totalCredit - totalDebit;  // Liability / Equity / Revenue: CR normal
}

// ─────────────────────────────────────────────────────────────────────────────

class LedgerRepository {
  final DatabaseHelper _db;

  LedgerRepository(this._db);

  // ─── Well-known account codes ─────────────────────────────────
  static const String codeCash               = '1100';
  static const String codeAccountsReceivable = '1200';
  static const String codeRevenue            = '4100';
  static const String codeExpenses           = '5100';
  static const String codeRetainedEarnings   = '3000';

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

  /// Inserts a balanced journal entry (header + lines) atomically.
  /// Throws [ArgumentError] if the entry is not balanced.
  Future<int> postEntry(JournalEntry entry) async {
    if (!entry.isBalanced) {
      throw ArgumentError(
          'قيد اليومية غير متوازن: المجموع المدين ≠ المجموع الدائن');
    }
    return _db.runTransaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final entryId = await txn.insert('journal_entries', {
        'reference':   entry.reference,
        'entry_date':  entry.entryDate,
        'description': entry.description,
        'source_type': entry.sourceType,
        'source_id':   entry.sourceId,
        'created_at':  now,
      });
      for (final line in entry.lines) {
        await txn.insert('journal_entry_lines', {
          'entry_id':    entryId,
          'account_id':  line.accountId,
          'debit':       line.debit,
          'credit':      line.credit,
          'description': line.description,
        });
      }
      debugPrint('[Ledger] Posted entry #$entryId — ${entry.description}');
      return entryId;
    });
  }

  /// Reverse a previously posted entry (e.g. on invoice cancellation).
  Future<void> reverseEntry(int originalEntryId, String date) async {
    final rows = await _db.rawQuery('''
      SELECT jel.*, je.description, je.source_type, je.source_id
      FROM   journal_entry_lines jel
      JOIN   journal_entries     je ON je.id = jel.entry_id
      WHERE  jel.entry_id = ?
    ''', [originalEntryId]);
    if (rows.isEmpty) return;

    final desc = rows.first['description'] as String;
    final lines = rows.map((r) => JournalLine(
          entryId: 0,
          accountId: r['account_id'] as int,
          debit: (r['credit'] as num).toDouble(),   // swap
          credit: (r['debit'] as num).toDouble(),   // swap
        )).toList();

    await postEntry(JournalEntry(
      entryDate: date,
      description: 'عكس: $desc',
      sourceType: 'manual',
      lines: lines,
    ));
    debugPrint('[Ledger] Reversed entry #$originalEntryId');
  }

  // ─── Trial Balance ────────────────────────────────────────────

  /// Returns all accounts with their aggregated debit / credit totals
  /// for the given date range (inclusive). Excludes zero-balance accounts.
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
        .map((b) => PLLine(accountName: b.account.name, amount: b.balance))
        .toList();

    final expenseLines = balances
        .where((b) => b.account.type == AccountType.expense)
        .map((b) => PLLine(accountName: b.account.name, amount: b.balance))
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
    // Include all entries up to and including asOfDate
    final balances = await getTrialBalance(toDate: asOfDate);

    double assets      = 0;
    double liabilities = 0;
    double equity      = 0;

    final assetLines      = <BSLine>[];
    final liabilityLines  = <BSLine>[];
    final equityLines     = <BSLine>[];

    for (final b in balances) {
      switch (b.account.type) {
        case AccountType.asset:
          assets += b.balance;
          assetLines.add(BSLine(accountName: b.account.name, amount: b.balance));
          break;
        case AccountType.liability:
          liabilities += b.balance;
          liabilityLines.add(BSLine(accountName: b.account.name, amount: b.balance));
          break;
        case AccountType.equity:
          equity += b.balance;
          equityLines.add(BSLine(accountName: b.account.name, amount: b.balance));
          break;
        default:
          break; // Revenue / Expense roll into retained earnings separately
      }
    }

    // Net income from inception to asOfDate rolls into equity
    final pl = await getIncomeStatement(fromDate: '2000-01-01', toDate: asOfDate);
    equity += pl.netIncome;

    return BalanceSheet(
      asOfDate: asOfDate,
      totalAssets: assets,
      totalLiabilities: liabilities,
      totalEquity: equity + pl.netIncome,
      assetLines: assetLines,
      liabilityLines: liabilityLines,
      equityLines: equityLines,
      netIncome: pl.netIncome,
    );
  }

  // ─── General Ledger ───────────────────────────────────────────

  /// Returns all journal entry lines for a given account, optionally
  /// filtered by date range.
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
      final debit  = (r['debit']  as num).toDouble();
      final credit = (r['credit'] as num).toDouble();
      running += debit - credit; // for asset/expense; caller can flip sign
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

  // ─── Helpers ──────────────────────────────────────────────────

  String _buildDateCondition(String? from, String? to, String col) {
    if (from != null && to != null) return 'AND $col BETWEEN ? AND ?';
    if (from != null) return 'AND $col >= ?';
    if (to   != null) return 'AND $col <= ?';
    return '';
  }

  List<Object?> _buildDateArgs(String? from, String? to) {
    if (from != null && to != null) return [from, to];
    if (from != null) return [from];
    if (to   != null) return [to];
    return [];
  }

  Account _accountFromMap(Map<String, dynamic> m) => Account(
        id:        m['id'] as int,
        code:      m['code'] as String,
        name:      m['name'] as String,
        type:      AccountTypeX.fromString(m['type'] as String),
        isActive:  (m['is_active'] as int? ?? 1) == 1,
        sortOrder: m['sort_order'] as int? ?? 0,
      );
}

// ─── Value Objects for Reports ────────────────────────────────────────────────

class PLLine {
  final String accountName;
  final double amount;
  const PLLine({required this.accountName, required this.amount});
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
  final double netIncome; // current-period net income included in equity

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

  /// Assets = Liabilities + Equity (accounting equation check).
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
