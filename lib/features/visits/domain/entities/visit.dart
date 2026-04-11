// lib/features/visits/domain/entities/visit.dart

class Visit {
  final int? id;
  final int patientId;
  final int doctorId;
  final int? appointmentId;
  final String visitDate;
  final String? diagnosis;
  final String? notes;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final String? patientName;
  final String? doctorName;

  const Visit({
    this.id,
    required this.patientId,
    required this.doctorId,
    this.appointmentId,
    required this.visitDate,
    this.diagnosis,
    this.notes,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
    this.doctorName,
  });

  Visit copyWith({
    int? id,
    int? patientId,
    int? doctorId,
    int? appointmentId,
    String? visitDate,
    String? diagnosis,
    String? notes,
    bool? isLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName,
    String? doctorName,
  }) =>
      Visit(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        doctorId: doctorId ?? this.doctorId,
        appointmentId: appointmentId ?? this.appointmentId,
        visitDate: visitDate ?? this.visitDate,
        diagnosis: diagnosis ?? this.diagnosis,
        notes: notes ?? this.notes,
        isLocked: isLocked ?? this.isLocked,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        patientName: patientName ?? this.patientName,
        doctorName: doctorName ?? this.doctorName,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class VisitProcedureItem {
  final int? id;
  final int visitId;
  final int procedureId;
  final int quantity;
  final double unitPrice;
  final double discount;
  final String? notes;
  final DateTime createdAt;

  // Joined
  final String? procedureName;

  const VisitProcedureItem({
    this.id,
    required this.visitId,
    required this.procedureId,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0.0,
    this.notes,
    required this.createdAt,
    this.procedureName,
  });

  double get lineTotal => (unitPrice * quantity) * (1 - discount / 100);
}
