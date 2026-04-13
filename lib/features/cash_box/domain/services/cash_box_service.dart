// lib/features/cash_box/domain/services/cash_box_service.dart

import 'package:clinic_app/features/cash_box/data/repositories/cash_box_repository_impl.dart';
import 'package:clinic_app/core/utils/date_utils.dart';
import 'package:clinic_app/features/cash_box/domain/entities/cash_box.dart';

class CashBoxService {
  final CashBoxRepositoryImpl _cashBoxRepo;

  CashBoxService(this._cashBoxRepo);

  /// Ensures today's cash box is open. Returns it.
  Future<CashBox> ensureTodayOpen() => _cashBoxRepo.getOrCreateToday();

  /// Close today's cash box.
  /// closing balance = opening + income - expenses (auto-calculated).
  Future<void> closeToday() async {
    final today = await _cashBoxRepo.getByDate(ClinicDateUtils.todayString());
    if (today == null) throw StateError('الصندوق غير مفتوحة اليوم');
    if (today.isClosed) throw StateError('الصندوق مغلقة مسبقاً');

    final closing = today.calculatedClosingBalance;
    await _cashBoxRepo.close(today.id!, closing);
  }

  /// Get today's cash box (creates it if needed).
  Future<CashBox> getToday() => _cashBoxRepo.getOrCreateToday();

  Future<List<CashBox>> getHistory({String? from, String? to}) =>
      _cashBoxRepo.getHistory(fromDate: from, toDate: to);
}
