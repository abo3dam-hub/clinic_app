// lib/features/doctors/domain/repositories/doctor_repository.dart

import '../entities/doctor.dart';

abstract class DoctorRepository {
  Future<List<Doctor>> getAll({bool activeOnly = true});
  Future<Doctor?> getById(int id);
  Future<int> create(Doctor doctor);
  Future<void> update(Doctor doctor);
  Future<void> delete(int id);
}
