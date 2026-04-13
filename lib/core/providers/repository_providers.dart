// lib/core/providers/repository_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clinic_app/core/database/database_helper.dart';
import 'package:clinic_app/core/database/database_provider.dart';

import 'package:clinic_app/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:clinic_app/features/patients/domain/repositories/patient_repository.dart';
import 'package:clinic_app/features/doctors/data/repositories/doctor_repository_impl.dart';
import 'package:clinic_app/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:clinic_app/features/appointments/data/repositories/appointment_repository_impl.dart';
import 'package:clinic_app/features/procedures/data/repositories/procedure_repository_impl.dart';
import 'package:clinic_app/features/visits/data/repositories/visit_repository_impl.dart';
import 'package:clinic_app/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:clinic_app/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:clinic_app/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:clinic_app/features/accounting/data/repositories/ledger_repository.dart';
import 'package:clinic_app/features/cash_box/data/repositories/cash_box_repository_impl.dart';

// ─── Core repositories ─────────────────────────────────────────────────────

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

// ─── Accounting ───────────────────────────────────────────────────────────────

final ledgerRepositoryProvider = Provider<LedgerRepository>(
    (ref) => LedgerRepository(ref.watch(databaseHelperProvider)));

// ─── Invoice: needs JournalService (declared in service_providers.dart)
// Use a lazy provider defined in service_providers.dart to break the
// circular dependency chain: repository → service → repository.
// The invoice repository is therefore declared in service_providers.dart
// where JournalService is already available.

// ─── Expense: also needs JournalService — same pattern ────────────────────────
// See service_providers.dart for invoiceRepositoryProvider and
// expenseRepositoryProvider.

// ─── Inventory ────────────────────────────────────────────────────────────────

final inventoryRepositoryProvider = Provider<InventoryRepositoryImpl>(
    (ref) => InventoryRepositoryImpl(ref.watch(databaseHelperProvider)));

// ─── CashBox ──────────────────────────────────────────────────────────────────

// CashBoxRepositoryImpl is still declared here (no journal dependency)
// ignore: always_use_package_imports

final cashBoxRepositoryProvider = Provider<CashBoxRepositoryImpl>(
    (ref) => CashBoxRepositoryImpl(ref.watch(databaseHelperProvider)));
