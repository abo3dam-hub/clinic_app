// lib/features/dashboard/presentation/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ClinicDateUtils.todayString();
    final daily = ref.watch(dailyReportProvider(today));
    final cashBox = ref.watch(cashBoxTodayProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ──────────────────────────────────────────
          _Greeting(),
          const SizedBox(height: AppSpacing.lg),

          // ── Stats grid (responsive) ───────────────────────────
          daily.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (report) => _StatsGrid(report: report),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Cash box + Doctor stats ───────────────────────────
          daily.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (report) => _BottomRow(
              cashBoxAsync: cashBox,
              report: report,
            ),
          ),

          // Bottom breathing room
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ─── Greeting ─────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'صباح الخير'
        : hour < 17
            ? 'مساء الخير'
            : 'مساء النور';
    final fmt = DateFormat('EEEE، d MMMM yyyy', 'ar');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greet,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(fmt.format(DateTime.now()),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textHint)),
      ],
    );
  }
}

// ─── Stats Grid (responsive) ──────────────────────────────────
// FIX: Was a hard-coded GridView.count(crossAxisCount: 4) which
// forced 4 columns regardless of screen width.  LayoutBuilder now
// picks 2 or 4 columns based on available width, and the aspect
// ratio is capped so cards never become uncomfortably tall.

class _StatsGrid extends StatelessWidget {
  final dynamic report;
  const _StatsGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    final cards = [
      StatCard(
        label: 'زيارات اليوم',
        value: '${report.totalVisits}',
        icon: Icons.local_hospital_outlined,
        color: AppColors.primary,
        subtitle: '${report.totalPatients} مريض',
      ),
      StatCard(
        label: 'إجمالي الفواتير',
        value: '${fmt.format(report.totalInvoiced)} USD',
        icon: Icons.receipt_long_outlined,
        color: AppColors.secondary,
      ),
      StatCard(
        label: 'المحصّل اليوم',
        value: '${fmt.format(report.totalCollected)} USD',
        icon: Icons.payments_outlined,
        color: AppColors.success,
      ),
      StatCard(
        label: 'صافي الخزينة',
        value: '${fmt.format(report.netCash)} USD',
        icon: Icons.account_balance_wallet_outlined,
        color: report.netCash >= 0 ? AppColors.primary : AppColors.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 2 : 4;
        final cellWidth =
            (constraints.maxWidth - (crossCount - 1) * AppSpacing.md) /
                crossCount;
        // Keep cards at a comfortable fixed height regardless of width
        final aspectRatio = (cellWidth / 110).clamp(1.6, 3.0);

        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

// ─── Bottom Row ───────────────────────────────────────────────
// FIX: Extracted to its own widget and made responsive.
// On narrow windows the two cards stack vertically instead of
// overflowing side-by-side.

class _BottomRow extends StatelessWidget {
  final dynamic cashBoxAsync;
  final dynamic report;
  const _BottomRow({required this.cashBoxAsync, required this.report});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CashBoxCard(cashBoxAsync: cashBoxAsync, report: report),
              const SizedBox(height: AppSpacing.md),
              _DoctorStatsCard(report: report),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child:
                    _CashBoxCard(cashBoxAsync: cashBoxAsync, report: report)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _DoctorStatsCard(report: report)),
          ],
        );
      },
    );
  }
}

// ─── Cash Box Card ────────────────────────────────────────────

class _CashBoxCard extends StatelessWidget {
  final dynamic cashBoxAsync;
  final dynamic report;
  const _CashBoxCard({required this.cashBoxAsync, required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الخزينة اليومية'),
          const SizedBox(height: AppSpacing.md),
          cashBoxAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (box) => Column(
              children: [
                _CashRow('الرصيد الافتتاحي', fmt.format(box.openingBalance),
                    AppColors.textSecondary),
                _CashRow('إجمالي الإيرادات', fmt.format(report.totalCollected),
                    AppColors.success),
                _CashRow('إجمالي المصروفات', fmt.format(report.totalExpenses),
                    AppColors.error),
                const Divider(height: AppSpacing.lg),
                _CashRow('الرصيد الختامي',
                    fmt.format(box.calculatedClosingBalance), AppColors.primary,
                    bold: true),
                if (box.isClosed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: StatusChip(
                        label: 'الخزينة مغلقة', color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _CashRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color:
                        bold ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14)),
            Text('$value USD',
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      );
}

// ─── Doctor Stats Card ────────────────────────────────────────

class _DoctorStatsCard extends StatelessWidget {
  final dynamic report;
  const _DoctorStatsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'أداء الأطباء اليوم'),
          const SizedBox(height: AppSpacing.md),
          if (report.doctorStats.isEmpty)
            const EmptyState(
              title: 'لا توجد زيارات اليوم',
              icon: Icons.medical_services_outlined,
            )
          else
            ...report.doctorStats.map((s) => _DoctorRow(
                  name: s.doctorName,
                  visits: s.visits,
                  revenue: fmt.format(s.revenue),
                  commission: fmt.format(s.commission),
                )),
        ],
      ),
    );
  }
}

class _DoctorRow extends StatelessWidget {
  final String name;
  final int visits;
  final String revenue;
  final String commission;

  const _DoctorRow({
    required this.name,
    required this.visits,
    required this.revenue,
    required this.commission,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.person, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('$visits زيارة',
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$revenue USD',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('عمولة: $commission',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
}
