// lib/core/providers/repository_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';

import '../../features/patients/data/repositories/patient_repository_impl.dart';
import '../../features/patients/domain/repositories/patient_repository.dart';
import '../../features/doctors/data/repositories/doctor_repository_impl.dart';
import '../../features/doctors/domain/repositories/doctor_repository.dart';
import '../../features/appointments/data/repositories/appointment_repository_impl.dart';
import '../../features/procedures/data/repositories/procedure_repository_impl.dart';
import '../../features/visits/data/repositories/visit_repository_impl.dart';
import '../../features/invoices/data/repositories/invoice_repository_impl.dart';
import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';

final patientRepositoryProvider = Provider<PatientRepository>(
    (ref) => PatientRepositoryImpl(ref.watch(databaseHelperProvider)));

final doctorRepositoryProvider = Provider<DoctorRepository>(
    (ref) => DoctorRepositoryImpl(ref.watch(databaseHelperProvider)));

final appointmentRepositoryProvider = Provider<AppointmentRepositoryImpl>(
    (ref) => AppointmentRepositoryImpl(ref.watch(databaseHelperProvider)));

final procedureRepositoryProvider = Provider<ProcedureRepositoryImpl>(
    (ref) => ProcedureRepositoryImpl(ref.watch(databaseHelperProvider)));

final visitRepositoryProvider = Provider<VisitRepositoryImpl>(
    (ref) => VisitRepositoryImpl(ref.watch(databaseHelperProvider)));

final invoiceRepositoryProvider = Provider<InvoiceRepositoryImpl>(
    (ref) => InvoiceRepositoryImpl(ref.watch(databaseHelperProvider)));

final expenseRepositoryProvider = Provider<ExpenseRepositoryImpl>(
    (ref) => ExpenseRepositoryImpl(ref.watch(databaseHelperProvider)));

final inventoryRepositoryProvider = Provider<InventoryRepositoryImpl>(
    (ref) => InventoryRepositoryImpl(ref.watch(databaseHelperProvider)));

final cashBoxRepositoryProvider = Provider<CashBoxRepositoryImpl>(
    (ref) => CashBoxRepositoryImpl(ref.watch(databaseHelperProvider)));
