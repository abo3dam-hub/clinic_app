// lib/features/doctors/domain/entities/doctor.dart

class Doctor {
  final int? id;
  final String name;
  final String? specialty;
  final String? phone;
  final double commissionPct;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Doctor({
    this.id,
    required this.name,
    this.specialty,
    this.phone,
    this.commissionPct = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Doctor copyWith({
    int? id,
    String? name,
    String? specialty,
    String? phone,
    double? commissionPct,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Doctor(
        id: id ?? this.id,
        name: name ?? this.name,
        specialty: specialty ?? this.specialty,
        phone: phone ?? this.phone,
        commissionPct: commissionPct ?? this.commissionPct,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Doctor && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
