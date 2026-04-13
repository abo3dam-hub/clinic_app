// lib/features/patients/domain/repositories/patient_repository.dart

import './../entities/patient.dart';

abstract class PatientRepository {
  Future<List<Patient>> getAll({bool activeOnly = true});
  Future<Patient?> getById(int id);
  Future<List<Patient>> search(String query);
  Future<int> create(Patient patient);
  Future<void> update(Patient patient);
  Future<void> delete(int id);

  // New methods for Dashboard and Profile
  Future<List<PatientBalance>> getPatientsWithBalances();
  Future<PatientProfile?> getPatientProfile(int id);
}
