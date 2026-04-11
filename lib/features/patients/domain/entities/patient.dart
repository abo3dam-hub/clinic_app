// lib/features/patients/domain/entities/patient.dart

class Patient {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? birthDate;
  final String? gender;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Patient({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.birthDate,
    this.gender,
    this.address,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Patient copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? birthDate,
    String? gender,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Patient(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Patient && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
