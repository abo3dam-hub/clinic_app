// PATCH: lib/features/invoices/data/repositories/invoice_repository_impl.dart
//
// Changes:
//   1. addPayment → call JournalService.onPaymentReceived after success
//   2. deletePayment → call JournalService.onPaymentDeleted after success
//   3. cancel → call JournalService.onInvoiceCancelled
//   4. createWithItems → call JournalService.onInvoiceCreated
//   5. replaceItems → guard netAmount < paidAmount (InvalidState prevention)
//   6. updateFinancials → call JournalService.onInvoiceNetChanged
//
// ─────────────────────────────────────────────────────────────────────────────
// The InvoiceRepositoryImpl constructor takes a JournalService:
//
//   class InvoiceRepositoryImpl {
//     final DatabaseHelper _db;
//     final JournalService _journal;
//
//     InvoiceRepositoryImpl(this._db, this._journal);   // ← add _journal
//
// Update repository_providers.dart:
//   final invoiceRepositoryProvider = Provider<InvoiceRepositoryImpl>(
//       (ref) => InvoiceRepositoryImpl(
//           ref.watch(databaseHelperProvider),
//           ref.watch(journalServiceProvider)));    // ← pass journal service
//
// ─────────────────────────────────────────────────────────────────────────────

// ─── createWithItems (add journal entry AFTER transaction) ───────────────────
//
// After the existing transaction returns `id`, append:
//
//   // Fetch patient name for journal description
//   final inv = await getById(id);
//   unawaited(_journal.onInvoiceCreated(
//     invoiceId: id,
//     netAmount: invoice.netAmount,
//     date: invoice.invoiceDate,
//     patientName: inv?.patientName ?? 'مريض #${invoice.patientId}',
//   ));
//   return id;
//
// Use `unawaited` (import 'package:meta/meta.dart' or use ignore) so a
// journal failure never rolls back the already-committed invoice transaction.
// Alternatively, wrap in try/catch and log:
//
//   try {
//     await _journal.onInvoiceCreated(...);
//   } catch (e) {
//     debugPrint('[InvoiceRepo] Journal write failed: $e');
//   }

// ─── replaceItems — add CRITICAL guard ───────────────────────────────────────
//
// Inside replaceItems(), after computing netAmount, add:
//
//   final paidAmount = (inv['paid_amount'] as num).toDouble();
//   // CRITICAL: Prevent netAmount < paidAmount (invalid financial state)
//   if (netAmount < paidAmount - 0.001) {
//     throw StateError(
//       'لا يمكن تعديل الفاتورة: المبلغ الجديد (\$${netAmount.toStringAsFixed(2)}) '
//       'أقل من المبلغ المدفوع بالفعل (\$${paidAmount.toStringAsFixed(2)}). '
//       'يرجى حذف الدفعة أولاً.');
//   }

// ─── addPayment — trigger journal ────────────────────────────────────────────
//
// After the transaction `return id;`, add:
//
//   final inv = await getById(payment.invoiceId);
//   try {
//     await _journal.onPaymentReceived(
//       paymentId: id,
//       invoiceId: payment.invoiceId,
//       amount: payment.amount,
//       date: payment.paymentDate,
//       patientName: inv?.patientName ?? '#${payment.invoiceId}',
//     );
//   } catch (e) {
//     debugPrint('[InvoiceRepo] Journal write failed (payment): $e');
//   }
//   return id;

// ─── deletePayment — trigger journal ─────────────────────────────────────────
//
// Before the existing `await _db.runTransaction...`, read the payment:
//   final payRows = await _db.query('payments', where: 'id = ?', whereArgs: [paymentId], limit: 1);
//   final paymentAmount = (payRows.first['amount'] as num).toDouble();
//   final paymentDate   =  payRows.first['payment_date'] as String;
//
// After the transaction completes:
//   final inv = await getById(invoiceId);
//   try {
//     await _journal.onPaymentDeleted(
//       paymentId: paymentId,
//       invoiceId: invoiceId,
//       amount: paymentAmount,
//       date: paymentDate,
//       patientName: inv?.patientName ?? '#$invoiceId',
//     );
//   } catch (e) {
//     debugPrint('[InvoiceRepo] Journal write failed (delete payment): $e');
//   }

// ─── cancel — trigger journal ─────────────────────────────────────────────────
//
// Before the update, read the invoice:
//   final inv = await getById(id);
//
// After the update:
//   try {
//     await _journal.onInvoiceCancelled(
//       invoiceId: id,
//       netAmount: inv?.netAmount ?? 0,
//       date: ClinicDateUtils.todayString(),
//       patientName: inv?.patientName ?? '#$id',
//     );
//   } catch (e) {
//     debugPrint('[InvoiceRepo] Journal write failed (cancel): $e');
//   }

// ─────────────────────────────────────────────────────────────────────────────

// PATCH: lib/features/expenses/data/repositories/expense_repository_impl.dart
//
// Add JournalService parameter and call onExpenseRecorded after create():
//
//   Future<int> create(Expense expense) async {
//     final id = await _db.insert('expenses', map);
//     try {
//       await _journal.onExpenseRecorded(
//         expenseId: id,
//         amount: expense.amount,
//         date: expense.expenseDate,
//         description: expense.description,
//       );
//     } catch (e) {
//       debugPrint('[ExpenseRepo] Journal write failed: $e');
//     }
//     return id;
//   }
