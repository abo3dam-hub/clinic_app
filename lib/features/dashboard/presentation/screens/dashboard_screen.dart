// lib/features/dashboard/presentation/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:clinic_app/core/providers/service_providers.dart';
import 'package:clinic_app/core/theme/app_theme.dart';
import 'package:clinic_app/core/utils/date_utils.dart';
import 'package:clinic_app/shared/widgets/app_widgets.dart';
import 'package:clinic_app/features/cash_box/domain/entities/cash_box.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ClinicDateUtils.todayString();
    final daily = ref.watch(dailyReportProvider(today));
    final cashBox = ref.watch(cashBoxTodayProvider);
    final apptCounts = ref.watch(todayAppointmentCountsProvider);
    final lowStock = ref.watch(lowStockProvider);
    final pendingBalances = ref.watch(pendingBalancesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting & Welcome ──────────────────────────────────────────
          _Greeting().animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
          const SizedBox(height: AppSpacing.xl),

          // ── Main Layout ────────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1100;
              
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Content (Left)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          daily.when(
                            loading: () => const LoadingView(),
                            error: (e, _) => ErrorView(message: e.toString()),
                            data: (report) => _StatsGrid(report: report),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _PendingPatientsWidget(balancesAsync: pendingBalances),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    // Secondary Content (Right Sidebar)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _AppointmentsCard(apptCounts: apptCounts),
                          const SizedBox(height: AppSpacing.lg),
                          _LowStockCard(lowStockAsync: lowStock),
                          const SizedBox(height: AppSpacing.lg),
                          daily.when(
                            loading: () => const SizedBox(height: 100, child: LoadingView()),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (report) => _CashBoxCard(cashBoxAsync: cashBox, report: report),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          daily.when(
                            loading: () => const SizedBox(height: 100, child: LoadingView()),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (report) => _DoctorStatsCard(report: report),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Mobile/Tablet Stack
              return Column(
                children: [
                  daily.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(message: e.toString()),
                    data: (report) => _StatsGrid(report: report),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _AppointmentsCard(apptCounts: apptCounts),
                  const SizedBox(height: AppSpacing.lg),
                  _PendingPatientsWidget(balancesAsync: pendingBalances),
                  const SizedBox(height: AppSpacing.lg),
                  _LowStockCard(lowStockAsync: lowStock),
                  const SizedBox(height: AppSpacing.lg),
                  daily.when(
                    loading: () => const SizedBox(height: 100, child: LoadingView()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (report) => _CashBoxCard(cashBoxAsync: cashBox, report: report),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
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
    final greet = hour < 12 ? 'صباح الخير دكتور' : hour < 17 ? 'مساء الخير دكتور' : 'طاب مساؤك دكتور';
    final fmt = DateFormat('EEEE، d MMMM yyyy', 'ar');
    
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 2),
          ),
          child: const CircleAvatar(
            backgroundColor: AppColors.primarySurface,
            child: Icon(Icons.person_outline, size: 40, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greet,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(fmt.format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary, 
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
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
    final fmt = NumberFormat('#,##0.0', 'ar');
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 1.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _InteractiveStatCard(
              title: 'الزيارات اليوم',
              value: '${report.totalVisits}',
              subtitle: '${report.totalPatients} مريض مسجل',
              icon: Icons.people_outline,
              color: const Color(0xFF6366f1),
              onTap: () => context.push('/visits'),
            ),
            _InteractiveStatCard(
              title: 'إجمالي الفواتير',
              value: '${fmt.format(report.totalInvoiced)} \$',
              subtitle: 'المبلغ الإجمالي المستحق',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF0ea5e9),
              onTap: () => context.push('/invoices'),
            ),
            _InteractiveStatCard(
              title: 'التحصيل الفعلي',
              value: '${fmt.format(report.totalCollected)} \$',
              subtitle: 'المقبوضات النقدية اليوم',
              icon: Icons.payments_outlined,
              color: const Color(0xFF10b981),
              onTap: () => context.push('/invoices'), 
            ),
            _InteractiveStatCard(
              title: 'صافي الربح',
              value: '${fmt.format(report.netCash)} \$',
              subtitle: 'بعد خصم المصروفات',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFf59e0b),
              onTap: () => context.push('/cash-box'),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1);
      },
    );
  }
}

class _InteractiveStatCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InteractiveStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_InteractiveStatCard> createState() => _InteractiveStatCardState();
}

class _InteractiveStatCardState extends State<_InteractiveStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered ? widget.color.withOpacity(0.5) : AppColors.border,
              width: 1.5,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.color.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  if (_isHovered)
                    Icon(Icons.arrow_forward_ios, size: 14, color: widget.color)
                        .animate()
                        .fadeIn()
                        .slideX(begin: -0.5),
                ],
              ),
              const Spacer(),
              Text(widget.title, 
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.value, 
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                )),
              const SizedBox(height: 4),
              Text(widget.subtitle, 
                style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pending Patients Widget ─────────────────────────────────

class _PendingPatientsWidget extends StatelessWidget {
  final AsyncValue<dynamic> balancesAsync;
  const _PendingPatientsWidget({required this.balancesAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');
    
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const SectionHeader(title: 'مطالبات مالية معلقة'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: balancesAsync.when(
                    data: (list) => Text('${(list as List).length}', 
                      style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    loading: () => const SizedBox.shrink(),
                    error: (_,__) => const SizedBox.shrink(),
                  ),
                ),
                const Spacer(),
                SecondaryButton(
                  label: 'عرض الكل', 
                  compact: true,
                  onPressed: () => context.push('/accounting'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          balancesAsync.when(
            loading: () => const SizedBox(height: 200, child: LoadingView()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ErrorView(message: e.toString()),
            ),
            data: (items) {
              final list = items as List;
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: EmptyState(title: 'لا يوجد مطالبات معلقة حالياً', icon: Icons.check_circle_outline),
                );
              }
              
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length > 5 ? 5 : list.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySurface,
                      child: Text(item.patientName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('آخر زيارة: ${item.lastActivityDate != null ? DateFormat('yyyy-MM-dd').format(item.lastActivityDate) : 'غير محدد'}', 
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${fmt.format(item.outstandingBalance)} \$', 
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w900, fontSize: 16)),
                        const Text('مبلغ معلق', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ],
                    ),
                    onTap: () => context.push('/patients/${item.patientId}'),
                  ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.05);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Cards (Restored & Refined) ─────────────────────────

class _AppointmentsCard extends StatelessWidget {
  final AsyncValue<Map<String, int>> apptCounts;
  const _AppointmentsCard({required this.apptCounts});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'مواعيد اليوم'),
          const SizedBox(height: AppSpacing.lg),
          apptCounts.when(
            loading: () => const LoadingView(),
            error: (err, _) => ErrorView(message: err.toString()),
            data: (counts) {
              final pending = counts['pending'] ?? 0;
              final confirmed = counts['confirmed'] ?? 0;
              final completed = counts['completed'] ?? 0;
              final total = pending + confirmed + completed;
              
              if (total == 0) return const EmptyState(title: 'لا يوجد مواعيد', icon: Icons.calendar_today_outlined);

              return Column(
                children: [
                  _SegmentBar(
                    total: total,
                    segments: [
                      _Segment(value: completed, color: AppColors.success, label: 'تم'),
                      _Segment(value: confirmed, color: AppColors.primary, label: 'مؤكد'),
                      _Segment(value: pending, color: AppColors.warning, label: 'انتظار'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CompactApptRow(label: 'مكتملة', count: completed, color: AppColors.success),
                  _CompactApptRow(label: 'مؤكدة', count: confirmed, color: AppColors.primary),
                  _CompactApptRow(label: 'قيد الانتظار', count: pending, color: AppColors.warning),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: 'إدارة المواعيد', 
              compact: true,
              onPressed: () => context.push('/appointments'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactApptRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CompactApptRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

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
              const SectionHeader(title: 'نواقص المخزون'),
              const Icon(Icons.inventory_2_outlined, color: AppColors.error, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          lowStockAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (items) {
              final list = items as List;
              if (list.isEmpty) {
                return const Text('لا يوجد نواقص حالياً', style: TextStyle(color: AppColors.success, fontSize: 13));
              }
              return Column(
                children: [
                  ...list.take(3).map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(4)),
                          child: Text('${item.quantity}', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      label: 'المخزون الكامل', 
                      compact: true,
                      onPressed: () => context.push('/inventory'),
                    ),
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

class _CashBoxCard extends StatelessWidget {
  final dynamic cashBoxAsync;
  final dynamic report;
  const _CashBoxCard({required this.cashBoxAsync, required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'حالة الصندوق'),
          const SizedBox(height: AppSpacing.md),
          cashBoxAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (box) => Column(
              children: [
                _CashDetailRow('الرصيد الحالي', fmt.format(box.calculatedClosingBalance), AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'إغلاق الصندوق', 
                    compact: true,
                    onPressed: () => context.push('/cash-box'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CashDetailRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      Text('$value \$', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
    ],
  );
}

class _DoctorStatsCard extends StatelessWidget {
  final dynamic report;
  const _DoctorStatsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'أداء الأطباء'),
          const SizedBox(height: AppSpacing.md),
          if (report.doctorStats.isEmpty)
            const EmptyState(title: 'لا يوجد بيانات', icon: Icons.medical_services_outlined)
          else
            ...report.doctorStats.take(2).map((s) => _SimpleDoctorRow(name: s.doctorName, visits: s.visits)),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: 'تقرير الأداء', 
              compact: true,
              onPressed: () => context.push('/reports'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleDoctorRow extends StatelessWidget {
  final String name;
  final int visits;
  const _SimpleDoctorRow({required this.name, required this.visits});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.person_pin, size: 16, color: AppColors.textHint),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Text('$visits زيارة', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _SegmentBar extends StatelessWidget {
  final int total;
  final List<_Segment> segments;

  const _SegmentBar({required this.total, required this.segments});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: AppColors.borderLight),
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

class _Segment {
  final int value;
  final Color color;
  final String label;
  _Segment({required this.value, required this.color, required this.label});
}
