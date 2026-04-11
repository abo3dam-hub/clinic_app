// lib/features/reports/domain/services/report_service.dart

import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/date_utils.dart';

// ═══════════════════════════════════════════════════════════════
// Report value objects
// ═══════════════════════════════════════════════════════════════

class DailyReport {
  final String date;
  final int    totalVisits;
  final int    totalPatients;
  final double totalInvoiced;
  final double totalCollected;
  final double totalExpenses;
  final double netCash;
  final List<DoctorDailyStats> doctorStats;

  const DailyReport({
    required this.date,
    required this.totalVisits,
    required this.totalPatients,
    required this.totalInvoiced,
    required this.totalCollected,
    required this.totalExpenses,
    required this.netCash,
    required this.doctorStats,
  });
}

class DoctorDailyStats {
  final int    doctorId;
  final String doctorName;
  final int    visits;
  final double revenue;
  final double commission;

  const DoctorDailyStats({
    required this.doctorId,
    required this.doctorName,
    required this.visits,
    required this.revenue,
    required this.commission,
  });
}

// ─────────────────────────────────────────────────────────────

class PeriodReport {
  final String fromDate;
  final String toDate;
  final int    totalVisits;
  final int    totalPatients;
  final double totalInvoiced;
  final double totalCollected;
  final double totalExpenses;
  final double netProfit;
  final List<MonthStat>       monthlyBreakdown;
  final List<DoctorPerfStat>  doctorPerformance;
  final List<ProcedureStat>   topProcedures;

  const PeriodReport({
    required this.fromDate,
    required this.toDate,
    required this.totalVisits,
    required this.totalPatients,
    required this.totalInvoiced,
    required this.totalCollected,
    required this.totalExpenses,
    required this.netProfit,
    required this.monthlyBreakdown,
    required this.doctorPerformance,
    required this.topProcedures,
  });
}

class MonthStat {
  final String month;
  final int    visits;
  final double invoiced;
  final double collected;
  final double expenses;

  const MonthStat({
    required this.month,
    required this.visits,
    required this.invoiced,
    required this.collected,
    required this.expenses,
  });
}

class DoctorPerfStat {
  final int    doctorId;
  final String doctorName;
  final int    totalVisits;
  final double totalRevenue;
  final double commissionPct;
  final double commissionAmount;
  final double netRevenue;

  const DoctorPerfStat({
    required this.doctorId,
    required this.doctorName,
    required this.totalVisits,
    required this.totalRevenue,
    required this.commissionPct,
    required this.commissionAmount,
    required this.netRevenue,
  });
}

class ProcedureStat {
  final int    procedureId;
  final String procedureName;
  final int    totalCount;
  final double totalRevenue;

  const ProcedureStat({
    required this.procedureId,
    required this.procedureName,
    required this.totalCount,
    required this.totalRevenue,
  });
}

// ═══════════════════════════════════════════════════════════════
// Report Service
// ═══════════════════════════════════════════════════════════════

class ReportService {
  final DatabaseHelper _db;

  ReportService(this._db);

  // ─── Daily Report ─────────────────────────────────────────────

  Future<DailyReport> getDailyReport(String date) async {
    // Visits
    final visitsRows = await _db.rawQuery('''
      SELECT COUNT(*) AS cnt,
             COUNT(DISTINCT patient_id) AS patients
      FROM   visits
      WHERE  visit_date = ?
    ''', [date]);

    final totalVisits   = (visitsRows.first['cnt']      as int? ?? 0);
    final totalPatients = (visitsRows.first['patients'] as int? ?? 0);

    // Invoiced & collected
    final invRows = await _db.rawQuery('''
      SELECT COALESCE(SUM(net_amount),  0) AS invoiced,
             COALESCE(SUM(paid_amount), 0) AS collected
      FROM   invoices
      WHERE  invoice_date = ? AND status != 'cancelled'
    ''', [date]);

    final totalInvoiced  = (invRows.first['invoiced']  as num).toDouble();
    final totalCollected = (invRows.first['collected'] as num).toDouble();

    // Expenses
    final expRows = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM   expenses
      WHERE  expense_date = ?
    ''', [date]);

    final totalExpenses = (expRows.first['total'] as num).toDouble();

    // Doctor stats
    final drRows = await _db.rawQuery('''
      SELECT d.id            AS doctor_id,
             d.name          AS doctor_name,
             d.commission_pct,
             COUNT(v.id)     AS visits,
             COALESCE(SUM(i.net_amount), 0) AS revenue
      FROM   doctors d
      LEFT JOIN visits   v ON v.doctor_id    = d.id AND v.visit_date = ?
      LEFT JOIN invoices i ON i.visit_id     = v.id AND i.status != 'cancelled'
      GROUP  BY d.id
      HAVING visits > 0
      ORDER  BY revenue DESC
    ''', [date]);

    final doctorStats = drRows.map((r) {
      final rev        = (r['revenue']        as num).toDouble();
      final commission = (r['commission_pct'] as num).toDouble();
      return DoctorDailyStats(
        doctorId:   r['doctor_id']   as int,
        doctorName: r['doctor_name'] as String,
        visits:     r['visits']      as int,
        revenue:    rev,
        commission: rev * commission / 100,
      );
    }).toList();

    return DailyReport(
      date:            date,
      totalVisits:     totalVisits,
      totalPatients:   totalPatients,
      totalInvoiced:   totalInvoiced,
      totalCollected:  totalCollected,
      totalExpenses:   totalExpenses,
      netCash:         totalCollected - totalExpenses,
      doctorStats:     doctorStats,
    );
  }

  // ─── Monthly Report ───────────────────────────────────────────

  Future<PeriodReport> getMonthlyReport(int year, int month) async {
    final from = ClinicDateUtils.toDbDate(DateTime(year, month, 1));
    final to   = ClinicDateUtils.toDbDate(DateTime(year, month + 1, 0));
    return _getPeriodReport(from, to);
  }

  // ─── Yearly Report ────────────────────────────────────────────

  Future<PeriodReport> getYearlyReport(int year) async {
    return _getPeriodReport(
        ClinicDateUtils.yearStart(year), ClinicDateUtils.yearEnd(year));
  }

  // ─── Custom Period ────────────────────────────────────────────

  Future<PeriodReport> getCustomReport(String from, String to) =>
      _getPeriodReport(from, to);

  // ─── Doctor Performance ───────────────────────────────────────

  Future<List<DoctorPerfStat>> getDoctorPerformance({
    required String fromDate,
    required String toDate,
    int? doctorId,
  }) async {
    final args = <Object?>[fromDate, toDate];
    final extra = doctorId != null ? 'AND d.id = ?' : '';
    if (doctorId != null) args.add(doctorId);

    final rows = await _db.rawQuery('''
      SELECT d.id              AS doctor_id,
             d.name            AS doctor_name,
             d.commission_pct,
             COUNT(DISTINCT v.id)              AS total_visits,
             COALESCE(SUM(i.net_amount), 0)    AS total_revenue
      FROM   doctors d
      LEFT JOIN visits   v ON v.doctor_id = d.id
                           AND v.visit_date BETWEEN ? AND ?
      LEFT JOIN invoices i ON i.visit_id  = v.id
                           AND i.status  != 'cancelled'
      WHERE  d.is_active = 1 $extra
      GROUP  BY d.id
      ORDER  BY total_revenue DESC
    ''', args);

    return rows.map((r) {
      final rev   = (r['total_revenue']  as num).toDouble();
      final comPct = (r['commission_pct'] as num).toDouble();
      final comAmt = rev * comPct / 100;
      return DoctorPerfStat(
        doctorId:         r['doctor_id']   as int,
        doctorName:       r['doctor_name'] as String,
        totalVisits:      r['total_visits'] as int,
        totalRevenue:     rev,
        commissionPct:    comPct,
        commissionAmount: comAmt,
        netRevenue:       rev - comAmt,
      );
    }).toList();
  }

  // ─── Private helpers ──────────────────────────────────────────

  Future<PeriodReport> _getPeriodReport(String from, String to) async {
    // Totals
    final totRow = await _db.rawQuery('''
      SELECT COUNT(DISTINCT v.id)              AS total_visits,
             COUNT(DISTINCT v.patient_id)      AS total_patients,
             COALESCE(SUM(i.net_amount),  0)   AS invoiced,
             COALESCE(SUM(i.paid_amount), 0)   AS collected
      FROM   visits v
      LEFT JOIN invoices i ON i.visit_id = v.id AND i.status != 'cancelled'
      WHERE  v.visit_date BETWEEN ? AND ?
    ''', [from, to]);

    final expRow = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS expenses
      FROM   expenses
      WHERE  expense_date BETWEEN ? AND ?
    ''', [from, to]);

    final totalVisits    = (totRow.first['total_visits']    as int? ?? 0);
    final totalPatients  = (totRow.first['total_patients']  as int? ?? 0);
    final totalInvoiced  = (totRow.first['invoiced']  as num).toDouble();
    final totalCollected = (totRow.first['collected'] as num).toDouble();
    final totalExpenses  = (expRow.first['expenses']  as num).toDouble();

    // Monthly breakdown
    final monthRows = await _db.rawQuery('''
      SELECT strftime('%Y-%m', v.visit_date) AS month,
             COUNT(DISTINCT v.id)             AS visits,
             COALESCE(SUM(i.net_amount),  0)  AS invoiced,
             COALESCE(SUM(i.paid_amount), 0)  AS collected
      FROM   visits v
      LEFT JOIN invoices i ON i.visit_id = v.id AND i.status != 'cancelled'
      WHERE  v.visit_date BETWEEN ? AND ?
      GROUP  BY month
      ORDER  BY month ASC
    ''', [from, to]);

    final expMonthRows = await _db.rawQuery('''
      SELECT strftime('%Y-%m', expense_date) AS month,
             COALESCE(SUM(amount), 0)         AS expenses
      FROM   expenses
      WHERE  expense_date BETWEEN ? AND ?
      GROUP  BY month
    ''', [from, to]);

    final expMap = {
      for (final r in expMonthRows) r['month'] as String: (r['expenses'] as num).toDouble()
    };

    final monthlyBreakdown = monthRows.map((r) {
      final m = r['month'] as String;
      return MonthStat(
        month:     m,
        visits:    r['visits']    as int,
        invoiced:  (r['invoiced']  as num).toDouble(),
        collected: (r['collected'] as num).toDouble(),
        expenses:  expMap[m] ?? 0.0,
      );
    }).toList();

    // Doctor performance
    final doctorPerf = await getDoctorPerformance(
        fromDate: from, toDate: to);

    // Top procedures
    final procRows = await _db.rawQuery('''
      SELECT pr.id          AS procedure_id,
             pr.name        AS procedure_name,
             SUM(vp.quantity)             AS total_count,
             SUM(vp.unit_price * vp.quantity - vp.discount) AS total_revenue
      FROM   visit_procedures vp
      JOIN   procedures pr ON pr.id = vp.procedure_id
      JOIN   visits      v  ON v.id  = vp.visit_id
      WHERE  v.visit_date BETWEEN ? AND ?
      GROUP  BY pr.id
      ORDER  BY total_revenue DESC
      LIMIT  10
    ''', [from, to]);

    final topProcedures = procRows.map((r) => ProcedureStat(
          procedureId:   r['procedure_id']   as int,
          procedureName: r['procedure_name'] as String,
          totalCount:    (r['total_count']   as num).toInt(),
          totalRevenue:  (r['total_revenue'] as num).toDouble(),
        )).toList();

    return PeriodReport(
      fromDate:         from,
      toDate:           to,
      totalVisits:      totalVisits,
      totalPatients:    totalPatients,
      totalInvoiced:    totalInvoiced,
      totalCollected:   totalCollected,
      totalExpenses:    totalExpenses,
      netProfit:        totalCollected - totalExpenses,
      monthlyBreakdown: monthlyBreakdown,
      doctorPerformance: doctorPerf,
      topProcedures:    topProcedures,
    );
  }
}
