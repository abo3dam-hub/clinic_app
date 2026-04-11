// lib/features/invoices/data/repositories/invoice_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/invoice.dart';
import '../../../visits/domain/entities/visit.dart';

class InvoiceRepositoryImpl {
  final DatabaseHelper _db;

  InvoiceRepositoryImpl(this._db);

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

    if (fromDate != null) {
      conditions.add('i.invoice_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add('i.invoice_date <= ?');
      args.add(toDate);
    }
    if (status != null) {
      conditions.add('i.status = ?');
      args.add(status);
    }
    if (patientId != null) {
      conditions.add('i.patient_id = ?');
      args.add(patientId);
    }

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

  /// FIX #4 – Targeted single-row lookup by visit_id using the index
  /// (idx_invoices_visit). Replaces the previous full-table getAll() scan
  /// that was called on every procedure add/remove in syncInvoiceForVisit.
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
      'visit_id': invoice.visitId,
      'patient_id': invoice.patientId,
      'invoice_date': invoice.invoiceDate,
      'total_amount': invoice.totalAmount,
      'discount': invoice.discount,
      'net_amount': invoice.netAmount,
      'paid_amount': 0.0,
      'status': InvoiceStatus.unpaid.value,
      'notes': invoice.notes,
      'is_locked': 0,
      'created_at': now,
      'updated_at': now,
    };
    final id = await _db.insert('invoices', map);
    await _db.writeAuditLog(
        tableName: 'invoices', recordId: id, action: 'INSERT', newValues: map);
    return id;
  }

  /// FIX #5 – Atomic invoice + items creation inside a single transaction.
  /// Replaces the previous two-step (create → addItem loop) that had no
  /// atomicity guarantee.
  Future<int> createWithItems(
      Invoice invoice, List<VisitProcedureItem> procedures) async {
    _validate(invoice);
    return _db.runTransaction<int>((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('invoices', {
        'visit_id': invoice.visitId,
        'patient_id': invoice.patientId,
        'invoice_date': invoice.invoiceDate,
        'total_amount': invoice.totalAmount,
        'discount': 0.0,
        'net_amount': invoice.netAmount,
        'paid_amount': 0.0,
        'status': InvoiceStatus.unpaid.value,
        'notes': invoice.notes,
        'is_locked': 0,
        'created_at': now,
        'updated_at': now,
      });
      for (final p in procedures) {
        await txn.insert('invoice_items', {
          'invoice_id': id,
          'description': p.procedureName ?? 'إجراء #${p.procedureId}',
          'quantity': p.quantity,
          'unit_price': p.unitPrice,
          'discount': p.discount,
          'total': p.lineTotal,
          'created_at': now,
        });
      }
      return id;
    });
  }

  /// FIX #5 – Atomically replaces all items for an existing invoice and
  /// recalculates totals. Preserves paid_amount and derives the correct status.
  /// Called by syncInvoiceForVisit instead of the previous non-atomic loop.
  Future<void> replaceItems(int invoiceId, List<VisitProcedureItem> procedures,
      double totalAmount) async {
    await _db.runTransaction<void>((txn) async {
      // Re-read the invoice inside the transaction for consistency.
      final invRows = await txn.query('invoices',
          where: 'id = ?', whereArgs: [invoiceId], limit: 1);
      if (invRows.isEmpty) return;

      final inv = invRows.first;
      if ((inv['is_locked'] as int) == 1) {
        throw StateError('هذه الفاتورة مقفلة ولا يمكن تعديلها');
      }

      // Remove old items.
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoiceId]);

      final now = DateTime.now().toIso8601String();
      for (final p in procedures) {
        await txn.insert('invoice_items', {
          'invoice_id': invoiceId,
          'description': p.procedureName ?? 'إجراء #${p.procedureId}',
          'quantity': p.quantity,
          'unit_price': p.unitPrice,
          'discount': p.discount,
          'total': p.lineTotal,
          'created_at': now,
        });
      }

      // Recalculate totals, preserving paid_amount and deriving status.
      final discount = (inv['discount'] as num).toDouble();
      final netAmount = (totalAmount - discount).clamp(0.0, double.infinity);
      final paidAmount = (inv['paid_amount'] as num).toDouble();
      final newStatus = InvoiceStatusX.derive(paidAmount, netAmount);

      await txn.update(
        'invoices',
        {
          'total_amount': totalAmount,
          'net_amount': netAmount,
          'status': newStatus.value,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    });
  }

  /// Updates metadata-only fields (notes, dates, lock flag).
  /// Does NOT touch paid_amount or status — use [updateFinancials] for that.
  Future<void> update(Invoice invoice) async {
    assert(invoice.id != null);
    await _assertNotLocked(invoice.id!);
    _validate(invoice);
    final map = {
      'visit_id': invoice.visitId,
      'patient_id': invoice.patientId,
      'invoice_date': invoice.invoiceDate,
      'notes': invoice.notes,
      'is_locked': invoice.isLocked ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.update('invoices', map, where: 'id = ?', whereArgs: [invoice.id]);
  }

  /// FIX #6 – Dedicated method for changing discount / net_amount.
  /// Always derives and persists the correct status so the invoice can never
  /// end up in an inconsistent state (e.g. paidAmount > netAmount with
  /// status = 'unpaid' after a discount was applied).
  Future<void> updateFinancials({
    required int invoiceId,
    required double discount,
    required double netAmount,
  }) async {
    await _assertNotLocked(invoiceId);
    // Re-read paid_amount from DB to derive an accurate status.
    final rows = await _db.query('invoices',
        where: 'id = ?', whereArgs: [invoiceId], limit: 1);
    if (rows.isEmpty) throw StateError('الفاتورة غير موجودة');
    final paidAmount = (rows.first['paid_amount'] as num).toDouble();
    final newStatus = InvoiceStatusX.derive(paidAmount, netAmount);

    await _db.update(
      'invoices',
      {
        'discount': discount,
        'net_amount': netAmount,
        'status': newStatus.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> cancel(int id) async {
    await _assertNotLocked(id);
    await _db.update('invoices',
        {'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _db.writeAuditLog(
        tableName: 'invoices',
        recordId: id,
        action: 'UPDATE',
        newValues: {'status': 'cancelled'});
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
      'invoice_id': item.invoiceId,
      'description': item.description,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'discount': item.discount,
      'total': item.total,
      'created_at': DateTime.now().toIso8601String(),
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

  /// Adds a payment inside a transaction and updates invoice status.
  /// Throws [StateError] if overpayment would occur.
  Future<int> addPayment(Payment payment) async {
    return _db.runTransaction<int>((txn) async {
      // Load current invoice
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
            'مبلغ الدفعة (${payment.amount}) يتجاوز المبلغ المتبقي ($remaining)');
      }

      // Insert payment
      final now = DateTime.now().toIso8601String();
      final payMap = {
        'invoice_id': payment.invoiceId,
        'amount': payment.amount,
        'payment_date': payment.paymentDate,
        'method': payment.method.value,
        'notes': payment.notes,
        'created_at': now,
      };
      final id = await txn.insert('payments', payMap);

      // Update invoice totals using the shared derive logic.
      final newPaid = paidSoFar + payment.amount;
      final newStatus = InvoiceStatusX.derive(newPaid, netAmount);

      await txn.update(
        'invoices',
        {'paid_amount': newPaid, 'status': newStatus.value, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [payment.invoiceId],
      );

      return id;
    });
  }

  Future<void> deletePayment(int paymentId) async {
    final rows = await _db.query('payments',
        where: 'id = ?', whereArgs: [paymentId], limit: 1);
    if (rows.isEmpty) return;
    final invoiceId = rows.first['invoice_id'] as int;
    await _assertNotLocked(invoiceId);

    await _db.runTransaction<void>((txn) async {
      await txn.delete('payments', where: 'id = ?', whereArgs: [paymentId]);

      // Recalculate paid_amount
      final result = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE invoice_id = ?',
          [invoiceId]);
      final newPaid = (result.first['total'] as num).toDouble();

      final invRows = await txn.query('invoices',
          where: 'id = ?', whereArgs: [invoiceId], limit: 1);
      final netAmount = (invRows.first['net_amount'] as num).toDouble();
      final newStatus = InvoiceStatusX.derive(newPaid, netAmount);

      await txn.update(
        'invoices',
        {
          'paid_amount': newPaid,
          'status': newStatus.value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    });
  }

  // ─── Private helpers ──────────────────────────────────────────

  /// Recalculates total_amount and net_amount after item changes.
  /// Preserves paid_amount and re-derives status via [InvoiceStatusX.derive].
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

    final discount = (invRows.first['discount'] as num).toDouble();
    final paidAmount = (invRows.first['paid_amount'] as num).toDouble();
    final netAmount = (totalAmount - discount).clamp(0.0, double.infinity);
    final newStatus = InvoiceStatusX.derive(paidAmount, netAmount);

    await _db.update(
      'invoices',
      {
        'total_amount': totalAmount,
        'net_amount': netAmount,
        'status': newStatus.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
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
    if (inv.netAmount < 0)
      throw ArgumentError('صافي الفاتورة لا يمكن أن يكون سالباً');
  }
}
