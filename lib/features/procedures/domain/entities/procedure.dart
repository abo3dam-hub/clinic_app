// lib/features/procedures/domain/entities/procedure.dart

class Procedure {
  final int? id;
  final String name;
  final String? description;
  final double defaultPrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Procedure({
    this.id,
    required this.name,
    this.description,
    this.defaultPrice = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Procedure copyWith({
    int? id,
    String? name,
    String? description,
    double? defaultPrice,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Procedure(
        id:           id           ?? this.id,
        name:         name         ?? this.name,
        description:  description  ?? this.description,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        isActive:     isActive     ?? this.isActive,
        createdAt:    createdAt    ?? this.createdAt,
        updatedAt:    updatedAt    ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Procedure && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
