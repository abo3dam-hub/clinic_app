// lib/features/doctors/data/repositories/doctor_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  final DatabaseHelper _db;

  DoctorRepositoryImpl(this._db);

  static const _table = 'doctors';

  Doctor _fromMap(Map<String, dynamic> m) => Doctor(
        id: m['id'] as int,
        name: m['name'] as String,
        specialty: m['specialty'] as String?,
        phone: m['phone'] as String?,
        commissionPct: (m['commission_pct'] as num).toDouble(),
        isActive: (m['is_active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _toMap(Doctor d) => {
        'name': d.name,
        'specialty': d.specialty,
        'phone': d.phone,
        'commission_pct': d.commissionPct,
        'is_active': d.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

  @override
  Future<List<Doctor>> getAll({bool activeOnly = true}) async {
    final rows = await _db.query(
      _table,
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return rows.map(_fromMap).toList();
  }

  @override
  Future<Doctor?> getById(int id) async {
    final rows = await _db.query(_table,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  @override
  Future<int> create(Doctor doctor) async {
    _validate(doctor);
    final map = _toMap(doctor);
    map['created_at'] = DateTime.now().toIso8601String();
    final id = await _db.insert(_table, map);
    await _db.writeAuditLog(
        tableName: _table, recordId: id, action: 'INSERT', newValues: map);
    return id;
  }

  @override
  Future<void> update(Doctor doctor) async {
    assert(doctor.id != null);
    _validate(doctor);
    final old = await getById(doctor.id!);
    final map = _toMap(doctor);
    await _db.update(_table, map,
        where: 'id = ?', whereArgs: [doctor.id]);
    await _db.writeAuditLog(
        tableName: _table,
        recordId: doctor.id!,
        action: 'UPDATE',
        oldValues: old != null ? _toMap(old) : null,
        newValues: map);
  }

  @override
  Future<void> delete(int id) async {
    final old = await getById(id);
    await _db.update(_table,
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id]);
    await _db.writeAuditLog(
        tableName: _table,
        recordId: id,
        action: 'DELETE',
        oldValues: old != null ? _toMap(old) : null);
  }

  void _validate(Doctor d) {
    if (d.name.trim().isEmpty) throw ArgumentError('اسم الطبيب مطلوب');
    if (d.commissionPct < 0 || d.commissionPct > 100) {
      throw ArgumentError('نسبة العمولة يجب أن تكون بين 0 و 100');
    }
  }
}
