import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:clinic_app/core/providers/service_providers.dart';
import 'package:clinic_app/core/theme/app_theme.dart';
import 'package:clinic_app/core/utils/date_utils.dart';
import 'package:clinic_app/shared/widgets/app_widgets.dart';
import 'package:clinic_app/features/patients/domain/entities/patient.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root Screen
// ─────────────────────────────────────────────────────────────────────────────

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

    return Container(
      // ── Background gradient fills the whole screen ──────────────────────
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0F4FF), Color(0xFFF8FAFC), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Row 1: Header (logo + greeting + date) ─────────────────────
            _HeaderRow()
                .animate()
                .fadeIn(duration: 350.ms)
                .slideX(begin: -0.04),

            const SizedBox(height: AppSpacing.sm),

            // ── Row 2: Body (main content + right sidebar) ──────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left: Stats + Dossier + Pending ───────────────────────
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stats 4 cards
                        Expanded(
                          flex: 3,
                          child: daily.when(
                            loading: () => const _LoadingCard(),
                            error: (e, _) => ErrorView(message: e.toString()),
                            data: (report) => _StatsRow(report: report),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Patient dossier (search + recent)
                        Expanded(
                          flex: 3,
                          child: const _PatientDossierCard()
                              .animate()
                              .fadeIn(duration: 450.ms, delay: 80.ms)
                              .slideY(begin: 0.06),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Pending balances
                        Expanded(
                          flex: 4,
                          child: _PendingPatientsCard(
                                  balancesAsync: pendingBalances)
                              .animate()
                              .fadeIn(duration: 450.ms, delay: 120.ms),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // ── Right Sidebar ─────────────────────────────────────────
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Appointments
                        Expanded(
                          flex: 3,
                          child: _AppointmentsCard(apptCounts: apptCounts)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 60.ms),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Low stock
                        Expanded(
                          flex: 2,
                          child: _LowStockCard(lowStockAsync: lowStock)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 100.ms),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Cash box
                        Expanded(
                          flex: 2,
                          child: _CashBoxCard(cashBoxAsync: cashBox)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 140.ms),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Doctor stats
                        Expanded(
                          flex: 3,
                          child: daily.when(
                            loading: () => const _LoadingCard(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (report) => _DoctorStatsCard(report: report)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 180.ms),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Row  (logo · greeting · date · clock)
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'صباح الخير '
        : hour < 17
            ? 'مساء الخير '
            : ' مساء الخير ';
    final dateStr =
        ClinicDateUtils.formatArabicMonth(DateTime.now(), 'EEEE، d MMMM yyyy');

    return Row(
      children: [
        // ── Logo ────────────────────────────────────────────────────────
        Hero(
          tag: 'app-logo',
          child: Image.asset(
            'assets/images/logo.png',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.medical_services,
                  size: 46, color: AppColors.primary),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // ── Greeting ─────────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                greet,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Real-time clock ──────────────────────────────────────────────
        _RealTimeClock(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real-time clock
// ─────────────────────────────────────────────────────────────────────────────

class _RealTimeClock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              DateFormat('hh:mm:ss a').format(DateTime.now()),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row  (4 horizontal cards)
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final dynamic report;
  const _StatsRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');
    final cards = [
      _StatData(
        title: 'الزيارات اليوم',
        value: '${report.totalVisits}',
        subtitle: '${report.totalPatients} مريض',
        icon: Icons.people_outline,
        colors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        route: '/visits',
      ),
      _StatData(
        title: 'إجمالي الفواتير',
        value: '${fmt.format(report.totalInvoiced)} \$',
        subtitle: 'المبلغ المستحق',
        icon: Icons.receipt_long_outlined,
        colors: const [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
        route: '/invoices',
      ),
      _StatData(
        title: 'التحصيل الفعلي',
        value: '${fmt.format(report.totalCollected)} \$',
        subtitle: 'المقبوضات اليوم',
        icon: Icons.payments_outlined,
        colors: const [Color(0xFF10B981), Color(0xFF14B8A6)],
        route: '/invoices',
      ),
      _StatData(
        title: 'صافي الربح',
        value: '${fmt.format(report.netCash)} \$',
        subtitle: 'بعد المصروفات',
        icon: Icons.account_balance_outlined,
        colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
        route: '/cash-box',
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cards
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: e.key < cards.length - 1 ? AppSpacing.sm : 0),
                  child: _StatCard(data: e.value),
                ),
              ))
          .toList(),
    ).animate().fadeIn(duration: 450.ms, delay: 50.ms).slideY(begin: 0.08);
  }
}

class _StatData {
  final String title, value, subtitle, route;
  final IconData icon;
  final List<Color> colors;
  const _StatData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.route,
  });
}

class _StatCard extends StatefulWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.data.colors.first;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push(widget.data.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.data.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: base.withValues(alpha: _hovered ? 0.45 : 0.22),
                blurRadius: _hovered ? 24 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(widget.data.icon, color: Colors.white, size: 22),
                  ),
                  if (_hovered)
                    const Icon(Icons.arrow_forward_ios,
                            size: 12, color: Colors.white70)
                        .animate()
                        .fadeIn()
                        .slideX(begin: -0.4),
                ],
              ),
              const Spacer(),
              Text(widget.data.title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(widget.data.value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(widget.data.subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient Dossier Card
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientNotifierProvider);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_shared,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الوصول السريع للأضابير',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                      const Text('ابحث أو تصفح أحدث السجلات',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/patients'),
                  icon: const Icon(Icons.open_in_new,
                      size: 14, color: Colors.white),
                  label: const Text('كل السجلات',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  context.push('/patients?q=$v');
                }
              },
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المريض أو رقم الهاتف...',
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.primary, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.primary, size: 18),
                  onPressed: () {
                    if (_searchController.text.trim().isNotEmpty) {
                      context.push('/patients?q=${_searchController.text}');
                    }
                  },
                ),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
              ),
            ),
          ),

          // Recent dossiers
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: patientsAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => Text('خطأ: $e'),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                        title: 'لا يوجد سجلات',
                        icon: Icons.person_search_outlined);
                  }
                  final recent = list.take(10).toList();
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    itemBuilder: (_, i) => _DossierShortcut(patient: recent[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dossier Shortcut
// ─────────────────────────────────────────────────────────────────────────────

class _DossierShortcut extends StatelessWidget {
  final Patient patient;
  const _DossierShortcut({required this.patient});

  static const _gradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF14B8A6)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context) {
    final id = patient.id ?? 0;
    final gradient = _gradients[id % _gradients.length];
    return GestureDetector(
      onTap: () => context.push('/patients/$id'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(left: AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: gradient.first.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Text(
                    patient.name.isNotEmpty ? patient.name[0] : '?',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(patient.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 11)),
              Text('#$id',
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (60 * (id % 10)).ms)
        .scale(begin: const Offset(0.88, 0.88), curve: Curves.easeOutBack);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Patients Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingPatientsCard extends StatelessWidget {
  final AsyncValue<dynamic> balancesAsync;
  const _PendingPatientsCard({required this.balancesAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                const SectionHeader(title: 'مطالبات مالية معلقة'),
                const SizedBox(width: 6),
                balancesAsync.when(
                  data: (list) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${(list as List).length}',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
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

          // List
          Expanded(
            child: balancesAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (items) {
                final list = items as List;
                if (list.isEmpty) {
                  return const Center(
                    child: EmptyState(
                        title: 'لا يوجد مطالبات معلقة',
                        icon: Icons.check_circle_outline),
                  );
                }
                final shown = list.take(4).toList();
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: shown.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final item = shown[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 0),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(item.patientName[0],
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      title: Text(item.patientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        'آخر زيارة: ${item.lastActivityDate != null ? ClinicDateUtils.formatArabicMonth(item.lastActivityDate, 'd MMMM yyyy') : 'غير محدد'}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint),
                      ),
                      trailing: Text(
                        '${fmt.format(item.outstandingBalance)} \$',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w900,
                            fontSize: 14),
                      ),
                      onTap: () => context.push('/patients/${item.patientId}'),
                    ).animate().fadeIn(delay: (80 * i).ms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appointments Card (sidebar)
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentsCard extends StatelessWidget {
  final AsyncValue<Map<String, int>> apptCounts;
  const _AppointmentsCard({required this.apptCounts});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'مواعيد اليوم'),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: apptCounts.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (counts) {
                final pending = counts['pending'] ?? 0;
                final confirmed = counts['confirmed'] ?? 0;
                final completed = counts['completed'] ?? 0;
                final total = pending + confirmed + completed;

                if (total == 0) {
                  return const EmptyState(
                      title: 'لا يوجد مواعيد',
                      icon: Icons.calendar_today_outlined);
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    const SizedBox(height: 4),
                    _CompactApptRow(
                        label: 'مكتملة',
                        count: completed,
                        color: AppColors.success),
                    _CompactApptRow(
                        label: 'مؤكدة',
                        count: confirmed,
                        color: AppColors.primary),
                    _CompactApptRow(
                        label: 'انتظار',
                        count: pending,
                        color: AppColors.warning),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'إدارة المواعيد',
            compact: true,
            onPressed: () => context.push('/appointments'),
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
  const _CompactApptRow(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            Text('$count',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Low Stock Card (sidebar)
// ─────────────────────────────────────────────────────────────────────────────

class _LowStockCard extends StatelessWidget {
  final AsyncValue<dynamic> lowStockAsync;
  const _LowStockCard({required this.lowStockAsync});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(child: SectionHeader(title: 'نواقص المخزون')),
              Icon(Icons.inventory_2_outlined,
                  color: AppColors.error, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: lowStockAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (items) {
                final list = items as List;
                if (list.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد نواقص حالياً',
                        style:
                            TextStyle(color: AppColors.success, fontSize: 12)),
                  );
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: list
                      .take(3)
                      .map((item) => Row(
                            children: [
                              Expanded(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600))),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.errorSurface,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('${item.quantity}',
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cash Box Card (sidebar)
// ─────────────────────────────────────────────────────────────────────────────

class _CashBoxCard extends StatelessWidget {
  final dynamic cashBoxAsync;
  const _CashBoxCard({required this.cashBoxAsync});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.0', 'ar');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'حالة الصندوق'),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: cashBoxAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (box) => Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الرصيد الحالي',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${fmt.format(box.calculatedClosingBalance)} \$',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15),
                      ),
                    ],
                  ),
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Doctor Stats Card (sidebar)
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorStatsCard extends StatelessWidget {
  final dynamic report;
  const _DoctorStatsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'أداء الأطباء'),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: report.doctorStats.isEmpty
                ? const Center(
                    child: EmptyState(
                        title: 'لا يوجد بيانات',
                        icon: Icons.medical_services_outlined))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: (report.doctorStats as List)
                        .take(3)
                        .map<Widget>((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_pin,
                                      size: 14, color: AppColors.textHint),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(s.doctorName,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis)),
                                  Text('${s.visits} زيارة',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'تقرير الأداء',
            compact: true,
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segment Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentBar extends StatelessWidget {
  final int total;
  final List<_Segment> segments;
  const _SegmentBar({required this.total, required this.segments});

  @override
  Widget build(BuildContext context) => Container(
        height: 7,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: AppColors.borderLight),
        child: Row(
          children: segments.map((s) {
            if (s.value == 0) return const SizedBox.shrink();
            return Expanded(flex: s.value, child: Container(color: s.color));
          }).toList(),
        ),
      );
}

class _Segment {
  final int value;
  final Color color;
  final String label;
  const _Segment(
      {required this.value, required this.color, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading placeholder card
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const AppCard(
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
}
