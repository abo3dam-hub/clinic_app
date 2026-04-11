// lib/features/doctors/domain/repositories/doctor_repository.dart

import '../../features/doctors/domain/entities/doctor.dart';

abstract class DoctorRepository {
  Future<List<Doctor>> getAll({bool activeOnly = true});
  Future<Doctor?> getById(int id);
  Future<int> create(Doctor doctor);
  Future<void> update(Doctor doctor);
  Future<void> delete(int id);
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/visits/domain/repositories/visit_repository.dart

// (import paths adjusted per actual file layout)

abstract class VisitRepository {
  Future<List<dynamic>> getAll(
      {String? fromDate, String? toDate, int? patientId, int? doctorId});
  Future<dynamic> getById(int id);
  Future<int> create(dynamic visit);
  Future<void> update(dynamic visit);
  Future<void> lock(int id);
  Future<void> delete(int id);

  // VisitProcedures
  Future<List<dynamic>> getProceduresForVisit(int visitId);
  Future<int> addProcedure(dynamic item);
  Future<void> removeProcedure(int id);
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/invoices/domain/repositories/invoice_repository.dart

abstract class InvoiceRepository {
  Future<List<dynamic>> getAll(
      {String? fromDate, String? toDate, String? status, int? patientId});
  Future<dynamic> getById(int id);
  Future<int> create(dynamic invoice);
  Future<void> update(dynamic invoice);
  Future<void> cancel(int id);

  // Items
  Future<List<dynamic>> getItemsForInvoice(int invoiceId);
  Future<int> addItem(dynamic item);
  Future<void> removeItem(int id);

  // Payments
  Future<List<dynamic>> getPaymentsForInvoice(int invoiceId);
  Future<int> addPayment(dynamic payment);
  Future<void> deletePayment(int id);
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/expenses/domain/repositories/expense_repository.dart

abstract class ExpenseRepository {
  Future<List<dynamic>> getAll(
      {String? fromDate, String? toDate, String? category});
  Future<dynamic> getById(int id);
  Future<int> create(dynamic expense);
  Future<void> update(dynamic expense);
  Future<void> delete(int id);
  Future<List<String>> getCategories();
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/inventory/domain/repositories/inventory_repository.dart

abstract class InventoryRepository {
  Future<List<dynamic>> getAllItems({bool activeOnly = true});
  Future<dynamic> getItemById(int id);
  Future<int> createItem(dynamic item);
  Future<void> updateItem(dynamic item);

  Future<List<dynamic>> getMovements(
      {int? itemId, String? fromDate, String? toDate});
  Future<int> addMovement(dynamic movement);

  Future<List<dynamic>> getLowStockItems();
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/cash_box/domain/repositories/cash_box_repository.dart

abstract class CashBoxRepository {
  Future<dynamic> getByDate(String date);
  Future<dynamic> getOrCreateToday();
  Future<int> open(dynamic cashBox);
  Future<void> close(int id, double closingBalance);
  Future<List<dynamic>> getHistory({String? fromDate, String? toDate});
}
