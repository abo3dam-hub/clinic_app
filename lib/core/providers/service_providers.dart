// lib/core/providers/service_providers.dart

import 'package:clinic_app/core/utils/date_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../database/database_provider.dart';
import '../services/backup_service.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import 'repository_providers.dart';
import '../../features/invoices/domain/services/invoice_service.dart';
import '../../features/reports/domain/services/report_service.dart';
import '../../features/doctors/domain/services/doctor_revenue_service.dart';
import '../../features/cash_box/domain/services/cash_box_service.dart';
import '../../features/patients/domain/entities/patient.dart';
import '../../features/patients/domain/repositories/patient_repository.dart';
import '../../features/doctors/domain/entities/doctor.dart';
import '../../features/doctors/domain/repositories/doctor_repository.dart';
import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/procedures/domain/entities/procedure.dart';
import '../../features/procedures/data/repositories/procedure_repository_impl.dart';
import '../../features/visits/domain/entities/visit.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/inventory/domain/entities/inventory.dart';

// Services
final invoiceServiceProvider = Provider<InvoiceService>((ref) => InvoiceService(
    invoiceRepo: ref.watch(invoiceRepositoryProvider),
    visitRepo: ref.watch(visitRepositoryProvider)));
final reportServiceProvider = Provider<ReportService>(
    (ref) => ReportService(ref.watch(databaseHelperProvider)));
final doctorRevenueServiceProvider = Provider<DoctorRevenueService>(
    (ref) => DoctorRevenueService(ref.watch(databaseHelperProvider)));
final backupServiceProvider = Provider<BackupService>(
    (ref) => BackupService(ref.watch(databaseHelperProvider)));
final cashBoxServiceProvider = Provider<CashBoxService>(
    (ref) => CashBoxService(ref.watch(cashBoxRepositoryProvider)));
final pdfExportServiceProvider =
    Provider<PdfExportService>((_) => PdfExportService(clinicName: 'عيادتي'));
final excelExportServiceProvider = Provider<ExcelExportService>(
    (_) => ExcelExportService(clinicName: 'عيادتي'));

class AppointmentFilterNotifier extends Notifier<AppointmentFilter> {
  @override
  AppointmentFilter build() {
    // القيمة الابتدائية
    final today = DateTime.now();
    final todayStr = ClinicDateUtils.toDbDate(today);
    return AppointmentFilter(date: todayStr);
  }

  final appointmentFilterProvider =
      NotifierProvider<AppointmentFilterNotifier, AppointmentFilter>(() {
    return AppointmentFilterNotifier();
  });

  // 2. دالة لتحديث القيمة
  void updateFilter(AppointmentFilter newFilter) {
    state = newFilter;
  }
}

// Patients
class PatientNotifier extends AsyncNotifier<List<Patient>> {
  PatientRepository get _r => ref.read(patientRepositoryProvider);
  @override
  Future<List<Patient>> build() => _r.getAll();
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _r.getAll());
  }

  Future<void> search(String q) async {
    state = await AsyncValue.guard(() => _r.search(q));
  }

  Future<void> create(Patient p) async {
    await _r.create(p);
    await refresh();
  }

  Future<void> updatePatient(Patient p) async {
    await _r.update(p);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _r.delete(id);
    await refresh();
  }
}

final patientNotifierProvider =
    AsyncNotifierProvider<PatientNotifier, List<Patient>>(PatientNotifier.new);

// Doctors
class DoctorNotifier extends AsyncNotifier<List<Doctor>> {
  DoctorRepository get _r => ref.read(doctorRepositoryProvider);
  @override
  Future<List<Doctor>> build() => _r.getAll();
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _r.getAll());
  }

  Future<void> create(Doctor d) async {
    await _r.create(d);
    await refresh();
  }

  Future<void> updateDoctor(Doctor d) async {
    await _r.update(d);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _r.delete(id);
    await refresh();
  }
}

final doctorNotifierProvider =
    AsyncNotifierProvider<DoctorNotifier, List<Doctor>>(DoctorNotifier.new);

// Appointment filter
class AppointmentFilter {
  final String? date;
  final String? fromDate;
  final String? toDate;
  final int? doctorId;
  final String? status;
  const AppointmentFilter(
      {this.date, this.fromDate, this.toDate, this.doctorId, this.status});
}

final appointmentFilterProvider = StateProvider<AppointmentFilter>(
    (erf) => AppointmentFilter(date: _todayStr()));
final appointmentsProvider = FutureProvider<List<Appointment>>((ref) {
  final r = ref.watch(appointmentRepositoryProvider);
  final f = ref.watch(appointmentFilterProvider);

  return r.getAll(
      date: f.date,
      fromDate: f.fromDate,
      toDate: f.toDate,
      doctorId: f.doctorId,
      status: f.status);
});
final todayAppointmentCountsProvider = FutureProvider<Map<String, int>>(
    (ref) => ref.watch(appointmentRepositoryProvider).getTodayCounts());

// Procedures
class ProcedureNotifier extends AsyncNotifier<List<Procedure>> {
  ProcedureRepositoryImpl get _r => ref.read(procedureRepositoryProvider);
  @override
  Future<List<Procedure>> build() => _r.getAll();
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _r.getAll());
  }

  Future<void> search(String q) async {
    state = await AsyncValue.guard(() => _r.search(q));
  }

  Future<void> create(Procedure p) async {
    await _r.create(p);
    await refresh();
  }

  Future<void> updateProcedure(Procedure p) async {
    await _r.update(p);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _r.delete(id);
    await refresh();
  }

  Future<void> toggle(int id, bool a) async {
    await _r.toggleActive(id, active: a);
    await refresh();
  }
}

final procedureNotifierProvider =
    AsyncNotifierProvider<ProcedureNotifier, List<Procedure>>(
        ProcedureNotifier.new);

// Visit filter
class VisitFilter {
  final String? fromDate;
  final String? toDate;
  final int? patientId;
  final int? doctorId;
  const VisitFilter(
      {this.fromDate, this.toDate, this.patientId, this.doctorId});
}

final visitFilterProvider =
    StateProvider<VisitFilter>((_) => const VisitFilter());
final visitsProvider = FutureProvider<List<Visit>>((ref) {
  final r = ref.watch(visitRepositoryProvider);
  final f = ref.watch(visitFilterProvider);
  return r.getAll(
      fromDate: f.fromDate,
      toDate: f.toDate,
      patientId: f.patientId,
      doctorId: f.doctorId);
});
final visitProceduresProvider =
    FutureProvider.family<List<VisitProcedureItem>, int>((ref, id) =>
        ref.watch(visitRepositoryProvider).getProceduresForVisit(id));

// Invoice filter
class InvoiceFilter {
  final String? fromDate;
  final String? toDate;
  final String? status;
  final int? patientId;
  const InvoiceFilter(
      {this.fromDate, this.toDate, this.status, this.patientId});
}

final invoiceFilterProvider =
    StateProvider<InvoiceFilter>((ref) => const InvoiceFilter());
final invoicesProvider = FutureProvider<List<Invoice>>((ref) {
  final r = ref.watch(invoiceRepositoryProvider);
  final f = ref.watch(invoiceFilterProvider);
  return r.getAll(
      fromDate: f.fromDate,
      toDate: f.toDate,
      status: f.status,
      patientId: f.patientId);
});
final invoiceByIdProvider = FutureProvider.family<Invoice?, int>(
    (ref, id) => ref.watch(invoiceRepositoryProvider).getById(id));
final invoiceItemsProvider = FutureProvider.family<List<InvoiceItem>, int>(
    (ref, id) => ref.watch(invoiceRepositoryProvider).getItemsForInvoice(id));
final invoicePaymentsProvider = FutureProvider.family<List<Payment>, int>(
    (ref, id) =>
        ref.watch(invoiceRepositoryProvider).getPaymentsForInvoice(id));

// Inventory
final inventoryItemsProvider = FutureProvider<List<InventoryItem>>(
    (ref) => ref.watch(inventoryRepositoryProvider).getAllItems());
final lowStockProvider = FutureProvider<List<InventoryItem>>(
    (ref) => ref.watch(inventoryRepositoryProvider).getLowStockItems());
final stockMovementsProvider = FutureProvider.family<List<StockMovement>, int?>(
    (ref, itemId) =>
        ref.watch(inventoryRepositoryProvider).getMovements(itemId: itemId));

// Reports
class ReportPeriod {
  final String fromDate;
  final String toDate;
  const ReportPeriod({required this.fromDate, required this.toDate});
  @override
  bool operator ==(Object o) =>
      o is ReportPeriod && o.fromDate == fromDate && o.toDate == toDate;
  @override
  int get hashCode => Object.hash(fromDate, toDate);
}

final reportPeriodProvider = Provider<ReportPeriod>((ref) {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final last = DateTime(now.year, now.month + 1, 0).day;
  return ReportPeriod(
      fromDate: '$y-$m-01', toDate: '$y-$m-${last.toString().padLeft(2, '0')}');
});
final periodReportProvider = FutureProvider<PeriodReport>((ref) {
  final p = ref.watch(reportPeriodProvider);
  return ref.watch(reportServiceProvider).getCustomReport(p.fromDate, p.toDate);
});
final dailyReportProvider = FutureProvider.family<DailyReport, String>(
    (ref, date) => ref.watch(reportServiceProvider).getDailyReport(date));
final doctorRevenueProvider =
    FutureProvider.family<List<DoctorRevenueResult>, ReportPeriod>((ref, p) =>
        ref
            .watch(doctorRevenueServiceProvider)
            .getAllDoctorsRevenue(fromDate: p.fromDate, toDate: p.toDate));

// Cash Box
final cashBoxTodayProvider = FutureProvider<CashBox>(
    (ref) => ref.watch(cashBoxServiceProvider).getToday());

String _todayStr() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
