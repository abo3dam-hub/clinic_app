import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

// استيراد نفس الـ Providers والـ Entities الخاصة بمشروعك
import 'package:clinic_app/core/providers/service_providers.dart';
import 'package:clinic_app/core/theme/app_theme.dart';
import 'package:clinic_app/core/utils/date_utils.dart';
import 'package:clinic_app/shared/widgets/app_widgets.dart';
import 'package:clinic_app/features/patients/domain/entities/patient.dart';
import 'package:clinic_app/features/cash_box/domain/entities/cash_box.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استدعاء كافة الـ Providers الأصلية بدون أي تغيير
    final today = ClinicDateUtils.todayString();
    final daily = ref.watch(dailyReportProvider(today));
    final cashBox = ref.watch(cashBoxTodayProvider);
    final apptCounts = ref.watch(todayAppointmentCountsProvider);
    final lowStock = ref.watch(lowStockProvider);
    final pendingBalances = ref.watch(pendingBalancesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F5F9), Color(0xFFF8FAFC), Color(0xFFF1FDF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Row 1: Header (logo + greeting + date) ──
              _HeaderRow()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.1),

              const SizedBox(height: 24),

              // ── Row 2: Main Grid Layout ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left Side: Stats and Main Cards (Flex 3) ──
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          // Stats Cards Row
                          SizedBox(
                            height: 140,
                            child: daily.when(
                              loading: () => const _LoadingPlaceholder(),
                              error: (e, _) => ErrorView(message: e.toString()),
                              data: (report) => _StatsRow(report: report),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Patient Dossier & Pending Balances
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: const _PatientDossierCard()
                                      .animate()
                                      .fadeIn(delay: 200.ms),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 6,
                                  child: _PendingPatientsCard(
                                          balancesAsync: pendingBalances)
                                      .animate()
                                      .fadeIn(delay: 300.ms),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    // ── Right Side: Sidebar Monitoring (Flex 1) ──
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Appointments Card
                          Expanded(
                            flex: 4,
                            child: _SidebarAppointments(apptCounts: apptCounts),
                          ),
                          const SizedBox(height: 20),
                          // Low Stock Card
                          Expanded(
                            flex: 3,
                            child: _SidebarLowStock(lowStockAsync: lowStock),
                          ),
                          const SizedBox(
                              height: 3, child: SizedBox.shrink()), // Spacer
                          const SizedBox(height: 20),
                          // Cash Box Card
                          Expanded(
                            flex: 3,
                            child: _SidebarCashBox(cashBoxAsync: cashBox),
                          ),
                        ],
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header (Logo, Greeting, Clock) - نفس وظائف ملفك تماماً
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final dateStr =
        ClinicDateUtils.formatArabicMonth(DateTime.now(), 'EEEE، d MMMM yyyy');

    return Row(
      children: [
        Hero(
          tag: 'app-logo',
          child: Container(
            child: Image.asset(
              'assets/images/logo.png',
              width: 70,
              height: 70,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 100,
                  color: AppColors.primarySurface,
                  child: const Icon(Icons.medical_services,
                      color: AppColors.primary, size: 35)),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greet,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_month,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(dateStr,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        _RealTimeClock(),
      ],
    );
  }
}

class _RealTimeClock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Text(
          DateFormat('hh:mm:ss a').format(DateTime.now()),
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF1E293B),
              letterSpacing: 1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row (The 4 Horizontal Cards)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final dynamic report;
  const _StatsRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');
    return Row(
      children: [
        _ModernStatCard(
            title: 'زيارات اليوم',
            value: '${report.totalVisits}',
            subtitle: '${report.totalPatients} مريض',
            icon: Icons.people_outline,
            color: const Color.fromARGB(255, 65, 142, 204),
            route: '/visits'),
        const SizedBox(width: 16),
        _ModernStatCard(
            title: 'إجمالي الفواتير',
            value: '${fmt.format(report.totalInvoiced)} \$',
            subtitle: 'المبلغ المستحق',
            icon: Icons.receipt_long_outlined,
            color: const Color.fromARGB(255, 81, 193, 245),
            route: '/invoices'),
        const SizedBox(width: 16),
        _ModernStatCard(
            title: 'التحصيل الفعلي',
            value: '${fmt.format(report.totalCollected)} \$',
            subtitle: 'المقبوضات اليوم',
            icon: Icons.payments_outlined,
            color: const Color(0xFF10B981),
            route: '/invoices'),
        const SizedBox(width: 16),
        _ModernStatCard(
            title: 'صافي الربح',
            value: '${fmt.format(report.netCash)} \$',
            subtitle: 'بعد المصروفات',
            icon: Icons.account_balance_outlined,
            color: const Color(0xFFF59E0B),
            route: '/cash-box'),
      ],
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title, value, subtitle, route;
  final IconData icon;
  final Color color;

  const _ModernStatCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.route});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Dossier Card (Search & Recent)
// ─────────────────────────────────────────────────────────────────────────────
class _PatientDossierCard extends ConsumerStatefulWidget {
  const _PatientDossierCard();
  @override
  ConsumerState<_PatientDossierCard> createState() =>
      _PatientDossierCardState();
}

class _PatientDossierCardState extends ConsumerState<_PatientDossierCard> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 30)
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.folder_shared_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                const Text('الأضابير الطبية',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                    onPressed: () => context.push('/patients'),
                    child: const Text('كل السجلات')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              onSubmitted: (v) =>
                  v.trim().isNotEmpty ? context.push('/patients?q=$v') : null,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المريض أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: patientsAsync.when(
              data: (list) => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.take(6).length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF0F4FF),
                        child: Text(p.name[0],
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold))),
                    title: Text(p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(p.phone ?? 'بدون هاتف',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text('#${p.id}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold)),
                    onTap: () => context.push('/patients/${p.id}'),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Patients (Accounting)
// ─────────────────────────────────────────────────────────────────────────────
class _PendingPatientsCard extends StatelessWidget {
  final AsyncValue<dynamic> balancesAsync;
  const _PendingPatientsCard({required this.balancesAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 30)
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Text('مطالبات مالية معلقة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                balancesAsync.maybeWhen(
                  data: (list) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${(list as List).length}',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  orElse: () => const SizedBox(),
                ),
                const Spacer(),
                IconButton.filledTonal(
                    onPressed: () => context.push('/accounting'),
                    icon: const Icon(Icons.arrow_outward, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: balancesAsync.when(
              data: (items) {
                final list = items as List;
                if (list.isEmpty)
                  return const Center(
                      child: EmptyState(
                          title: 'لا يوجد مديونيات',
                          icon: Icons.check_circle_outline));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: list.take(5).length,
                  itemBuilder: (context, i) {
                    final item = list[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              child: Text(item.patientName[0],
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.patientName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text(
                                    'آخر نشاط: ${item.lastActivityDate != null ? DateFormat('d MMM').format(item.lastActivityDate) : '-'}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text('${fmt.format(item.outstandingBalance)} \$',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar: Appointments (With original Segment Bar)
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarAppointments extends StatelessWidget {
  final AsyncValue<Map<String, int>> apptCounts;
  const _SidebarAppointments({required this.apptCounts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 20)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مواعيد اليوم',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: apptCounts.when(
              data: (counts) {
                final pending = counts['pending'] ?? 0;
                final confirmed = counts['confirmed'] ?? 0;
                final completed = counts['completed'] ?? 0;
                final total = pending + confirmed + completed;
                if (total == 0)
                  return const Center(
                      child: Text('لا يوجد مواعيد',
                          style: TextStyle(fontSize: 12, color: Colors.grey)));

                return Column(
                  children: [
                    _SegmentBar(total: total, segments: [
                      _Segment(
                          value: completed,
                          color: AppColors.success,
                          label: 'تم'),
                      _Segment(
                          value: confirmed,
                          color: AppColors.primary,
                          label: 'مؤكد'),
                      _Segment(
                          value: pending,
                          color: AppColors.warning,
                          label: 'انتظار'),
                    ]),
                    const SizedBox(height: 16),
                    _apptRow('مكتملة', completed, AppColors.success),
                    _apptRow('مؤكدة', confirmed, AppColors.primary),
                    _apptRow('انتظار', pending, AppColors.warning),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ),
          SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                  label: 'إدارة المواعيد',
                  compact: true,
                  onPressed: () => context.push('/appointments'))),
        ],
      ),
    );
  }

  Widget _apptRow(String label, int val, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text('$val',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar: Low Stock
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarLowStock extends StatelessWidget {
  final AsyncValue<dynamic> lowStockAsync;
  const _SidebarLowStock({required this.lowStockAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.inventory_2_outlined,
                color: Colors.orangeAccent, size: 18),
            SizedBox(width: 8),
            Text('نواقص المخزون',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: lowStockAsync.when(
              data: (items) {
                final list = items as List;
                if (list.isEmpty)
                  return const Center(
                      child: Text('المخزون مكتمل',
                          style: TextStyle(
                              color: Colors.greenAccent, fontSize: 11)));
                return ListView.builder(
                  itemCount: list.take(3).length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(list[i].name,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text('${list[i].quantity}',
                              style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold)),
                        ]),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar: Cash Box (The Interactive Gradient Card)
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarCashBox extends StatelessWidget {
  final AsyncValue<CashBox> cashBoxAsync;
  const _SidebarCashBox({required this.cashBoxAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'ar');
    return cashBoxAsync.when(
      data: (box) {
        final closing = box.calculatedClosingBalance;
        final isProfit = closing >= 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfit
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color:
                      (isProfit ? Colors.green : Colors.red).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رصيد الصندوق',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              FittedBox(
                  child: Text('${fmt.format(closing)} \$',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900))),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: box.totalIncome > 0
                      ? (box.totalExpenses / box.totalIncome).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniCash('وارد', '${fmt.format(box.totalIncome)}'),
                  _miniCash('صادر', '${fmt.format(box.totalExpenses)}'),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const _LoadingPlaceholder(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _miniCash(String label, String val) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(val,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Original Helper Components (Segment Bar & Loading)
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentBar extends StatelessWidget {
  final int total;
  final List<_Segment> segments;
  const _SegmentBar({required this.total, required this.segments});
  @override
  Widget build(BuildContext context) => Container(
        height: 8,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFFF1F5F9)),
        child: Row(
            children: segments
                .map((s) => s.value == 0
                    ? const SizedBox()
                    : Expanded(flex: s.value, child: Container(color: s.color)))
                .toList()),
      );
}

class _Segment {
  final int value;
  final Color color;
  final String label;
  const _Segment(
      {required this.value, required this.color, required this.label});
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
}
