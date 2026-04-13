// lib/features/cash_box/domain/entities/cash_box.dart

class CashBox {
  final int? id;
  final String boxDate;
  final double openingBalance;
  final double? closingBalance;
  final bool isClosed;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed
  final double totalIncome;
  final double totalExpenses;

  const CashBox({
    this.id,
    required this.boxDate,
    this.openingBalance = 0.0,
    this.closingBalance,
    this.isClosed = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
  });

  double get calculatedClosingBalance =>
      openingBalance + totalIncome - totalExpenses;
}
