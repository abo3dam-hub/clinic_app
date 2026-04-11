// lib/features/visits/domain/entities/procedure.dart

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
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Procedure && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/appointments/domain/entities/appointment.dart

enum AppointmentStatus { pending, confirmed, cancelled, completed }

extension AppointmentStatusX on AppointmentStatus {
  String get value => name;
  static AppointmentStatus fromString(String s) =>
      AppointmentStatus.values.firstWhere((e) => e.name == s,
          orElse: () => AppointmentStatus.pending);
}

class Appointment {
  final int? id;
  final int patientId;
  final int doctorId;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields (optional, populated by queries)
  final String? patientName;
  final String? doctorName;

  const Appointment({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.scheduledAt,
    this.status = AppointmentStatus.pending,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
    this.doctorName,
  });

  Appointment copyWith({
    int? id,
    int? patientId,
    int? doctorId,
    DateTime? scheduledAt,
    AppointmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName,
    String? doctorName,
  }) =>
      Appointment(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        doctorId: doctorId ?? this.doctorId,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        patientName: patientName ?? this.patientName,
        doctorName: doctorName ?? this.doctorName,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Appointment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/visits/domain/entities/visit.dart

class Visit {
  final int? id;
  final int patientId;
  final int doctorId;
  final int? appointmentId;
  final DateTime visitDate;
  final String? diagnosis;
  final String? notes;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
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
    DateTime? visitDate,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Visit && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/visits/domain/entities/visit_procedure.dart

class VisitProcedure {
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

  const VisitProcedure({
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

  double get lineTotal => (unitPrice * quantity) - discount;

  VisitProcedure copyWith({
    int? id,
    int? visitId,
    int? procedureId,
    int? quantity,
    double? unitPrice,
    double? discount,
    String? notes,
    DateTime? createdAt,
    String? procedureName,
  }) =>
      VisitProcedure(
        id: id ?? this.id,
        visitId: visitId ?? this.visitId,
        procedureId: procedureId ?? this.procedureId,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        procedureName: procedureName ?? this.procedureName,
      );
}
