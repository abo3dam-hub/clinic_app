// lib/features/cash_box/data/repositories/cash_box_repository_impl.dart

import 'package:clinic_app/core/database/database_helper.dart';
import 'package:clinic_app/features/cash_box/domain/entities/cash_box.dart';

class CashBoxRepositoryImpl {
  final DatabaseHelper _db;

  CashBoxRepositoryImpl(this._db);

  CashBox _fromMap(Map<String, dynamic> m) => CashBox(
        id: m['id'] as int,
        boxDate: m['box_date'] as String,
        openingBalance: (m['opening_balance'] as num).toDouble(),
        closingBalance: m['closing_balance'] != null
            ? (m['closing_balance'] as num).toDouble()
            : null,
        isClosed: (m['is_closed'] as int) == 1,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        totalIncome: (m['total_income'] as num? ?? 0).toDouble(),
        totalExpenses: (m['total_expenses'] as num? ?? 0).toDouble(),
      );

  Future<CashBox?> getByDate(String date) async {
    final rows = await _db.rawQuery('''
      SELECT cb.*,
             COALESCE((SELECT SUM(p.amount)
                       FROM   payments p
                       WHERE  p.payment_date = cb.box_date), 0) AS total_income,
             COALESCE((SELECT SUM(e.amount)
                       FROM   expenses e
                       WHERE  e.expense_date = cb.box_date), 0) AS total_expenses
      FROM   cash_box cb
      WHERE  cb.box_date = ?
    ''', [date]);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  Future<CashBox> getOrCreateToday() async {
    final today = _today();
    final existing = await getByDate(today);
    if (existing != null) return existing;

    // Opening balance = yesterday's closing balance
    final yesterday = _dateOffset(-1);
    final prev = await getByDate(yesterday);
    final opening = prev?.closingBalance ?? prev?.calculatedClosingBalance ?? 0.0;

    final now = DateTime.now().toIso8601String();
    await _db.insert('cash_box', {
      'box_date': today,
      'opening_balance': opening,
      'is_closed': 0,
      'created_at': now,
      'updated_at': now,
    });
    return (await getByDate(today))!;
  }

  Future<int> open(CashBox cashBox) async {
    final now = DateTime.now().toIso8601String();
    return _db.insert('cash_box', {
      'box_date': cashBox.boxDate,
      'opening_balance': cashBox.openingBalance,
      'is_closed': 0,
      'notes': cashBox.notes,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> close(int id, double closingBalance) async {
    await _db.update('cash_box', {
      'closing_balance': closingBalance,
      'is_closed': 1,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CashBox>> getHistory({String? fromDate, String? toDate}) async {
    final conditions = <String>[];
    final args = <Object?>[];
    if (fromDate != null) { conditions.add('cb.box_date >= ?'); args.add(fromDate); }
    if (toDate   != null) { conditions.add('cb.box_date <= ?'); args.add(toDate);   }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await _db.rawQuery('''
      SELECT cb.*,
             COALESCE((SELECT SUM(p.amount) FROM payments p
                       WHERE p.payment_date = cb.box_date), 0) AS total_income,
             COALESCE((SELECT SUM(e.amount) FROM expenses e
                       WHERE e.expense_date = cb.box_date), 0) AS total_expenses
      FROM   cash_box cb
      $where
      ORDER  BY cb.box_date DESC
    ''', args);
    return rows.map(_fromMap).toList();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4,'0')}-'
        '${now.month.toString().padLeft(2,'0')}-'
        '${now.day.toString().padLeft(2,'0')}';
  }

  String _dateOffset(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.year.toString().padLeft(4,'0')}-'
        '${d.month.toString().padLeft(2,'0')}-'
        '${d.day.toString().padLeft(2,'0')}';
  }
}
