// lib/features/appointments/data/repositories/appointment_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/appointment.dart';

class AppointmentRepositoryImpl {
  final DatabaseHelper _db;

  AppointmentRepositoryImpl(this._db);

  static const _table = 'appointments';

  // ─── Mapping ─────────────────────────────────────────────────

  Appointment _fromMap(Map<String, dynamic> m) => Appointment(
        id:          m['id'] as int,
        patientId:   m['patient_id'] as int,
        doctorId:    m['doctor_id'] as int,
        scheduledAt: m['scheduled_at'] as String,
        status: AppointmentStatusX.fromString(m['status'] as String),
        notes:       m['notes'] as String?,
        createdAt:   DateTime.parse(m['created_at'] as String),
        updatedAt:   DateTime.parse(m['updated_at'] as String),
        patientName: m['patient_name'] as String?,
        doctorName:  m['doctor_name'] as String?,
      );

  Map<String, dynamic> _toMap(Appointment a) => {
        'patient_id':   a.patientId,
        'doctor_id':    a.doctorId,
        'scheduled_at': a.scheduledAt,
        'status':       a.status.value,
        'notes':        a.notes,
        'updated_at':   DateTime.now().toIso8601String(),
      };

  // ─── Queries ─────────────────────────────────────────────────

  /// Get all appointments with optional filters.
  Future<List<Appointment>> getAll({
    String? date,
    String? fromDate,
    String? toDate,
    int? doctorId,
    String? status,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (date != null) {
      conditions.add("date(a.scheduled_at) = ?");
      args.add(date);
    }
    if (fromDate != null) {
      conditions.add("date(a.scheduled_at) >= ?");
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add("date(a.scheduled_at) <= ?");
      args.add(toDate);
    }
    if (doctorId != null) {
      conditions.add('a.doctor_id = ?');
      args.add(doctorId);
    }
    if (status != null) {
      conditions.add('a.status = ?');
      args.add(status);
    }

    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await _db.rawQuery('''
      SELECT a.*,
             p.name AS patient_name,
             d.name AS doctor_name
      FROM   appointments a
      JOIN   patients p ON p.id = a.patient_id
      JOIN   doctors  d ON d.id = a.doctor_id
      $where
      ORDER  BY a.scheduled_at ASC
    ''', args);

    return rows.map(_fromMap).toList();
  }

  Future<Appointment?> getById(int id) async {
    final rows = await _db.rawQuery('''
      SELECT a.*,
             p.name AS patient_name,
             d.name AS doctor_name
      FROM   appointments a
      JOIN   patients p ON p.id = a.patient_id
      JOIN   doctors  d ON d.id = a.doctor_id
      WHERE  a.id = ?
    ''', [id]);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  /// Returns appointments scheduled for today.
  Future<List<Appointment>> getToday() async {
    final today = _dateStr(DateTime.now());
    return getAll(date: today);
  }

  /// Returns count of appointments by status for today.
  Future<Map<String, int>> getTodayCounts() async {
    final today = _dateStr(DateTime.now());
    final rows = await _db.rawQuery('''
      SELECT status, COUNT(*) AS cnt
      FROM   appointments
      WHERE  date(scheduled_at) = ?
      GROUP  BY status
    ''', [today]);

    return {for (final r in rows) r['status'] as String: r['cnt'] as int};
  }

  // ─── Write ────────────────────────────────────────────────────

  Future<int> create(Appointment appointment) async {
    _validate(appointment);
    final now = DateTime.now().toIso8601String();
    final map = _toMap(appointment)..['created_at'] = now;
    final id  = await _db.insert(_table, map);
    await _db.writeAuditLog(
      tableName: _table,
      recordId:  id,
      action:    'INSERT',
      newValues: map,
    );
    return id;
  }

  Future<void> update(Appointment appointment) async {
    assert(appointment.id != null, 'id is required for update');
    _validate(appointment);
    final old = await getById(appointment.id!);
    final map = _toMap(appointment);
    await _db.update(_table, map,
        where: 'id = ?', whereArgs: [appointment.id]);
    await _db.writeAuditLog(
      tableName: _table,
      recordId:  appointment.id!,
      action:    'UPDATE',
      oldValues: old != null ? _toMap(old) : null,
      newValues: map,
    );
  }

  /// Update only the status field.
  Future<void> updateStatus(int id, AppointmentStatus status) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
      _table,
      {'status': status.value, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.writeAuditLog(
      tableName: _table,
      recordId:  id,
      action:    'UPDATE',
      newValues: {'status': status.value},
    );
  }

  Future<void> delete(int id) async {
    final old = await getById(id);
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _db.writeAuditLog(
      tableName: _table,
      recordId:  id,
      action:    'DELETE',
      oldValues: old != null ? _toMap(old) : null,
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────

  void _validate(Appointment a) {
    if (a.scheduledAt.isEmpty) throw ArgumentError('وقت الموعد مطلوب');
  }

  String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
