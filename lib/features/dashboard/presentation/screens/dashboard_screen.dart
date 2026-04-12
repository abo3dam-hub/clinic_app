// lib/features/dashboard/presentation/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final apptCounts = ref.watch(todayAppointmentCountsProvider);
    final lowStock = ref.watch(lowStockProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ──────────────────────────────────────────
          _Greeting().animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
          const SizedBox(height: AppSpacing.lg),

          // ── Main Financial & Medical Stats Grid ───────────────
          daily.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (report) => _StatsGrid(report: report)
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.1),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Dashboard Metrics Row ─────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final crossAxis = isWide ? CrossAxisAlignment.start : CrossAxisAlignment.stretch;
              Widget rowOrCol(List<Widget> children) {
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: children[1]),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: w,
                  )).toList(),
                );
              }

              return rowOrCol([
                // 1. Appointments & Inventory
                Column(
                  mainAxisSize: MainAxisSize.min, // Added
                  crossAxisAlignment: crossAxis,
                  children: [
                    _AppointmentsCard(apptCounts: apptCounts),
                    const SizedBox(height: AppSpacing.md),
                    _LowStockCard(lowStockAsync: lowStock),
                  ],
                ),

                // 2. Cash Box & Doctors
                Column(
                  mainAxisSize: MainAxisSize.min, // Added
                  crossAxisAlignment: crossAxis,
                  children: [
                    daily.when(
                      loading: () => const SizedBox(height: 100, child: LoadingView()),
                      error: (_,__) => const SizedBox.shrink(),
                      data: (report) => _CashBoxCard(cashBoxAsync: cashBox, report: report),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    daily.when(
                      loading: () => const SizedBox(height: 100, child: LoadingView()),
                      error: (_,__) => const SizedBox.shrink(),
                      data: (report) => _DoctorStatsCard(report: report),
                    ),
                  ],
                ),
              ]).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.05);
            },
          ),
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
    final greet = hour < 12 ? 'صباح الخير' : hour < 17 ? 'مساء الخير' : 'مساء النور';
    final icon = hour < 12 ? Icons.wb_sunny : hour < 17 ? Icons.wb_cloudy : Icons.nights_stay;
    final fmt = DateFormat('EEEE، d MMMM yyyy', 'ar');
    return Row(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greet,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(fmt.format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textHint, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ─── Modern Stats Grid ────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final dynamic report;
  const _StatsGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 700 ? 2 : 4;
        final cellWidth = (constraints.maxWidth - (crossCount - 1) * AppSpacing.md) / crossCount;
        final aspectRatio = (cellWidth / 120).clamp(1.5, 3.0);

        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ModernStatCard(
              title: 'الزيارات اليوم',
              value: '${report.totalVisits}',
              subtitle: '${report.totalPatients} مريض',
              icon: Icons.personal_injury,
              gradient: const [Color(0xFF3b82f6), Color(0xFF2563eb)],
            ),
            _ModernStatCard(
              title: 'الإيرادات اليومية',
              value: '${fmt.format(report.totalInvoiced)} \$',
              subtitle: 'إجمالي الفواتير الصادرة',
              icon: Icons.monetization_on,
              gradient: const [Color(0xFF10b981), Color(0xFF059669)],
            ),
            _ModernStatCard(
              title: 'التحصيل',
              value: '${fmt.format(report.totalCollected)} \$',
              subtitle: 'نقد / بطاقة / تحويل',
              icon: Icons.account_balance_wallet,
              gradient: const [Color(0xFF8b5cf6), Color(0xFF7c3aed)],
            ),
            _ModernStatCard(
              title: 'صافي الصندوق',
              value: '${fmt.format(report.netCash)} \$',
              subtitle: 'بعد الخصم والمصروفات',
              icon: Icons.inventory_2,
              gradient: report.netCash >= 0 ? const [Color(0xFFf59e0b), Color(0xFFd97706)] : const [Color(0xFFef4444), Color(0xFFdc2626)],
            ),
          ],
        );
      },
    );
  }
}

class _ModernStatCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  @override
  State<_ModernStatCard> createState() => _ModernStatCardState();
}

class _ModernStatCardState extends State<_ModernStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            if (_hovered)
              BoxShadow(color: widget.gradient.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
            else
               BoxShadow(color: widget.gradient.last.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias, // Keep icon clipped inside card
        child: Stack(
          children: [
            // Large background icon (4x larger)
            Positioned(
              bottom: -10,
              left: -10,
              child: Icon(
                widget.icon,
                size: 80,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(widget.title, 
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Icon(widget.icon, color: Colors.white.withOpacity(0.8), size: 18),
                    ],
                  ),
                  const Spacer(),
                  Text(widget.value, 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(widget.subtitle, 
                    style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Appointments Breakdown ───────────────────────────────────

class _AppointmentsCard extends StatelessWidget {
  final AsyncValue<Map<String, int>> apptCounts;
  const _AppointmentsCard({required this.apptCounts});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'حالة المواعيد اليوم'),
          const SizedBox(height: AppSpacing.md),
          apptCounts.when(
            loading: () => const LoadingView(),
            error: (err, _) => ErrorView(message: err.toString()),
            data: (counts) {
              if (counts.isEmpty) return const EmptyState(title: 'لا توجد مواعيد اليوم', icon: Icons.calendar_today);
              final pending = counts['pending'] ?? 0;
              final confirmed = counts['confirmed'] ?? 0;
              final completed = counts['completed'] ?? 0;
              final cancelled = counts['cancelled'] ?? 0;
              final total = pending + confirmed + completed + cancelled;
              if (total == 0) return const EmptyState(title: 'لا توجد مواعيد', icon: Icons.calendar_today);

              return Column(
                children: [
                  _SegmentBar(
                    total: total,
                    segments: [
                      _Segment(value: completed, color: AppColors.success, label: 'مكتمل'),
                      _Segment(value: confirmed, color: AppColors.primary, label: 'مؤكد'),
                      _Segment(value: pending, color: AppColors.warning, label: 'قيد الانتظار'),
                      _Segment(value: cancelled, color: AppColors.error, label: 'ملغي'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ApptLegendItem(label: 'مكتمل', count: completed, color: AppColors.success),
                      _ApptLegendItem(label: 'مؤكد', count: confirmed, color: AppColors.primary),
                      _ApptLegendItem(label: 'انتظار', count: pending, color: AppColors.warning),
                      _ApptLegendItem(label: 'ملغي', count: cancelled, color: AppColors.error),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Segment {
  final int value;
  final Color color;
  final String label;
  _Segment({required this.value, required this.color, required this.label});
}

class _SegmentBar extends StatelessWidget {
  final int total;
  final List<_Segment> segments;

  const _SegmentBar({required this.total, required this.segments});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: segments.map((s) {
          if (s.value == 0) return const SizedBox.shrink();
          return Expanded(
            flex: s.value,
            child: Container(color: s.color),
          );
        }).toList(),
      ),
    );
  }
}

class _ApptLegendItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _ApptLegendItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─── Low Stock Card ───────────────────────────────────────────

class _LowStockCard extends StatelessWidget {
  final AsyncValue<dynamic> lowStockAsync;
  const _LowStockCard({required this.lowStockAsync});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: 'تنبيهات المخزون'),
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          lowStockAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (items) {
              final list = items as List;
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.successSurface, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('المخزون بوضع ممتاز، لا يوجد نواقص', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length > 5 ? 5 : list.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Text('${item.quantity}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('الحد: ${item.minQuantity}', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
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
          const SectionHeader(title: 'حركة الصندوق التفصيلية'),
          const SizedBox(height: AppSpacing.md),
          cashBoxAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (box) => Column(
              children: [
                _CashRow('الرصيد الافتتاحي', fmt.format(box.openingBalance), AppColors.textSecondary),
                _CashRow('إجمالي المقبوضات', fmt.format(report.totalCollected), AppColors.success, bg: AppColors.successSurface),
                _CashRow('إجمالي المصروفات', fmt.format(report.totalExpenses), AppColors.error, bg: AppColors.errorSurface),
                const Divider(height: AppSpacing.lg),
                _CashRow('الرصيد الختامي المتوقع', fmt.format(box.calculatedClosingBalance), AppColors.primary, bold: true, size: 16),
                if (box.isClosed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: StatusChip(label: 'تم إغلاق الصندوق', color: AppColors.textHint),
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
  final double size;
  final Color? bg;
  const _CashRow(this.label, this.value, this.color, {this.bold = false, this.size = 14, this.bg});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: bg ?? Colors.transparent,
          borderRadius: BorderRadius.circular(8)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: size - 1)),
            Text('$value \$', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size)),
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
          const SectionHeader(title: 'أداء الأطباء اليوم '),
          const SizedBox(height: AppSpacing.md),
          if (report.doctorStats.isEmpty)
            const EmptyState(
              title: 'لا يوجد أداء مسجل اليوم',
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

  const _DoctorRow({required this.name, required this.visits, required this.revenue, required this.commission});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySurface,
              child: const Icon(Icons.person, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$visits مريض عاينهم', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$revenue \$', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text('عمولة: $commission', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
}
