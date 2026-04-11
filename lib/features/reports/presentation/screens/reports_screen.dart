// lib/features/reports/presentation/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/services/report_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _selectedDate = ClinicDateUtils.todayString();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // ── Tab bar ─────────────────────────────────────────
          Container(
            color: AppColors.surfaceCard,
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'يومي'),
                Tab(text: 'شهري'),
                Tab(text: 'سنوي'),
                Tab(text: 'أداء الأطباء'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DailyTab(
                    date: _selectedDate,
                    onDateChanged: (d) => setState(() => _selectedDate = d)),
                _MonthlyTab(
                    year: _selectedYear,
                    month: _selectedMonth,
                    onChanged: (y, m) => setState(() {
                          _selectedYear = y;
                          _selectedMonth = m;
                        })),
                _YearlyTab(
                    year: _selectedYear,
                    onChanged: (y) => setState(() => _selectedYear = y)),
                _DoctorPerfTab(year: _selectedYear),
              ],
            ),
          ),
        ],
      );
}

// ─── Daily Tab ────────────────────────────────────────────────

class _DailyTab extends ConsumerWidget {
  final String date;
  final void Function(String) onDateChanged;
  const _DailyTab({required this.date, required this.onDateChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dailyReportProvider(date));
    final fmt = NumberFormat('#,##0.00', 'ar');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Date picker
          Row(children: [
            const Text('التاريخ:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 200,
              child: AppDateField(
                  label: '', value: date, onChanged: onDateChanged),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),

          reportAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (r) => Column(children: [
              // Stats cards
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                      label: 'الزيارات',
                      value: '${r.totalVisits}',
                      icon: Icons.local_hospital_outlined,
                      color: AppColors.primary),
                  StatCard(
                      label: 'الفواتير',
                      value: '${fmt.format(r.totalInvoiced)} USD',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.secondary),
                  StatCard(
                      label: 'المحصّل',
                      value: '${fmt.format(r.totalCollected)} USD',
                      icon: Icons.payments_outlined,
                      color: AppColors.success),
                  StatCard(
                      label: 'المصروفات',
                      value: '${fmt.format(r.totalExpenses)} USD',
                      icon: Icons.money_off_outlined,
                      color: AppColors.error),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Doctor table
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'أداء الأطباء'),
                      const SizedBox(height: AppSpacing.md),
                      r.doctorStats.isEmpty
                          ? const EmptyState(title: 'لا توجد زيارات')
                          : AppTable(
                              headers: const [
                                'الطبيب',
                                'الزيارات',
                                'الإيرادات',
                                'العمولة',
                                'الصافي'
                              ],
                              rows: r.doctorStats
                                  .map((s) => [
                                        Text(s.doctorName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text('${s.visits}'),
                                        Text('${fmt.format(s.revenue)} USD',
                                            style: const TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600)),
                                        Text('${fmt.format(s.commission)} USD',
                                            style: const TextStyle(
                                                color: AppColors.warning)),
                                        Text(
                                            '${fmt.format(s.revenue - s.commission)} USD',
                                            style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700)),
                                      ])
                                  .toList(),
                            ),
                    ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Monthly Tab ──────────────────────────────────────────────

class _MonthlyTab extends ConsumerWidget {
  final int year;
  final int month;
  final void Function(int, int) onChanged;
  const _MonthlyTab(
      {required this.year, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ReportPeriod(
      fromDate: ClinicDateUtils.toDbDate(DateTime(year, month, 1)),
      toDate: ClinicDateUtils.toDbDate(DateTime(year, month + 1, 0)),
    );
    final reportAsync = ref.watch(periodReportProvider);
    final fmt = NumberFormat('#,##0.00', 'ar');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        // Month / year picker
        Row(children: [
          const Text('الشهر:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          DropdownButton<int>(
            value: month,
            items: List.generate(
                12,
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text(_monthName(i + 1)))),
            onChanged: (m) {
              if (m != null) onChanged(year, m);
            },
          ),
          const SizedBox(width: AppSpacing.md),
          const Text('السنة:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          DropdownButton<int>(
            value: year,
            items: List.generate(
                10,
                (i) => DropdownMenuItem(
                    value: DateTime.now().year - i,
                    child: Text('${DateTime.now().year - i}'))),
            onChanged: (y) {
              if (y != null) onChanged(y, month);
            },
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),

        reportAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (r) => _PeriodSummaryView(report: r, fmt: fmt),
        ),
      ]),
    );
  }

  String _monthName(int m) => [
        '',
        'يناير',
        'فبراير',
        'مارس',
        'إبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر'
      ][m];
}

// ─── Yearly Tab ───────────────────────────────────────────────

class _YearlyTab extends ConsumerWidget {
  final int year;
  final void Function(int) onChanged;
  const _YearlyTab({required this.year, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    final reportAsync = ref.watch(FutureProvider(
        (ref) => ref.watch(reportServiceProvider).getYearlyReport(year)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        Row(children: [
          const Text('السنة:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          DropdownButton<int>(
            value: year,
            items: List.generate(
                10,
                (i) => DropdownMenuItem(
                    value: DateTime.now().year - i,
                    child: Text('${DateTime.now().year - i}'))),
            onChanged: (y) {
              if (y != null) onChanged(y);
            },
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        reportAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (r) => _PeriodSummaryView(report: r, fmt: fmt),
        ),
      ]),
    );
  }
}

// ─── Doctor Performance Tab ───────────────────────────────────

class _DoctorPerfTab extends ConsumerWidget {
  final int year;
  const _DoctorPerfTab({required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ReportPeriod(
        fromDate: ClinicDateUtils.yearStart(year),
        toDate: ClinicDateUtils.yearEnd(year));
    final async = ref.watch(doctorRevenueProvider(period));
    final fmt = NumberFormat('#,##0.00', 'ar');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (doctors) => doctors.isEmpty
            ? const EmptyState(
                title: 'لا توجد بيانات', icon: Icons.medical_services_outlined)
            : AppTable(
                headers: const [
                  'الطبيب',
                  'الزيارات',
                  'الإيرادات',
                  'العمولة %',
                  'مبلغ العمولة',
                  'الصافي'
                ],
                rows: doctors
                    .map((d) => [
                          Text(d.doctorName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${d.totalVisits}'),
                          Text('${fmt.format(d.grossRevenue)} USD',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                          Text('${d.commissionPct.toStringAsFixed(1)}%'),
                          Text('${fmt.format(d.commissionAmount)} USD',
                              style: const TextStyle(color: AppColors.warning)),
                          Text('${fmt.format(d.netRevenue)} USD',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ])
                    .toList(),
              ),
      ),
    );
  }
}

// ─── Period Summary View ──────────────────────────────────────

class _PeriodSummaryView extends StatelessWidget {
  final PeriodReport report;
  final NumberFormat fmt;
  const _PeriodSummaryView({required this.report, required this.fmt});

  @override
  Widget build(BuildContext context) => Column(children: [
        // Top stats
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
                label: 'الزيارات',
                value: '${report.totalVisits}',
                icon: Icons.local_hospital_outlined,
                color: AppColors.primary),
            StatCard(
                label: 'المحصّل',
                value: '${fmt.format(report.totalCollected)} USD',
                icon: Icons.payments_outlined,
                color: AppColors.success),
            StatCard(
                label: 'المصروفات',
                value: '${fmt.format(report.totalExpenses)} USD',
                icon: Icons.money_off_outlined,
                color: AppColors.error),
            StatCard(
                label: 'صافي الربح',
                value: '${fmt.format(report.netProfit)} USD',
                icon: Icons.trending_up,
                color: AppColors.secondary),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Monthly breakdown
        if (report.monthlyBreakdown.isNotEmpty)
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader(title: 'التفاصيل الشهرية'),
              const SizedBox(height: AppSpacing.md),
              AppTable(
                headers: const [
                  'الشهر',
                  'الزيارات',
                  'الإيرادات',
                  'المصروفات',
                  'الصافي'
                ],
                rows: report.monthlyBreakdown
                    .map((m) => [
                          Text(m.month,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${m.visits}'),
                          Text('${fmt.format(m.collected)} USD'),
                          Text('${fmt.format(m.expenses)} USD',
                              style: const TextStyle(color: AppColors.error)),
                          Text('${fmt.format(m.collected - m.expenses)} USD',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ])
                    .toList(),
              ),
            ]),
          ),
        const SizedBox(height: AppSpacing.lg),

        // Top procedures
        if (report.topProcedures.isNotEmpty)
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionHeader(title: 'أكثر الإجراءات'),
              const SizedBox(height: AppSpacing.md),
              AppTable(
                headers: const ['الإجراء', 'العدد', 'الإيرادات'],
                rows: report.topProcedures
                    .map((p) => [
                          Text(p.procedureName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${p.totalCount}'),
                          Text('${fmt.format(p.totalRevenue)} USD',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                        ])
                    .toList(),
              ),
            ]),
          ),
      ]);
}
