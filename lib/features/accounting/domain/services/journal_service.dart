// lib/features/accounting/domain/services/journal_service.dart
//
// Auto-generates balanced double-entry journal entries for every
// financial event in the system.  Called by repositories AFTER their
// own write succeeds (inside the same outer transaction where possible).
//
// Rules:
//   Invoice created  → DR Accounts Receivable (1200) | CR Revenue (4100)
//   Payment received → DR Cash (1100)                | CR AR (1200)
//   Payment deleted  → DR AR (1200)                  | CR Cash (1100)
//   Invoice cancelled→ DR Revenue (4100)              | CR AR (1200) [reverse]
//   Expense recorded → DR Operating Expenses (5100)  | CR Cash (1100)
//   Discount applied → DR Revenue (4100)              | CR AR (1200) [delta]

import 'package:flutter/foundation.dart';
import '../../../accounting/data/repositories/ledger_repository.dart';

class JournalService {
  final LedgerRepository _ledger;

  JournalService(this._ledger);

  // ─── Invoice Created ──────────────────────────────────────────

  /// DR Accounts Receivable | CR Revenue
  Future<void> onInvoiceCreated({
    required int invoiceId,
    required double netAmount,
    required String date,
    required String patientName,
  }) async {
    if (netAmount <= 0) return;
    final ar  = await _requireAccount(LedgerRepository.codeAccountsReceivable);
    final rev = await _requireAccount(LedgerRepository.codeRevenue);

    await _ledger.postEntry(JournalEntry(
      reference:   'INV-$invoiceId',
      entryDate:   date,
      description: 'فاتورة خدمات طبية — $patientName',
      sourceType:  'invoice',
      sourceId:    invoiceId,
      lines: [
        JournalLine(entryId: 0, accountId: ar.id,  debit: netAmount, description: 'AR: $patientName'),
        JournalLine(entryId: 0, accountId: rev.id, credit: netAmount, description: 'إيراد طبي'),
      ],
    ));
    debugPrint('[Journal] onInvoiceCreated #$invoiceId amount=$netAmount');
  }

  // ─── Invoice Updated (net amount changed) ─────────────────────

  /// When a discount is applied or items change, adjust AR vs Revenue.
  /// delta = newNet - oldNet (negative if net decreased).
  Future<void> onInvoiceNetChanged({
    required int invoiceId,
    required double delta,      // newNet - oldNet
    required String date,
    required String patientName,
  }) async {
    if (delta.abs() < 0.001) return;
    final ar  = await _requireAccount(LedgerRepository.codeAccountsReceivable);
    final rev = await _requireAccount(LedgerRepository.codeRevenue);

    final List<JournalLine> lines;
    if (delta > 0) {
      // Net increased → more AR, more Revenue
      lines = [
        JournalLine(entryId: 0, accountId: ar.id,  debit:  delta, description: 'تعديل AR'),
        JournalLine(entryId: 0, accountId: rev.id, credit: delta, description: 'تعديل إيراد'),
      ];
    } else {
      // Net decreased (discount) → less AR, less Revenue
      final abs = delta.abs();
      lines = [
        JournalLine(entryId: 0, accountId: rev.id, debit:  abs, description: 'خصم من الإيراد'),
        JournalLine(entryId: 0, accountId: ar.id,  credit: abs, description: 'تخفيض AR'),
      ];
    }

    await _ledger.postEntry(JournalEntry(
      reference:   'INV-$invoiceId',
      entryDate:   date,
      description: 'تعديل فاتورة — $patientName',
      sourceType:  'invoice',
      sourceId:    invoiceId,
      lines:       lines,
    ));
  }

  // ─── Invoice Cancelled ────────────────────────────────────────

  /// DR Revenue | CR Accounts Receivable (full reversal of original)
  Future<void> onInvoiceCancelled({
    required int invoiceId,
    required double netAmount,
    required String date,
    required String patientName,
  }) async {
    if (netAmount <= 0) return;
    final ar  = await _requireAccount(LedgerRepository.codeAccountsReceivable);
    final rev = await _requireAccount(LedgerRepository.codeRevenue);

    await _ledger.postEntry(JournalEntry(
      reference:   'INV-$invoiceId-CANCEL',
      entryDate:   date,
      description: 'إلغاء فاتورة — $patientName',
      sourceType:  'invoice',
      sourceId:    invoiceId,
      lines: [
        JournalLine(entryId: 0, accountId: rev.id, debit:  netAmount, description: 'عكس إيراد'),
        JournalLine(entryId: 0, accountId: ar.id,  credit: netAmount, description: 'عكس AR'),
      ],
    ));
    debugPrint('[Journal] onInvoiceCancelled #$invoiceId amount=$netAmount');
  }

  // ─── Payment Received ─────────────────────────────────────────

  /// DR Cash | CR Accounts Receivable
  Future<void> onPaymentReceived({
    required int paymentId,
    required int invoiceId,
    required double amount,
    required String date,
    required String patientName,
  }) async {
    if (amount <= 0) return;
    final cash = await _requireAccount(LedgerRepository.codeCash);
    final ar   = await _requireAccount(LedgerRepository.codeAccountsReceivable);

    await _ledger.postEntry(JournalEntry(
      reference:   'PMT-$paymentId',
      entryDate:   date,
      description: 'دفعة — فاتورة #$invoiceId — $patientName',
      sourceType:  'payment',
      sourceId:    paymentId,
      lines: [
        JournalLine(entryId: 0, accountId: cash.id, debit:  amount, description: 'تحصيل نقدي'),
        JournalLine(entryId: 0, accountId: ar.id,   credit: amount, description: 'تسوية AR'),
      ],
    ));
    debugPrint('[Journal] onPaymentReceived #$paymentId amount=$amount');
  }

  // ─── Payment Deleted ──────────────────────────────────────────

  /// DR Accounts Receivable | CR Cash (reverse of payment)
  Future<void> onPaymentDeleted({
    required int paymentId,
    required int invoiceId,
    required double amount,
    required String date,
    required String patientName,
  }) async {
    if (amount <= 0) return;
    final cash = await _requireAccount(LedgerRepository.codeCash);
    final ar   = await _requireAccount(LedgerRepository.codeAccountsReceivable);

    await _ledger.postEntry(JournalEntry(
      reference:   'PMT-$paymentId-DEL',
      entryDate:   date,
      description: 'حذف دفعة — فاتورة #$invoiceId — $patientName',
      sourceType:  'payment',
      sourceId:    paymentId,
      lines: [
        JournalLine(entryId: 0, accountId: ar.id,   debit:  amount, description: 'عكس تسوية AR'),
        JournalLine(entryId: 0, accountId: cash.id, credit: amount, description: 'عكس تحصيل'),
      ],
    ));
    debugPrint('[Journal] onPaymentDeleted #$paymentId amount=$amount');
  }

  // ─── Expense Recorded ─────────────────────────────────────────

  /// DR Operating Expenses | CR Cash
  Future<void> onExpenseRecorded({
    required int expenseId,
    required double amount,
    required String date,
    required String description,
  }) async {
    if (amount <= 0) return;
    final exp  = await _requireAccount(LedgerRepository.codeExpenses);
    final cash = await _requireAccount(LedgerRepository.codeCash);

    await _ledger.postEntry(JournalEntry(
      reference:   'EXP-$expenseId',
      entryDate:   date,
      description: 'مصروف: $description',
      sourceType:  'expense',
      sourceId:    expenseId,
      lines: [
        JournalLine(entryId: 0, accountId: exp.id,  debit:  amount, description: description),
        JournalLine(entryId: 0, accountId: cash.id, credit: amount, description: 'صرف نقدي'),
      ],
    ));
    debugPrint('[Journal] onExpenseRecorded #$expenseId amount=$amount');
  }

  // ─── Helpers ──────────────────────────────────────────────────

  Future<Account> _requireAccount(String code) async {
    final acct = await _ledger.getAccountByCode(code);
    if (acct == null) {
      throw StateError(
          'الحساب $code غير موجود في دليل الحسابات. يرجى تشغيل تهيئة قاعدة البيانات.');
    }
    return acct;
  }
}
