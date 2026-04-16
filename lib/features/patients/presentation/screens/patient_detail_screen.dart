import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:clinic_app/core/providers/service_providers.dart';
import 'package:clinic_app/core/utils/date_utils.dart';
import 'package:clinic_app/core/theme/app_theme.dart';
import 'package:clinic_app/shared/widgets/app_widgets.dart';
import 'package:clinic_app/features/patients/domain/entities/patient.dart';
import 'package:clinic_app/features/invoices/domain/entities/invoice.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final int patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider(widget.patientId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.refresh(patientProfileProvider(widget.patientId))),
        data: (profile) {
          if (profile == null)
            return const Center(child: Text('المريض غير موجود'));

          return CustomScrollView(
            slivers: [
              // ── Header العصري مع خلفية متدرجة ──
              _ModernProfileHeader(profile: profile),

              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Sidebar: بيانات الملف الشخصي (Fixed Width) ──
                      Expanded(
                        flex: 1,
                        child: _PatientSidebarInfo(profile: profile)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: -0.1),
                      ),

                      const SizedBox(width: 24),

                      // ── Main Content: التايم لاين العصري ──
                      Expanded(
                        flex: 3,
                        child: _ModernDossierTimeline(profile: profile),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: Modern Hero Section
// ─────────────────────────────────────────────────────────────────────────────
class _ModernProfileHeader extends StatelessWidget {
  final PatientProfile profile;
  const _ModernProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFF1E293B),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                  radius: 100, backgroundColor: Colors.white.withOpacity(0.03)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 60, 32, 20),
              child: Row(
                children: [
                  _AvatarBadge(name: profile.patient.name),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(profile.patient.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(width: 12),
                            if (profile.patient.isActive)
                              _StatusBadge(label: 'نشط', color: Colors.green)
                            else
                              _StatusBadge(
                                  label: 'غير نشط', color: Colors.redAccent),
                          ],
                        ),
                        Text('رقم الملف: #${profile.patient.id}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 16)),
                      ],
                    ),
                  ),
                  _QuickBalanceWidget(balance: profile.outstandingBalance),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: () => context
                        .push('/visits/new?patientId=${profile.patient.id}'),
                    icon: const Icon(Icons.add),
                    label: const Text('زيارة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
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
// Sidebar: Patient Personal Info
// ─────────────────────────────────────────────────────────────────────────────
class _PatientSidebarInfo extends StatelessWidget {
  final PatientProfile profile;
  const _PatientSidebarInfo({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('البيانات الشخصية',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const Divider(height: 32),
              _InfoRow(
                  icon: Icons.phone_android,
                  label: 'رقم الهاتف',
                  value: profile.patient.phone ?? '-'),
              _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'تاريخ الميلاد',
                  value: profile.patient.birthDate ?? '-'),
              _InfoRow(
                  icon: Icons.wc_rounded,
                  label: 'الجنس',
                  value: profile.patient.gender == 'male' ? 'ذكر' : 'أنثى'),
              _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'العنوان',
                  value: profile.patient.address ?? '-'),
              _InfoRow(
                  icon: Icons.history_edu,
                  label: 'تاريخ التسجيل',
                  value: ClinicDateUtils.formatArabicMonth(
                      profile.patient.createdAt, 'yyyy/MM/dd')),
            ],
          ),
        ),
        if (profile.patient.notes?.isNotEmpty ?? false) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('ملاحظات طبية',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(profile.patient.notes!,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline: The Modern Visit Cards
// ─────────────────────────────────────────────────────────────────────────────
class _ModernDossierTimeline extends StatelessWidget {
  final PatientProfile profile;
  const _ModernDossierTimeline({required this.profile});

  @override
  Widget build(BuildContext context) {
    final visits = profile.visits
      ..sort((a, b) => b.visit.visitDate.compareTo(a.visit.visitDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('سجل المراجعات',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${visits.length} زيارات',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (visits.isEmpty)
          const Center(
              child: EmptyState(
                  title: 'لا يوجد سجل زيارات حتى الآن', icon: Icons.history))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              return _VisitTimelineCard(
                visitWithProc: visits[index],
                profile: profile,
                isLast: index == visits.length - 1,
              ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
            },
          ),
      ],
    );
  }
}

class _VisitTimelineCard extends StatelessWidget {
  final VisitWithProcedures visitWithProc;
  final PatientProfile profile;
  final bool isLast;

  const _VisitTimelineCard(
      {required this.visitWithProc,
      required this.profile,
      required this.isLast});

  @override
  Widget build(BuildContext context) {
    final visit = visitWithProc.visit;
    final relatedInvoices =
        profile.invoices.where((inv) => inv.visitId == visit.id).toList();
    final fmt = NumberFormat('#,##0.0', 'ar');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // خط التايم لاين الجانبي
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 4),
                ),
              ),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2, color: AppColors.primary.withOpacity(0.2))),
            ],
          ),
          const SizedBox(width: 20),
          // بطاقة الزيارة
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header الزيارة
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9).withOpacity(0.5),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                            ClinicDateUtils.formatArabicMonth(
                                visit.visitDate, 'EEEE، d MMMM yyyy'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Text(visit.doctorName ?? 'الطبيب العام',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (visit.diagnosis != null) ...[
                          const Text('التشخيص الطبي',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(visit.diagnosis!,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 20),
                        ],

                        // الإجراءات الطبية بتصميم Bento
                        if (visitWithProc.procedures.isNotEmpty) ...[
                          const Text('الإجراءات والعمليات',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: visitWithProc.procedures
                                .map((p) => Container(
                                      padding: const EdgeInsets.all(12),
                                      width: 200,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(p.procedureName ?? 'إجراء',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                          Text('${fmt.format(p.lineTotal)} \$',
                                              style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                          const Divider(height: 40),
                        ],

                        // القسم المالي (الفواتير)
                        if (relatedInvoices.isNotEmpty) ...[
                          const Text('الحالة المالية لهذه الزيارة',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  fontSize: 12)),
                          const SizedBox(height: 12),
                          ...relatedInvoices
                              .map((inv) => _FinancialSummaryRow(invoice: inv)),
                        ],
                      ],
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
// Helpers & Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FinancialSummaryRow extends StatelessWidget {
  final Invoice invoice;
  const _FinancialSummaryRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final balance = invoice.netAmount - invoice.paidAmount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: balance > 0 ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_outlined,
              color: balance > 0 ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Text('فاتورة #${invoice.id}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          _miniMoney('الإجمالي', '${invoice.netAmount}\$'),
          const SizedBox(width: 20),
          _miniMoney('المدفوع', '${invoice.paidAmount}\$', color: Colors.green),
          const SizedBox(width: 20),
          _miniMoney('المتبقي', '${balance}\$',
              color: balance > 0 ? Colors.red : Colors.green),
        ],
      ),
    );
  }

  Widget _miniMoney(String label, String val, {Color? color}) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(val,
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: color ?? Colors.black87)),
        ],
      );
}

class _AvatarBadge extends StatelessWidget {
  final String name;
  const _AvatarBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Center(
        child: Text(name.isNotEmpty ? name[0] : '?',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _QuickBalanceWidget extends StatelessWidget {
  final double balance;
  const _QuickBalanceWidget({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isNegative = balance > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text('الرصيد القائم',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('${NumberFormat('#,##0').format(balance)} \$',
              style: TextStyle(
                  color: isNegative ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
