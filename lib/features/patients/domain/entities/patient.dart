// lib/features/patients/domain/entities/patient.dart
import 'package:clinic_app/features/visits/domain/entities/visit_entities.dart';
import 'package:clinic_app/features/invoices/domain/entities/invoice.dart';

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

// ─────────────────────────────────────────────────────────────────────────────

/// Represents a summarized financial state of a patient.
class PatientBalance {
  final int patientId;
  final String patientName;
  final double outstandingBalance;
  final DateTime? lastActivityDate;

  const PatientBalance({
    required this.patientId,
    required this.patientName,
    required this.outstandingBalance,
    this.lastActivityDate,
  });
}

/// A composite entity to hold a visit along with its procedures.
/// Used for the "expand in-place" UI in the patient profile.
class VisitWithProcedures {
  final Visit visit;
  final List<VisitProcedure> procedures;

  const VisitWithProcedures({
    required this.visit,
    required this.procedures,
  });
}

/// The full detailed profile record for a patient.
class PatientProfile {
  final Patient patient;
  final List<VisitWithProcedures> visits;
  final List<Invoice> invoices;
  final List<Payment> payments;

  const PatientProfile({
    required this.patient,
    required this.visits,
    required this.invoices,
    required this.payments,
  });

  double get totalInvoiced => invoices.fold(0.0, (sum, item) => sum + item.netAmount);
  double get totalPaid => payments.fold(0.0, (sum, item) => sum + item.amount);
  double get outstandingBalance => totalInvoiced - totalPaid;
}
