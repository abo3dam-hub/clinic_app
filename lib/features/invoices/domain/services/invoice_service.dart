// lib/features/invoices/domain/services/invoice_service.dart
//
// Business logic: Appointment → Visit → Procedures → Invoice → Payments

import 'package:flutter/foundation.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import '../../domain/entities/invoice.dart';
import '../../../visits/data/repositories/visit_repository_impl.dart';
import '../../../../core/utils/date_utils.dart';

class InvoiceService {
  final InvoiceRepositoryImpl _invoiceRepo;
  final VisitRepositoryImpl _visitRepo;

  InvoiceService({
    required InvoiceRepositoryImpl invoiceRepo,
    required VisitRepositoryImpl visitRepo,
  })  : _invoiceRepo = invoiceRepo,
        _visitRepo = visitRepo;

  // ─── Auto-create invoice from visit procedures ────────────────

  /// Called after adding/removing a procedure on a visit.
  /// Creates or updates the invoice linked to [visitId].
  ///
  /// FIX #4 – Uses [getByVisitId] (indexed, single-row) instead of
  /// [getAll] (full-table scan) to locate the existing invoice.
  ///
  /// FIX #5 – All write operations are now atomic:
  ///   • New invoice → [createWithItems] (single transaction)
  ///   • Existing invoice → [replaceItems] (single transaction, preserves paid_amount)
  Future<Invoice> syncInvoiceForVisit(int visitId, int patientId) async {
    final procedures = await _visitRepo.getProceduresForVisit(visitId);

    // FIX #4: indexed single-row lookup, not a full-table scan.
    final linked = await _invoiceRepo.getByVisitId(visitId);

    if (procedures.isEmpty) {
      if (linked != null) await _invoiceRepo.cancel(linked.id!);
      return _emptyInvoice(visitId, patientId);
    }

    final totalAmount =
        procedures.fold<double>(0.0, (sum, p) => sum + p.lineTotal);

    if (linked == null) {
      // FIX #5: atomic create + item insertion in one transaction.
      final inv = Invoice(
        visitId: visitId,
        patientId: patientId,
        invoiceDate: ClinicDateUtils.todayString(),
        totalAmount: totalAmount,
        discount: 0.0,
        netAmount: totalAmount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final id = await _invoiceRepo.createWithItems(inv, procedures);
      return (await _invoiceRepo.getById(id))!;
    } else {
      // FIX #5: atomic item replacement, preserves paid_amount + status.
      await _invoiceRepo.replaceItems(linked.id!, procedures, totalAmount);
      return (await _invoiceRepo.getById(linked.id!))!;
    }
  }

  // ─── Apply discount to invoice ────────────────────────────────

  /// FIX #6 – Validates that the discount cannot push net_amount below the
  /// already-paid amount (which would create an impossible "overpaid" state).
  /// Delegates the write to [updateFinancials] which always persists the
  /// derived status, so the invoice is never left in an inconsistent state.
  Future<void> applyDiscount(int invoiceId, double discount) async {
    final inv = await _invoiceRepo.getById(invoiceId);
    if (inv == null) throw StateError('الفاتورة غير موجودة');
    if (inv.isLocked) throw StateError('الفاتورة مقفلة');
    if (discount < 0) throw ArgumentError('الخصم لا يمكن أن يكون سالباً');
    if (discount > inv.totalAmount) {
      throw ArgumentError('الخصم لا يمكن أن يتجاوز إجمالي الفاتورة');
    }

    final newNet = inv.totalAmount - discount;

    // FIX #6: guard against discount pushing net below what's already paid.
    if (newNet < inv.paidAmount - 0.001) {
      throw ArgumentError(
          'الخصم يجعل صافي الفاتورة (${newNet.toStringAsFixed(2)}) '
          'أقل من المبلغ المدفوع بالفعل (${inv.paidAmount.toStringAsFixed(2)})');
    }

    // FIX #6: use updateFinancials so status is always re-derived and saved.
    await _invoiceRepo.updateFinancials(
      invoiceId: invoiceId,
      discount: discount,
      netAmount: newNet,
    );

    debugPrint('[InvoiceService] Discount applied → invoice #$invoiceId '
        'discount=$discount net=$newNet');
  }

  // ─── Lock paid invoices ───────────────────────────────────────

  Future<void> lockIfFullyPaid(int invoiceId) async {
    final inv = await _invoiceRepo.getById(invoiceId);
    if (inv == null) return;
    if (inv.status == InvoiceStatus.paid && !inv.isLocked) {
      await _invoiceRepo.update(inv.copyWith(isLocked: true));
    }
  }

  // ─── Summary for a date range ─────────────────────────────────

  Future<InvoiceSummary> getSummary({
    required String fromDate,
    required String toDate,
  }) async {
    final invoices = await _invoiceRepo.getAll(
        fromDate: fromDate, toDate: toDate);

    double totalNet    = 0;
    double totalPaid   = 0;
    int    countPaid   = 0;
    int    countUnpaid = 0;

    for (final inv in invoices) {
      if (inv.status == InvoiceStatus.cancelled) continue;
      totalNet  += inv.netAmount;
      totalPaid += inv.paidAmount;
      if (inv.status == InvoiceStatus.paid)   countPaid++;
      if (inv.status == InvoiceStatus.unpaid) countUnpaid++;
    }

    return InvoiceSummary(
      totalNet: totalNet,
      totalPaid: totalPaid,
      totalRemaining: totalNet - totalPaid,
      countPaid: countPaid,
      countUnpaid: countUnpaid,
      countTotal: invoices.length,
    );
  }

  // ─── Private helpers ──────────────────────────────────────────

  Invoice _emptyInvoice(int visitId, int patientId) => Invoice(
        visitId: visitId,
        patientId: patientId,
        invoiceDate: ClinicDateUtils.todayString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

// ─── Value object ─────────────────────────────────────────────

class InvoiceSummary {
  final double totalNet;
  final double totalPaid;
  final double totalRemaining;
  final int countPaid;
  final int countUnpaid;
  final int countTotal;

  const InvoiceSummary({
    required this.totalNet,
    required this.totalPaid,
    required this.totalRemaining,
    required this.countPaid,
    required this.countUnpaid,
    required this.countTotal,
  });
}
