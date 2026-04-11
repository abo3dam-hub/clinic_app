// lib/features/patients/data/repositories/patient_repository_impl.dart

import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';

class PatientRepositoryImpl implements PatientRepository {
  final DatabaseHelper _db;

  PatientRepositoryImpl(this._db);

  static const _table = 'patients';

  // ── Mapping ─────────────────────────────────────────────────

  Patient _fromMap(Map<String, dynamic> m) => Patient(
        id: m['id'] as int,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        birthDate: m['birth_date'] as String?,
        gender: m['gender'] as String?,
        address: m['address'] as String?,
        notes: m['notes'] as String?,
        isActive: (m['is_active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> _toMap(Patient p) => {
        'name': p.name,
        'phone': p.phone,
        'email': p.email,
        'birth_date': p.birthDate,
        'gender': p.gender,
        'address': p.address,
        'notes': p.notes,
        'is_active': p.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

  // ── Queries ─────────────────────────────────────────────────

  @override
  Future<List<Patient>> getAll({bool activeOnly = true}) async {
    try {
      final rows = await _db.query(
        _table,
        where: activeOnly ? 'is_active = ?' : null,
        whereArgs: activeOnly ? [1] : null,
        orderBy: 'name ASC',
      );
      return rows.map(_fromMap).toList();
    } catch (e) {
      debugPrint('[PatientRepo] getAll error: $e');
      rethrow;
    }
  }

  @override
  Future<Patient?> getById(int id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  @override
  Future<List<Patient>> search(String query) async {
    final like = '%$query%';
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM $_table
      WHERE (name LIKE ? OR phone LIKE ? OR email LIKE ?)
        AND is_active = 1
      ORDER BY name ASC
      ''',
      [like, like, like],
    );
    return rows.map(_fromMap).toList();
  }

  // ── Write ────────────────────────────────────────────────────

  @override
  Future<int> create(Patient patient) async {
    _validate(patient);
    final map = _toMap(patient);
    map['created_at'] = DateTime.now().toIso8601String();
    final id = await _db.insert(_table, map);
    await _db.writeAuditLog(
      tableName: _table,
      recordId: id,
      action: 'INSERT',
      newValues: map,
    );
    return id;
  }

  @override
  Future<void> update(Patient patient) async {
    assert(patient.id != null, 'Cannot update a patient without an id');
    _validate(patient);
    final old = await getById(patient.id!);
    final map = _toMap(patient);
    await _db.update(_table, map, where: 'id = ?', whereArgs: [patient.id]);
    await _db.writeAuditLog(
      tableName: _table,
      recordId: patient.id!,
      action: 'UPDATE',
      oldValues: old != null ? _toMap(old) : null,
      newValues: map,
    );
  }

  @override
  Future<void> delete(int id) async {
    final old = await getById(id);
    // Soft delete: mark inactive
    await _db.update(
      _table,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.writeAuditLog(
      tableName: _table,
      recordId: id,
      action: 'DELETE',
      oldValues: old != null ? _toMap(old) : null,
    );
  }

  // ── Validation ───────────────────────────────────────────────

  void _validate(Patient p) {
    if (p.name.trim().isEmpty) {
      throw ArgumentError('اسم المريض مطلوب');
    }
    if (p.gender != null &&
        p.gender != 'male' &&
        p.gender != 'female') {
      throw ArgumentError('الجنس يجب أن يكون male أو female');
    }
  }
}
