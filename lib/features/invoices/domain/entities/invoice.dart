// lib/features/invoices/domain/entities/invoice.dart

enum InvoiceStatus { unpaid, partial, paid, cancelled }

extension InvoiceStatusX on InvoiceStatus {
  String get value => name;
  String get label {
    switch (this) {
      case InvoiceStatus.unpaid:     return 'غير مدفوعة';
      case InvoiceStatus.partial:    return 'مدفوعة جزئياً';
      case InvoiceStatus.paid:       return 'مدفوعة';
      case InvoiceStatus.cancelled:  return 'ملغاة';
    }
  }

  static InvoiceStatus fromString(String s) =>
      InvoiceStatus.values.firstWhere((e) => e.name == s,
          orElse: () => InvoiceStatus.unpaid);

  /// Single source of truth for deriving invoice status from financial amounts.
  /// Used by: addPayment, deletePayment, replaceItems, updateFinancials.
  /// [paid]  – current paid_amount
  /// [net]   – current net_amount (after discount)
  static InvoiceStatus derive(double paid, double net) {
    if (paid <= 0)            return InvoiceStatus.unpaid;
    if (paid >= net - 0.001)  return InvoiceStatus.paid;
    return InvoiceStatus.partial;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class Invoice {
  final int? id;
  final int? visitId;
  final int patientId;
  final String invoiceDate;
  final double totalAmount;
  final double discount;
  final double netAmount;
  final double paidAmount;
  final InvoiceStatus status;
  final String? notes;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final String? patientName;

  const Invoice({
    this.id,
    this.visitId,
    required this.patientId,
    required this.invoiceDate,
    this.totalAmount = 0.0,
    this.discount = 0.0,
    this.netAmount = 0.0,
    this.paidAmount = 0.0,
    this.status = InvoiceStatus.unpaid,
    this.notes,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
  });

  double get remainingAmount => netAmount - paidAmount;

  Invoice copyWith({
    int? id,
    int? visitId,
    int? patientId,
    String? invoiceDate,
    double? totalAmount,
    double? discount,
    double? netAmount,
    double? paidAmount,
    InvoiceStatus? status,
    String? notes,
    bool? isLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName,
  }) =>
      Invoice(
        id: id ?? this.id,
        visitId: visitId ?? this.visitId,
        patientId: patientId ?? this.patientId,
        invoiceDate: invoiceDate ?? this.invoiceDate,
        totalAmount: totalAmount ?? this.totalAmount,
        discount: discount ?? this.discount,
        netAmount: netAmount ?? this.netAmount,
        paidAmount: paidAmount ?? this.paidAmount,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        isLocked: isLocked ?? this.isLocked,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        patientName: patientName ?? this.patientName,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class InvoiceItem {
  final int? id;
  final int invoiceId;
  final String description;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final DateTime createdAt;

  const InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0.0,
    required this.total,
    required this.createdAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

enum PaymentMethod { cash, card, transfer, other }

extension PaymentMethodX on PaymentMethod {
  String get value => name;
  String get label {
    switch (this) {
      case PaymentMethod.cash:     return 'نقدي';
      case PaymentMethod.card:     return 'بطاقة';
      case PaymentMethod.transfer: return 'تحويل';
      case PaymentMethod.other:    return 'أخرى';
    }
  }

  static PaymentMethod fromString(String s) =>
      PaymentMethod.values.firstWhere((e) => e.name == s,
          orElse: () => PaymentMethod.cash);
}

class Payment {
  final int? id;
  final int invoiceId;
  final double amount;
  final String paymentDate;
  final PaymentMethod method;
  final String? notes;
  final DateTime createdAt;

  const Payment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    this.method = PaymentMethod.cash,
    this.notes,
    required this.createdAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class Expense {
  final int? id;
  final String category;
  final String description;
  final double amount;
  final String expenseDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    int? id,
    String? category,
    String? description,
    double? amount,
    String? expenseDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Expense(
        id: id ?? this.id,
        category: category ?? this.category,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        expenseDate: expenseDate ?? this.expenseDate,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
