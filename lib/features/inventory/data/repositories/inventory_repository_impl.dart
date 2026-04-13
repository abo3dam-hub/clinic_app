// lib/features/inventory/data/repositories/inventory_repository_impl.dart

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/inventory.dart';

class InventoryRepositoryImpl {
  final DatabaseHelper _db;

  InventoryRepositoryImpl(this._db);

  // ─── Items ────────────────────────────────────────────────────

  InventoryItem _itemFromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'] as int,
        name: m['name'] as String,
        unit: m['unit'] as String?,
        minQuantity: (m['min_quantity'] as num).toDouble(),
        quantity: (m['quantity'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num).toDouble(),
        isActive: (m['is_active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  StockMovement _movFromMap(Map<String, dynamic> m) => StockMovement(
        id: m['id'] as int,
        itemId: m['item_id'] as int,
        type: StockMovementTypeX.fromString(m['type'] as String),
        quantity: (m['quantity'] as num).toDouble(),
        unitCost: m['unit_cost'] != null
            ? (m['unit_cost'] as num).toDouble()
            : null,
        reference: m['reference'] as String?,
        notes: m['notes'] as String?,
        movementDate: m['movement_date'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        itemName: m['item_name'] as String?,
      );

  Future<List<InventoryItem>> getAllItems({bool activeOnly = true}) async {
    final rows = await _db.query(
      'items',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return rows.map(_itemFromMap).toList();
  }

  Future<InventoryItem?> getItemById(int id) async {
    final rows = await _db.query('items',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _itemFromMap(rows.first);
  }

  Future<int> createItem(InventoryItem item) async {
    final now = DateTime.now().toIso8601String();
    return _db.insert('items', {
      'name': item.name,
      'unit': item.unit,
      'min_quantity': item.minQuantity,
      'quantity': item.quantity,
      'unit_cost': item.unitCost,
      'is_active': item.isActive ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateItem(InventoryItem item) async {
    assert(item.id != null);
    await _db.update('items', {
      'name': item.name,
      'unit': item.unit,
      'min_quantity': item.minQuantity,
      'unit_cost': item.unitCost,
      'is_active': item.isActive ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    final rows = await _db.rawQuery('''
      SELECT * FROM items
      WHERE  is_active = 1 AND quantity < min_quantity
      ORDER  BY name ASC
    ''');
    return rows.map(_itemFromMap).toList();
  }

  // ─── Stock Movements ──────────────────────────────────────────

  Future<List<StockMovement>> getMovements({
    int? itemId,
    String? fromDate,
    String? toDate,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (itemId   != null) { conditions.add('sm.item_id = ?');          args.add(itemId);   }
    if (fromDate != null) { conditions.add('sm.movement_date >= ?');   args.add(fromDate); }
    if (toDate   != null) { conditions.add('sm.movement_date <= ?');   args.add(toDate);   }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await _db.rawQuery('''
      SELECT sm.*, i.name AS item_name
      FROM   stock_movements sm
      JOIN   items i ON i.id = sm.item_id
      $where
      ORDER  BY sm.movement_date DESC, sm.id DESC
    ''', args);

    return rows.map(_movFromMap).toList();
  }

  /// Adds a stock movement and updates item quantity in a transaction.
  /// Throws [StateError] if an 'out' movement would make stock negative.
  Future<int> addMovement(StockMovement movement) async {
    return _db.runTransaction<int>((txn) async {
      final itemRows = await txn.query('items',
          where: 'id = ?', whereArgs: [movement.itemId], limit: 1);
      if (itemRows.isEmpty) throw StateError('الصنف غير موجود');

      final currentQty = (itemRows.first['quantity'] as num).toDouble();
      double delta;

      switch (movement.type) {
        case StockMovementType.inward:
          delta = movement.quantity;
          break;
        case StockMovementType.outward:
          delta = -movement.quantity;
          break;
        case StockMovementType.adjustment:
          delta = movement.quantity; // signed value
          break;
      }

      final newQty = currentQty + delta;
      if (newQty < 0) {
        throw StateError(
            'المخزون غير كافٍ. المتاح: $currentQty، المطلوب: ${movement.quantity}');
      }

      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('stock_movements', {
        'item_id': movement.itemId,
        'type': movement.type.value,
        'quantity': movement.quantity,
        'unit_cost': movement.unitCost,
        'reference': movement.reference,
        'notes': movement.notes,
        'movement_date': movement.movementDate,
        'created_at': now,
      });

      await txn.update(
        'items',
        {'quantity': newQty, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [movement.itemId],
      );

      return id;
    });
  }
}

