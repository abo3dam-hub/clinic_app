// lib/features/appointments/domain/entities/appointment.dart

enum AppointmentStatus { pending, confirmed, cancelled, completed }

extension AppointmentStatusX on AppointmentStatus {
  String get value => name;

  String get label {
    switch (this) {
      case AppointmentStatus.pending:   return 'قيد الانتظار';
      case AppointmentStatus.confirmed: return 'مؤكد';
      case AppointmentStatus.cancelled: return 'ملغي';
      case AppointmentStatus.completed: return 'مكتمل';
    }
  }

  static AppointmentStatus fromString(String s) =>
      AppointmentStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => AppointmentStatus.pending,
      );
}

class Appointment {
  final int? id;
  final int patientId;
  final int doctorId;
  final String scheduledAt;   // ISO date-time string e.g. "2025-01-20 09:30"
  final AppointmentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via JOIN
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

  /// Returns just the date portion "YYYY-MM-DD"
  String get dateOnly => scheduledAt.length >= 10
      ? scheduledAt.substring(0, 10)
      : scheduledAt;

  /// Returns just the time portion "HH:MM"
  String get timeOnly => scheduledAt.length >= 16
      ? scheduledAt.substring(11, 16)
      : '';

  Appointment copyWith({
    int? id,
    int? patientId,
    int? doctorId,
    String? scheduledAt,
    AppointmentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName,
    String? doctorName,
  }) =>
      Appointment(
        id:           id           ?? this.id,
        patientId:    patientId    ?? this.patientId,
        doctorId:     doctorId     ?? this.doctorId,
        scheduledAt:  scheduledAt  ?? this.scheduledAt,
        status:       status       ?? this.status,
        notes:        notes        ?? this.notes,
        createdAt:    createdAt    ?? this.createdAt,
        updatedAt:    updatedAt    ?? this.updatedAt,
        patientName:  patientName  ?? this.patientName,
        doctorName:   doctorName   ?? this.doctorName,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Appointment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
