// lib/features/inventory/domain/entities/inventory.dart

class InventoryItem {
  final int? id;
  final String name;
  final String? unit;
  final double minQuantity;
  final double quantity;
  final double unitCost;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InventoryItem({
    this.id,
    required this.name,
    this.unit,
    this.minQuantity = 0.0,
    this.quantity = 0.0,
    this.unitCost = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBelowMinimum => quantity < minQuantity;

  InventoryItem copyWith({
    int? id,
    String? name,
    String? unit,
    double? minQuantity,
    double? quantity,
    double? unitCost,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      InventoryItem(
        id: id ?? this.id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        minQuantity: minQuantity ?? this.minQuantity,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

enum StockMovementType { inward, outward, adjustment }

extension StockMovementTypeX on StockMovementType {
  String get value {
    switch (this) {
      case StockMovementType.inward:     return 'in';
      case StockMovementType.outward:    return 'out';
      case StockMovementType.adjustment: return 'adjustment';
    }
  }

  static StockMovementType fromString(String s) {
    switch (s) {
      case 'in':         return StockMovementType.inward;
      case 'out':        return StockMovementType.outward;
      default:           return StockMovementType.adjustment;
    }
  }
}

class StockMovement {
  final int? id;
  final int itemId;
  final StockMovementType type;
  final double quantity;
  final double? unitCost;
  final String? reference;
  final String? notes;
  final String movementDate;
  final DateTime createdAt;

  // Joined
  final String? itemName;

  const StockMovement({
    this.id,
    required this.itemId,
    required this.type,
    required this.quantity,
    this.unitCost,
    this.reference,
    this.notes,
    required this.movementDate,
    required this.createdAt,
    this.itemName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
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
