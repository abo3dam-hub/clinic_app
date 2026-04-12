// lib/features/visits/data/repositories/visit_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/visit.dart';

class VisitRepositoryImpl {
  final DatabaseHelper _db;

  VisitRepositoryImpl(this._db);

  // ─── Mapping ─────────────────────────────────────────────────

  Visit _visitFromMap(Map<String, dynamic> m) => Visit(
        id: m['id'] as int,
        patientId: m['patient_id'] as int,
        doctorId: m['doctor_id'] as int,
        appointmentId: m['appointment_id'] as int?,
        visitDate: m['visit_date'] as String,
        diagnosis: m['diagnosis'] as String?,
        notes: m['notes'] as String?,
        isLocked: (m['is_locked'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        patientName: m['patient_name'] as String?,
        doctorName: m['doctor_name'] as String?,
      );

  VisitProcedureItem _procFromMap(Map<String, dynamic> m) => VisitProcedureItem(
        id: m['id'] as int,
        visitId: m['visit_id'] as int,
        procedureId: m['procedure_id'] as int,
        quantity: m['quantity'] as int,
        unitPrice: (m['unit_price'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        procedureName: m['procedure_name'] as String?,
      );

  // ─── Queries ─────────────────────────────────────────────────

  Future<List<Visit>> getAll({
    String? fromDate,
    String? toDate,
    int? patientId,
    int? doctorId,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (fromDate  != null) { conditions.add('v.visit_date >= ?'); args.add(fromDate);  }
    if (toDate    != null) { conditions.add('v.visit_date <= ?'); args.add(toDate);    }
    if (patientId != null) { conditions.add('v.patient_id = ?'); args.add(patientId); }
    if (doctorId  != null) { conditions.add('v.doctor_id  = ?'); args.add(doctorId);  }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await _db.rawQuery('''
      SELECT v.*,
             p.name AS patient_name,
             d.name AS doctor_name
      FROM   visits v
      JOIN   patients p ON p.id = v.patient_id
      JOIN   doctors  d ON d.id = v.doctor_id
      $where
      ORDER  BY v.visit_date DESC, v.id DESC
    ''', args);

    return rows.map(_visitFromMap).toList();
  }

  Future<Visit?> getById(int id) async {
    final rows = await _db.rawQuery('''
      SELECT v.*,
             p.name AS patient_name,
             d.name AS doctor_name
      FROM   visits v
      JOIN   patients p ON p.id = v.patient_id
      JOIN   doctors  d ON d.id = v.doctor_id
      WHERE  v.id = ?
    ''', [id]);
    return rows.isEmpty ? null : _visitFromMap(rows.first);
  }

  Future<int> create(Visit visit) async {
    _validate(visit);
    final map = {
      'patient_id': visit.patientId,
      'doctor_id': visit.doctorId,
      'appointment_id': visit.appointmentId,
      'visit_date': visit.visitDate,
      'diagnosis': visit.diagnosis,
      'notes': visit.notes,
      'is_locked': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final id = await _db.insert('visits', map);
    await _db.writeAuditLog(
        tableName: 'visits', recordId: id, action: 'INSERT', newValues: map);
    return id;
  }

  Future<void> update(Visit visit) async {
    assert(visit.id != null);
    await _assertNotLocked(visit.id!);
    _validate(visit);
    final map = {
      'patient_id': visit.patientId,
      'doctor_id': visit.doctorId,
      'appointment_id': visit.appointmentId,
      'visit_date': visit.visitDate,
      'diagnosis': visit.diagnosis,
      'notes': visit.notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.update('visits', map, where: 'id = ?', whereArgs: [visit.id]);
    await _db.writeAuditLog(
        tableName: 'visits',
        recordId: visit.id!,
        action: 'UPDATE',
        newValues: map);
  }

  Future<void> lock(int id) async {
    await _db.update('visits',
        {'is_locked': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    await _assertNotLocked(id);
    final old = await getById(id);
    await _db.delete('visits', where: 'id = ?', whereArgs: [id]);
    await _db.writeAuditLog(
        tableName: 'visits',
        recordId: id,
        action: 'DELETE',
        oldValues: {'id': id, 'patient_id': old?.patientId});
  }

  // ─── Visit Procedures ─────────────────────────────────────────

  Future<List<VisitProcedureItem>> getProceduresForVisit(int visitId) async {
    final rows = await _db.rawQuery('''
      SELECT vp.*, pr.name AS procedure_name
      FROM   visit_procedures vp
      JOIN   procedures pr ON pr.id = vp.procedure_id
      WHERE  vp.visit_id = ?
      ORDER  BY vp.id
    ''', [visitId]);
    return rows.map(_procFromMap).toList();
  }

  Future<int> addProcedure(VisitProcedureItem item) async {
    await _assertNotLocked(item.visitId);

    return _db.runTransaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final map = {
        'visit_id': item.visitId,
        'procedure_id': item.procedureId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'discount': item.discount,
        'notes': item.notes,
        'created_at': now,
      };
      final vpId = await txn.insert('visit_procedures', map);
      final ref = 'VISIT-${item.visitId}-PROC-$vpId';

      // 1. Auto-consume materials (from template)
      final materials = await txn.query('procedure_materials',
          where: 'procedure_id = ?', whereArgs: [item.procedureId]);

      for (final mat in materials) {
        final invId = mat['inventory_id'] as int;
        final qtyPerProc = (mat['quantity'] as num).toDouble();
        final totalToConsume = qtyPerProc * item.quantity;

        final itemRows = await txn.query('items', where: 'id = ?', whereArgs: [invId], limit: 1);
        if (itemRows.isNotEmpty) {
          final currentQty = (itemRows.first['quantity'] as num).toDouble();
          final unitCost = (itemRows.first['unit_cost'] as num).toDouble();

          await txn.insert('stock_movements', {
            'item_id': invId,
            'type': 'out',
            'quantity': totalToConsume,
            'unit_cost': unitCost,
            'reference': ref,
            'notes': 'استهلاك تلقائي: ${item.procedureName ?? "إجراءات"}',
            'movement_date': now.split('T')[0],
            'created_at': now,
          });

          await txn.update('items',
              {'quantity': currentQty - totalToConsume, 'updated_at': now},
              where: 'id = ?', whereArgs: [invId]);
        }
      }

      // 2. Ad-hoc consumables (manual selection)
      if (item.consumables != null) {
        for (final con in item.consumables!) {
          final itemRows = await txn.query('items', where: 'id = ?', whereArgs: [con.itemId], limit: 1);
          if (itemRows.isNotEmpty) {
            final currentQty = (itemRows.first['quantity'] as num).toDouble();
            await txn.insert('stock_movements', {
              'item_id': con.itemId,
              'type': 'out',
              'quantity': con.quantity,
              'unit_cost': con.unitCost,
              'reference': ref,
              'notes': 'استهلاك يدوي: ${item.procedureName ?? "إجراءات"}',
              'movement_date': now.split('T')[0],
              'created_at': now,
            });
            await txn.update('items',
                {'quantity': currentQty - con.quantity, 'updated_at': now},
                where: 'id = ?', whereArgs: [con.itemId]);
          }
        }
      }

      return vpId;
    });
  }

  Future<void> removeProcedure(int id) async {
    final rows = await _db.query('visit_procedures',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final visitId = rows.first['visit_id'] as int;
    await _assertNotLocked(visitId);

    await _db.runTransaction<void>((txn) async {
      final now = DateTime.now().toIso8601String();
      final ref = 'VISIT-$visitId-PROC-$id';

      // Find all stock movements related to this specific procedure instance
      final movements = await txn.query('stock_movements',
          where: 'reference = ?', whereArgs: [ref]);

      for (final mov in movements) {
        final itemId = mov['item_id'] as int;
        final qty = (mov['quantity'] as num).toDouble();
        final type = mov['type'] as String;

        // Reversal: if it was 'out', we add back ('in')
        if (type == 'out') {
          final itemRows = await txn.query('items', where: 'id = ?', whereArgs: [itemId], limit: 1);
          if (itemRows.isNotEmpty) {
            final currentQty = (itemRows.first['quantity'] as num).toDouble();
            await txn.update('items',
                {'quantity': currentQty + qty, 'updated_at': now},
                where: 'id = ?', whereArgs: [itemId]);

            await txn.insert('stock_movements', {
              'item_id': itemId,
              'type': 'in',
              'quantity': qty,
              'unit_cost': mov['unit_cost'],
              'reference': '$ref-REV',
              'notes': 'إلغاء إجراء: استرجاع المخزون',
              'movement_date': now.split('T')[0],
              'created_at': now,
            });
          }
        }
      }

      await txn.delete('visit_procedures', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────

  Future<void> _assertNotLocked(int visitId) async {
    final rows = await _db.query('visits',
        where: 'id = ?', whereArgs: [visitId], limit: 1);
    if (rows.isNotEmpty && (rows.first['is_locked'] as int) == 1) {
      throw StateError('هذه الزيارة مقفلة ولا يمكن تعديلها');
    }
  }

  void _validate(Visit v) {
    if (v.visitDate.isEmpty) throw ArgumentError('تاريخ الزيارة مطلوب');
  }
}
