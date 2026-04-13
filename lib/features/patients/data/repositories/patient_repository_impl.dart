// lib/features/patients/data/repositories/patient_repository_impl.dart

import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../invoices/domain/entities/invoice.dart';

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

  // ── New Methods ──────────────────────────────────────────────

  @override
  Future<List<PatientBalance>> getPatientsWithBalances() async {
    final rows = await _db.rawQuery('''
      SELECT 
        p.id, 
        p.name, 
        (SELECT COALESCE(SUM(net_amount), 0) FROM invoices WHERE patient_id = p.id AND status != 'cancelled') - 
        (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE invoice_id IN (SELECT id FROM invoices WHERE patient_id = p.id AND status != 'cancelled')) as balance,
        (SELECT MAX(created_at) FROM visits WHERE patient_id = p.id) as last_activity
      FROM patients p
      WHERE p.is_active = 1
      GROUP BY p.id
      HAVING balance > 0
      ORDER BY balance DESC
    ''');

    return rows.map((r) => PatientBalance(
      patientId: r['id'] as int,
      patientName: r['name'] as String,
      outstandingBalance: (r['balance'] as num).toDouble(),
      lastActivityDate: r['last_activity'] != null ? DateTime.parse(r['last_activity'] as String) : null,
    )).toList();
  }

  @override
  Future<PatientProfile?> getPatientProfile(int id) async {
    final patient = await getById(id);
    if (patient == null) return null;

    // 1. Fetch Visits
    final visitRows = await _db.query(
      'visits',
      where: 'patient_id = ?',
      whereArgs: [id],
      orderBy: 'visit_date DESC',
    );

    final List<VisitWithProcedures> visitsWithProcedures = [];
    for (final vRow in visitRows) {
      final visit = _visitFromMap(vRow);
      
      // Fetch procedures for this visit
      final procRows = await _db.rawQuery('''
        SELECT vp.*, p.name as procedure_name
        FROM visit_procedures vp
        JOIN procedures p ON p.id = vp.procedure_id
        WHERE vp.visit_id = ?
      ''', [visit.id]);
      
      final procedures = procRows.map(_visitProcedureFromMap).toList();
      visitsWithProcedures.add(VisitWithProcedures(visit: visit, procedures: procedures));
    }

    // 2. Fetch Invoices
    final invoiceRows = await _db.query(
      'invoices',
      where: 'patient_id = ?',
      whereArgs: [id],
      orderBy: 'invoice_date DESC',
    );
    final invoices = invoiceRows.map(_invoiceFromMap).toList();

    // 3. Fetch Payments (linked to patient's invoices)
    final paymentRows = await _db.rawQuery('''
      SELECT p.*
      FROM payments p
      JOIN invoices i ON i.id = p.invoice_id
      WHERE i.patient_id = ?
      ORDER BY p.payment_date DESC
    ''', [id]);
    final payments = paymentRows.map(_paymentFromMap).toList();

    return PatientProfile(
      patient: patient,
      visits: visitsWithProcedures,
      invoices: invoices,
      payments: payments,
    );
  }

  // ── Extra Mappings ───────────────────────────────────────────

  Visit _visitFromMap(Map<String, dynamic> m) => Visit(
        id: m['id'] as int,
        patientId: m['patient_id'] as int,
        doctorId: m['doctor_id'] as int,
        appointmentId: m['appointment_id'] as int?,
        visitDate: DateTime.parse(m['visit_date'] as String),
        diagnosis: m['diagnosis'] as String?,
        notes: m['notes'] as String?,
        isLocked: (m['is_locked'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  VisitProcedure _visitProcedureFromMap(Map<String, dynamic> m) => VisitProcedure(
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

  Invoice _invoiceFromMap(Map<String, dynamic> m) => Invoice(
        id: m['id'] as int,
        visitId: m['visit_id'] as int?,
        patientId: m['patient_id'] as int,
        invoiceDate: m['invoice_date'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        netAmount: (m['net_amount'] as num).toDouble(),
        paidAmount: (m['paid_amount'] as num).toDouble(),
        status: InvoiceStatusX.fromString(m['status'] as String),
        notes: m['notes'] as String?,
        isLocked: (m['is_locked'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Payment _paymentFromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as int,
        invoiceId: m['invoice_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        paymentDate: m['payment_date'] as String,
        method: PaymentMethodX.fromString(m['method'] as String),
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

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
