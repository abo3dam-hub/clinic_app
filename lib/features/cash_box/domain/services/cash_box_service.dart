// lib/features/cash_box/domain/services/cash_box_service.dart

import '../../../inventory/data/repositories/inventory_repository_impl.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../features/inventory/domain/entities/inventory.dart';

class CashBoxService {
  final CashBoxRepositoryImpl _cashBoxRepo;

  CashBoxService(this._cashBoxRepo);

  /// Ensures today's cash box is open. Returns it.
  Future<CashBox> ensureTodayOpen() => _cashBoxRepo.getOrCreateToday();

  /// Close today's cash box.
  /// closing balance = opening + income - expenses (auto-calculated).
  Future<void> closeToday() async {
    final today = await _cashBoxRepo.getByDate(ClinicDateUtils.todayString());
    if (today == null) throw StateError('الخزينة غير مفتوحة اليوم');
    if (today.isClosed) throw StateError('الخزينة مغلقة مسبقاً');

    final closing = today.calculatedClosingBalance;
    await _cashBoxRepo.close(today.id!, closing);
  }

  /// Get today's cash box (creates it if needed).
  Future<CashBox> getToday() => _cashBoxRepo.getOrCreateToday();

  Future<List<CashBox>> getHistory({String? from, String? to}) =>
      _cashBoxRepo.getHistory(fromDate: from, toDate: to);
}
