// lib/features/invoices/data/repositories/invoice_repository_impl.dart
//
// Changes vs original:
//   • Constructor takes JournalService (injected, never throws on failure)
//   • createWithItems  → fires onInvoiceCreated journal entry
//   • replaceItems     → CRITICAL guard: netAmount must not be < paidAmount
//   • addPayment       → fires onPaymentReceived journal entry
//   • deletePayment    → fires onPaymentDeleted journal entry
//   • cancel           → fires onInvoiceCancelled journal entry
//   • updateFinancials → fires onInvoiceNetChanged when net changes

import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/invoice.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../accounting/domain/services/journal_service.dart';

class InvoiceRepositoryImpl {
  final DatabaseHelper _db;
  final JournalService _journal;

  InvoiceRepositoryImpl(this._db, this._journal);

  // ─── Mapping ─────────────────────────────────────────────────

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
        patientName: m['patient_name'] as String?,
      );

  InvoiceItem _itemFromMap(Map<String, dynamic> m) => InvoiceItem(
        id: m['id'] as int,
        invoiceId: m['invoice_id'] as int,
        description: m['description'] as String,
        quantity: m['quantity'] as int,
        unitPrice: (m['unit_price'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
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

  // ─── Invoice Queries ──────────────────────────────────────────

  Future<List<Invoice>> getAll({
    String? fromDate,
    String? toDate,
    String? status,
    int? patientId,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    if (fromDate != null) { conditions.add('i.invoice_date >= ?'); args.add(fromDate); }
    if (toDate   != null) { conditions.add('i.invoice_date <= ?'); args.add(toDate);   }
    if (status   != null) { conditions.add('i.status = ?');        args.add(status);   }
    if (patientId != null){ conditions.add('i.patient_id = ?');    args.add(patientId);}
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await _db.rawQuery('''
      SELECT i.*, p.name AS patient_name
      FROM   invoices i
      JOIN   patients p ON p.id = i.patient_id
      $where
      ORDER  BY i.invoice_date DESC, i.id DESC
    ''', args);
    return rows.map(_invoiceFromMap).toList();
  }

  Future<Invoice?> getById(int id) async {
    final rows = await _db.rawQuery('''
      SELECT i.*, p.name AS patient_name
      FROM   invoices i
      JOIN   patients p ON p.id = i.patient_id
      WHERE  i.id = ?
    ''', [id]);
    return rows.isEmpty ? null : _invoiceFromMap(rows.first);
  }

  Future<Invoice?> getByVisitId(int visitId) async {
    final rows = await _db.rawQuery('''
      SELECT i.*, p.name AS patient_name
      FROM   invoices i
      JOIN   patients p ON p.id = i.patient_id
      WHERE  i.visit_id = ?
      LIMIT  1
    ''', [visitId]);
    return rows.isEmpty ? null : _invoiceFromMap(rows.first);
  }

  // ─── Invoice Write ────────────────────────────────────────────

  Future<int> create(Invoice invoice) async {
    _validate(invoice);
    final now = DateTime.now().toIso8601String();
    final map = {
      'visit_id':     invoice.visitId,
      'patient_id':   invoice.patientId,
      'invoice_date': invoice.invoiceDate,
      'total_amount': invoice.totalAmount,
      'discount':     invoice.discount,
      'net_amount':   invoice.netAmount,
      'paid_amount':  0.0,
      'status':       InvoiceStatus.unpaid.value,
      'notes':        invoice.notes,
      'is_locked':    0,
      'created_at':   now,
      'updated_at':   now,
    };
    final id = await _db.insert('invoices', map);
    await _db.writeAuditLog(
        tableName: 'invoices', recordId: id, action: 'INSERT', newValues: map);
    return id;
  }

  /// Atomic invoice + items creation. Fires journal entry after commit.
  Future<int> createWithItems(
      Invoice invoice, List<VisitProcedureItem> procedures) async {
    _validate(invoice);
    final id = await _db.runTransaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final invId = await txn.insert('invoices', {
        'visit_id':     invoice.visitId,
        'patient_id':   invoice.patientId,
        'invoice_date': invoice.invoiceDate,
        'total_amount': invoice.totalAmount,
        'discount':     0.0,
        'net_amount':   invoice.netAmount,
        'paid_amount':  0.0,
        'status':       InvoiceStatus.unpaid.value,
        'notes':        invoice.notes,
        'is_locked':    0,
        'created_at':   now,
        'updated_at':   now,
      });
      for (final p in procedures) {
        await txn.insert('invoice_items', {
          'invoice_id':  invId,
          'description': p.procedureName ?? 'إجراء #${p.procedureId}',
          'quantity':    p.quantity,
          'unit_price':  p.unitPrice,
          'discount':    p.discount,
          'total':       p.lineTotal,
          'created_at':  now,
        });
      }
      return invId;
    });

    // Journal entry: DR Accounts Receivable | CR Revenue
    final inv = await getById(id);
    if (inv != null && inv.netAmount > 0) {
      _safeJournal(() => _journal.onInvoiceCreated(
            invoiceId: id,
            netAmount: inv.netAmount,
            date: inv.invoiceDate,
            patientName: inv.patientName ?? '#${inv.patientId}',
          ));
    }
    debugPrint('[InvoiceRepo] createWithItems #$id net=${inv?.netAmount}');
    return id;
  }

  /// Atomically replaces items. Preserves paid_amount and derives status.
  /// CRITICAL: Throws StateError if new netAmount < paidAmount.
  Future<void> replaceItems(int invoiceId,
      List<VisitProcedureItem> procedures, double totalAmount) async {
    double? oldNet;
    double? newNet;

    await _db.runTransaction<void>((txn) async {
      final invRows = await txn.query('invoices',
          where: 'id = ?', whereArgs: [invoiceId], limit: 1);
      if (invRows.isEmpty) return;
      final inv = invRows.first;

      if ((inv['is_locked'] as int) == 1) {
        throw StateError('هذه الفاتورة مقفلة ولا يمكن تعديلها');
      }

      final discount   = (inv['discount']    as num).toDouble();
      final paidAmount = (inv['paid_amount'] as num).toDouble();
      oldNet = (inv['net_amount'] as num).toDouble();
      newNet = (totalAmount - discount).clamp(0.0, double.infinity);

      // ── CRITICAL GUARD ──────────────────────────────────────────
      // Prevent netAmount < paidAmount (impossible financial state).
      if (newNet! < paidAmount - 0.001) {
        throw StateError(
          'لا يمكن تعديل الفاتورة: الإجمالي الجديد '
          '(\$${newNet!.toStringAsFixed(2)}) أقل من '
          'المدفوع بالفعل (\$${paidAmount.toStringAsFixed(2)}). '
          'يرجى حذف الدفعة أولاً.');
      }

      // Replace items
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoiceId]);
      final now = DateTime.now().toIso8601String();
      for (final p in procedures) {
        await txn.insert('invoice_items', {
          'invoice_id':  invoiceId,
          'description': p.procedureName ?? 'إجراء #${p.procedureId}',
          'quantity':    p.quantity,
          'unit_price':  p.unitPrice,
          'discount':    p.discount,
          'total':       p.lineTotal,
          'created_at':  now,
        });
      }

      final newStatus = InvoiceStatusX.derive(paidAmount, newNet!);
      await txn.update('invoices', {
        'total_amount': totalAmount,
        'net_amount':   newNet,
        'status':       newStatus.value,
        'updated_at':   now,
      }, where: 'id = ?', whereArgs: [invoiceId]);
    });

    // Adjust journal if net changed
    if (oldNet != null && newNet != null) {
      final delta = newNet! - oldNet!;
      if (delta.abs() > 0.001) {
        final inv = await getById(invoiceId);
        _safeJournal(() => _journal.onInvoiceNetChanged(
              invoiceId: invoiceId,
              delta: delta,
              date: inv?.invoiceDate ?? ClinicDateUtils.todayString(),
              patientName: inv?.patientName ?? '#$invoiceId',
            ));
      }
    }
  }

  /// Updates metadata-only fields (notes, dates, lock flag).
  Future<void> update(Invoice invoice) async {
    assert(invoice.id != null);
    await _assertNotLocked(invoice.id!);
    _validate(invoice);
    await _db.update('invoices', {
      'visit_id':     invoice.visitId,
      'patient_id':   invoice.patientId,
      'invoice_date': invoice.invoiceDate,
      'notes':        invoice.notes,
      'is_locked':    invoice.isLocked ? 1 : 0,
      'updated_at':   DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [invoice.id]);
  }

  /// Updates financial fields (discount, net_amount). Derives correct status.
  Future<void> updateFinancials({
    required int invoiceId,
    required double discount,
    required double netAmount,
  }) async {
    await _assertNotLocked(invoiceId);
    final rows = await _db.query('invoices',
        where: 'id = ?', whereArgs: [invoiceId], limit: 1);
    if (rows.isEmpty) throw StateError('الفاتورة غير موجودة');

    final paidAmount = (rows.first['paid_amount'] as num).toDouble();
    final oldNet     = (rows.first['net_amount']  as num).toDouble();
    final newStatus  = InvoiceStatusX.derive(paidAmount, netAmount);

    await _db.update('invoices', {
      'discount':   discount,
      'net_amount': netAmount,
      'status':     newStatus.value,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [invoiceId]);

    // Journal: adjust AR / Revenue for the delta
    final delta = netAmount - oldNet;
    if (delta.abs() > 0.001) {
      final inv = await getById(invoiceId);
      _safeJournal(() => _journal.onInvoiceNetChanged(
            invoiceId: invoiceId,
            delta: delta,
            date: inv?.invoiceDate ?? ClinicDateUtils.todayString(),
            patientName: inv?.patientName ?? '#$invoiceId',
          ));
    }
  }

  Future<void> cancel(int id) async {
    await _assertNotLocked(id);
    final inv = await getById(id);
    await _db.update('invoices',
        {'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _db.writeAuditLog(
        tableName: 'invoices', recordId: id, action: 'UPDATE',
        newValues: {'status': 'cancelled'});

    // Reverse the original revenue recognition
    if (inv != null && inv.netAmount > 0) {
      _safeJournal(() => _journal.onInvoiceCancelled(
            invoiceId: id,
            netAmount: inv.netAmount,
            date: ClinicDateUtils.todayString(),
            patientName: inv.patientName ?? '#$id',
          ));
    }
  }

  // ─── Invoice Items ────────────────────────────────────────────

  Future<List<InvoiceItem>> getItemsForInvoice(int invoiceId) async {
    final rows = await _db.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'id ASC');
    return rows.map(_itemFromMap).toList();
  }

  Future<int> addItem(InvoiceItem item) async {
    await _assertNotLocked(item.invoiceId);
    final map = {
      'invoice_id':  item.invoiceId,
      'description': item.description,
      'quantity':    item.quantity,
      'unit_price':  item.unitPrice,
      'discount':    item.discount,
      'total':       item.total,
      'created_at':  DateTime.now().toIso8601String(),
    };
    final id = await _db.insert('invoice_items', map);
    await _recalculateInvoice(item.invoiceId);
    return id;
  }

  Future<void> removeItem(int id) async {
    final rows = await _db.query('invoice_items',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final invoiceId = rows.first['invoice_id'] as int;
    await _assertNotLocked(invoiceId);
    await _db.delete('invoice_items', where: 'id = ?', whereArgs: [id]);
    await _recalculateInvoice(invoiceId);
  }

  // ─── Payments ─────────────────────────────────────────────────

  Future<List<Payment>> getPaymentsForInvoice(int invoiceId) async {
    final rows = await _db.query('payments',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        orderBy: 'payment_date ASC');
    return rows.map(_paymentFromMap).toList();
  }

  /// Adds a payment transactionally. Fires journal entry on success.
  Future<int> addPayment(Payment payment) async {
    final id = await _db.runTransaction<int>((txn) async {
      final invRows = await txn.query('invoices',
          where: 'id = ?', whereArgs: [payment.invoiceId], limit: 1);
      if (invRows.isEmpty) throw StateError('الفاتورة غير موجودة');
      final inv = invRows.first;

      if ((inv['is_locked'] as int) == 1) {
        throw StateError('الفاتورة مقفلة');
      }
      if ((inv['status'] as String) == 'cancelled') {
        throw StateError('لا يمكن إضافة دفعة لفاتورة ملغاة');
      }

      final netAmount = (inv['net_amount'] as num).toDouble();
      final paidSoFar = (inv['paid_amount'] as num).toDouble();
      final remaining = netAmount - paidSoFar;

      if (payment.amount > remaining + 0.001) {
        throw StateError(
            'مبلغ الدفعة (\$${payment.amount.toStringAsFixed(2)}) '
            'يتجاوز المبلغ المتبقي (\$${remaining.toStringAsFixed(2)})');
      }

      final now = DateTime.now().toIso8601String();
      final payMap = {
        'invoice_id':   payment.invoiceId,
        'amount':       payment.amount,
        'payment_date': payment.paymentDate,
        'method':       payment.method.value,
        'notes':        payment.notes,
        'created_at':   now,
      };
      final payId = await txn.insert('payments', payMap);
      final newPaid  = paidSoFar + payment.amount;
      final newStatus = InvoiceStatusX.derive(newPaid, netAmount);
      await txn.update('invoices', {
        'paid_amount': newPaid,
        'status':      newStatus.value,
        'updated_at':  now,
      }, where: 'id = ?', whereArgs: [payment.invoiceId]);
      return payId;
    });

    // Journal: DR Cash | CR AR
    final inv = await getById(payment.invoiceId);
    _safeJournal(() => _journal.onPaymentReceived(
          paymentId: id,
          invoiceId: payment.invoiceId,
          amount: payment.amount,
          date: payment.paymentDate,
          patientName: inv?.patientName ?? '#${payment.invoiceId}',
        ));
    debugPrint('[InvoiceRepo] addPayment #$id amount=${payment.amount}');
    return id;
  }

  Future<void> deletePayment(int paymentId) async {
    final rows = await _db.query('payments',
        where: 'id = ?', whereArgs: [paymentId], limit: 1);
    if (rows.isEmpty) return;

    final invoiceId    = rows.first['invoice_id']   as int;
    final paymentAmount = (rows.first['amount']     as num).toDouble();
    final paymentDate   = rows.first['payment_date'] as String;
    await _assertNotLocked(invoiceId);

    await _db.runTransaction<void>((txn) async {
      await txn.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
      final result = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE invoice_id = ?',
          [invoiceId]);
      final newPaid = (result.first['total'] as num).toDouble();
      final invRows = await txn.query('invoices',
          where: 'id = ?', whereArgs: [invoiceId], limit: 1);
      final netAmount = (invRows.first['net_amount'] as num).toDouble();
      final newStatus = InvoiceStatusX.derive(newPaid, netAmount);
      await txn.update('invoices', {
        'paid_amount': newPaid,
        'status':      newStatus.value,
        'updated_at':  DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [invoiceId]);
    });

    // Journal: DR AR | CR Cash (reverse)
    final inv = await getById(invoiceId);
    _safeJournal(() => _journal.onPaymentDeleted(
          paymentId: paymentId,
          invoiceId: invoiceId,
          amount: paymentAmount,
          date: paymentDate,
          patientName: inv?.patientName ?? '#$invoiceId',
        ));
    debugPrint('[InvoiceRepo] deletePayment #$paymentId');
  }

  // ─── Private helpers ──────────────────────────────────────────

  Future<void> _recalculateInvoice(int invoiceId) async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(total), 0) AS total_amount
      FROM   invoice_items
      WHERE  invoice_id = ?
    ''', [invoiceId]);
    final totalAmount = (result.first['total_amount'] as num).toDouble();

    final invRows = await _db.query('invoices',
        where: 'id = ?', whereArgs: [invoiceId], limit: 1);
    if (invRows.isEmpty) return;

    final discount   = (invRows.first['discount']    as num).toDouble();
    final paidAmount = (invRows.first['paid_amount'] as num).toDouble();
    final netAmount  = (totalAmount - discount).clamp(0.0, double.infinity);
    final newStatus  = InvoiceStatusX.derive(paidAmount, netAmount);

    await _db.update('invoices', {
      'total_amount': totalAmount,
      'net_amount':   netAmount,
      'status':       newStatus.value,
      'updated_at':   DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [invoiceId]);
  }

  Future<void> _assertNotLocked(int invoiceId) async {
    final rows = await _db.query('invoices',
        where: 'id = ?', whereArgs: [invoiceId], limit: 1);
    if (rows.isNotEmpty && (rows.first['is_locked'] as int) == 1) {
      throw StateError('هذه الفاتورة مقفلة ولا يمكن تعديلها');
    }
  }

  void _validate(Invoice inv) {
    if (inv.invoiceDate.isEmpty) throw ArgumentError('تاريخ الفاتورة مطلوب');
    if (inv.netAmount < 0) throw ArgumentError('صافي الفاتورة لا يمكن أن يكون سالباً');
  }

  /// Fires a journal write in a fire-and-forget manner.
  /// A journal failure must NEVER roll back a committed financial write.
  void _safeJournal(Future<void> Function() fn) {
    fn().catchError((e) {
      debugPrint('[InvoiceRepo][Journal] Non-fatal journal error: $e');
    });
  }
}
