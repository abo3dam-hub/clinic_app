// lib/features/expenses/data/repositories/expense_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../../invoices/domain/entities/invoice.dart';

class ExpenseRepositoryImpl {
  final DatabaseHelper _db;

  ExpenseRepositoryImpl(this._db);

  Expense _fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int,
        category: m['category'] as String,
        description: m['description'] as String,
        amount: (m['amount'] as num).toDouble(),
        expenseDate: m['expense_date'] as String,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Future<List<Expense>> getAll({
    String? fromDate,
    String? toDate,
    String? category,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    if (fromDate != null) { conditions.add('expense_date >= ?'); args.add(fromDate); }
    if (toDate   != null) { conditions.add('expense_date <= ?'); args.add(toDate);   }
    if (category != null) { conditions.add('category = ?');      args.add(category); }

    final rows = await _db.query(
      'expenses',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expense_date DESC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<Expense?> getById(int id) async {
    final rows = await _db.query('expenses',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  Future<int> create(Expense expense) async {
    _validate(expense);
    final now = DateTime.now().toIso8601String();
    final map = {
      'category': expense.category,
      'description': expense.description,
      'amount': expense.amount,
      'expense_date': expense.expenseDate,
      'notes': expense.notes,
      'created_at': now,
      'updated_at': now,
    };
    final id = await _db.insert('expenses', map);
    await _db.writeAuditLog(
        tableName: 'expenses', recordId: id, action: 'INSERT', newValues: map);
    return id;
  }

  Future<void> update(Expense expense) async {
    assert(expense.id != null);
    _validate(expense);
    final map = {
      'category': expense.category,
      'description': expense.description,
      'amount': expense.amount,
      'expense_date': expense.expenseDate,
      'notes': expense.notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.update('expenses', map,
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<void> delete(int id) async {
    final old = await getById(id);
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    await _db.writeAuditLog(
        tableName: 'expenses',
        recordId: id,
        action: 'DELETE',
        oldValues: old != null
            ? {'category': old.category, 'amount': old.amount}
            : null);
  }

  Future<List<String>> getCategories() async {
    final rows = await _db.rawQuery(
        'SELECT DISTINCT category FROM expenses ORDER BY category ASC');
    return rows.map((r) => r['category'] as String).toList();
  }

  void _validate(Expense e) {
    if (e.description.trim().isEmpty) throw ArgumentError('وصف المصروف مطلوب');
    if (e.amount <= 0) throw ArgumentError('مبلغ المصروف يجب أن يكون أكبر من صفر');
  }
}
