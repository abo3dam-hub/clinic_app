// lib/features/doctors/domain/services/doctor_revenue_service.dart

import '../../../../core/database/database_helper.dart';

class DoctorRevenueResult {
  final int    doctorId;
  final String doctorName;
  final String specialty;
  final double commissionPct;

  final int    totalVisits;
  final double grossRevenue;
  final double commissionAmount;
  final double netRevenue;

  final List<DoctorDayRevenue> dailyBreakdown;

  const DoctorRevenueResult({
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.commissionPct,
    required this.totalVisits,
    required this.grossRevenue,
    required this.commissionAmount,
    required this.netRevenue,
    required this.dailyBreakdown,
  });
}

class DoctorDayRevenue {
  final String date;
  final int    visits;
  final double revenue;

  const DoctorDayRevenue({
    required this.date,
    required this.visits,
    required this.revenue,
  });
}

// ─────────────────────────────────────────────────────────────

class DoctorRevenueService {
  final DatabaseHelper _db;

  DoctorRevenueService(this._db);

  Future<DoctorRevenueResult> getRevenueForDoctor({
    required int doctorId,
    required String fromDate,
    required String toDate,
  }) async {
    // Doctor info
    final docRows = await _db.query('doctors',
        where: 'id = ?', whereArgs: [doctorId], limit: 1);
    if (docRows.isEmpty) throw StateError('الطبيب غير موجود');
    final doc = docRows.first;

    final commissionPct = (doc['commission_pct'] as num).toDouble();

    // Totals
    final totRows = await _db.rawQuery('''
      SELECT COUNT(DISTINCT v.id)           AS total_visits,
             COALESCE(SUM(i.net_amount), 0) AS gross_revenue
      FROM   visits v
      LEFT JOIN invoices i ON i.visit_id = v.id AND i.status != 'cancelled'
      WHERE  v.doctor_id   = ?
        AND  v.visit_date  BETWEEN ? AND ?
    ''', [doctorId, fromDate, toDate]);

    final totalVisits  = (totRows.first['total_visits']  as int? ?? 0);
    final grossRevenue = (totRows.first['gross_revenue'] as num).toDouble();
    final commission   = grossRevenue * commissionPct / 100;

    // Daily breakdown
    final dailyRows = await _db.rawQuery('''
      SELECT v.visit_date                   AS date,
             COUNT(DISTINCT v.id)           AS visits,
             COALESCE(SUM(i.net_amount), 0) AS revenue
      FROM   visits v
      LEFT JOIN invoices i ON i.visit_id = v.id AND i.status != 'cancelled'
      WHERE  v.doctor_id  = ?
        AND  v.visit_date BETWEEN ? AND ?
      GROUP  BY v.visit_date
      ORDER  BY v.visit_date ASC
    ''', [doctorId, fromDate, toDate]);

    final daily = dailyRows.map((r) => DoctorDayRevenue(
          date:    r['date']    as String,
          visits:  r['visits']  as int,
          revenue: (r['revenue'] as num).toDouble(),
        )).toList();

    return DoctorRevenueResult(
      doctorId:         doctorId,
      doctorName:       doc['name']      as String,
      specialty:        (doc['specialty'] ?? '') as String,
      commissionPct:    commissionPct,
      totalVisits:      totalVisits,
      grossRevenue:     grossRevenue,
      commissionAmount: commission,
      netRevenue:       grossRevenue - commission,
      dailyBreakdown:   daily,
    );
  }

  /// Revenue summary for ALL doctors in a period.
  Future<List<DoctorRevenueResult>> getAllDoctorsRevenue({
    required String fromDate,
    required String toDate,
  }) async {
    final docRows = await _db.query('doctors',
        where: 'is_active = ?', whereArgs: [1], orderBy: 'name ASC');

    final results = <DoctorRevenueResult>[];
    for (final d in docRows) {
      final res = await getRevenueForDoctor(
        doctorId: d['id'] as int,
        fromDate: fromDate,
        toDate: toDate,
      );
      if (res.totalVisits > 0) results.add(res);
    }
    return results;
  }
}
