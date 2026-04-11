// lib/features/procedures/data/repositories/procedure_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/procedure.dart';

class ProcedureRepositoryImpl {
  final DatabaseHelper _db;

  ProcedureRepositoryImpl(this._db);

  static const _table = 'procedures';

  // ─── Mapping ─────────────────────────────────────────────────

  Procedure _fromMap(Map<String, dynamic> m) => Procedure(
        id:           m['id'] as int,
        name:         m['name'] as String,
        description:  m['description'] as String?,
        defaultPrice: (m['default_price'] as num).toDouble(),
        isActive:     (m['is_active'] as int) == 1,
        createdAt:    DateTime.parse(m['created_at'] as String),
        updatedAt:    DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _toMap(Procedure p) => {
        'name':          p.name,
        'description':   p.description,
        'default_price': p.defaultPrice,
        'is_active':     p.isActive ? 1 : 0,
        'updated_at':    DateTime.now().toIso8601String(),
      };

  // ─── Queries ─────────────────────────────────────────────────

  Future<List<Procedure>> getAll({bool activeOnly = false}) async {
    final rows = await _db.query(
      _table,
      where:     activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy:   'name ASC',
    );
    return rows.map(_fromMap).toList();
  }

  Future<List<Procedure>> search(String query) async {
    final like = '%$query%';
    final rows = await _db.rawQuery('''
      SELECT * FROM $_table
      WHERE  name LIKE ? OR description LIKE ?
      ORDER  BY name ASC
    ''', [like, like]);
    return rows.map(_fromMap).toList();
  }

  Future<Procedure?> getById(int id) async {
    final rows = await _db.query(_table,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  // ─── Write ────────────────────────────────────────────────────

  Future<int> create(Procedure procedure) async {
    _validate(procedure);
    final now = DateTime.now().toIso8601String();
    final map = _toMap(procedure)..['created_at'] = now;
    final id  = await _db.insert(_table, map);
    await _db.writeAuditLog(
        tableName: _table, recordId: id,
        action: 'INSERT', newValues: map);
    return id;
  }

  Future<void> update(Procedure procedure) async {
    assert(procedure.id != null);
    _validate(procedure);
    final old = await getById(procedure.id!);
    final map = _toMap(procedure);
    await _db.update(_table, map,
        where: 'id = ?', whereArgs: [procedure.id]);
    await _db.writeAuditLog(
        tableName: _table, recordId: procedure.id!,
        action: 'UPDATE',
        oldValues: old != null ? _toMap(old) : null,
        newValues: map);
  }

  Future<void> toggleActive(int id, {required bool active}) async {
    await _db.update(_table,
        {'is_active': active ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final old = await getById(id);
    // Check if used in visit_procedures
    final used = await _db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM visit_procedures WHERE procedure_id = ?', [id]);
    final cnt = (used.first['cnt'] as int? ?? 0);
    if (cnt > 0) throw StateError('لا يمكن حذف هذا الإجراء لأنه مستخدم في $cnt زيارة');
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _db.writeAuditLog(
        tableName: _table, recordId: id, action: 'DELETE',
        oldValues: old != null ? _toMap(old) : null);
  }

  void _validate(Procedure p) {
    if (p.name.trim().isEmpty)  throw ArgumentError('اسم الإجراء مطلوب');
    if (p.defaultPrice < 0)     throw ArgumentError('السعر لا يمكن أن يكون سالباً');
  }
}
