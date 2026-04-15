// lib/features/patients/presentation/screens/patient_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: AppColors.surface,
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.refresh(patientProfileProvider(widget.patientId))),
        data: (profile) {
          if (profile == null)
            return const Center(child: Text('المريض غير موجود'));

          return Column(
            children: [
              // ── Patient Dossier Header ──────────────────────────────────
              _ProfileHeader(profile: profile),

              // ── Unified Dossier Timeline ────────────────────────────────
              Expanded(
                child: _DossierTimeline(profile: profile),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Profile Header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final PatientProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primarySurface,
            child: Text(
              profile.patient.name.characters.first,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(profile.patient.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (!profile.patient.isActive)
                      const StatusChip(
                          label: 'غير نشط', color: AppColors.error),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(profile.patient.phone ?? 'لا يوجد هاتف',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 24),
                    Icon(Icons.calendar_today,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                        'مسجل منذ: ${ClinicDateUtils.formatArabicMonth(profile.patient.createdAt, 'd MMMM yyyy')}',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),

          // Quick Balance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: profile.outstandingBalance > 0
                  ? AppColors.errorSurface
                  : AppColors.successSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('الرصيد المتبقي',
                    style: TextStyle(
                        color: profile.outstandingBalance > 0
                            ? AppColors.error
                            : AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Text('${fmt.format(profile.outstandingBalance)} \$',
                    style: TextStyle(
                        color: profile.outstandingBalance > 0
                            ? AppColors.error
                            : AppColors.success,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.lg),
          PrimaryButton(
            label: 'زيارة جديدة',
            icon: Icons.add,
            onPressed: () =>
                context.push('/visits/new?patientId=${profile.patient.id}'),
          ),
        ],
      ),
    );
  }
}

// ─── Tabs ────────────────────────────────────────────────────────────────────

// ─── Timeline Entry Helper ───────────────────────────────────────────────────

enum DossierEntryType { visit, invoice, payment }

class DossierEntry {
  final DateTime date;
  final DossierEntryType type;
  final dynamic data;

  DossierEntry({required this.date, required this.type, required this.data});
}

class _DossierTimeline extends StatelessWidget {
  final PatientProfile profile;
  const _DossierTimeline({required this.profile});

  @override
  Widget build(BuildContext context) {
    // 1. Collect visits and sort by date descending
    final visits = profile.visits
      ..sort((a, b) => b.visit.visitDate.compareTo(a.visit.visitDate));

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      children: [
        // ── Summary Sheet (Basic Info) ───────────────────────────
        _DossierSummarySheet(profile: profile),
        const SizedBox(height: AppSpacing.xxl),

        // ── Timeline Header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Text('سجل المريض - الزيارات والفواتير',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${visits.length} زيارة',
                  style:
                      const TextStyle(color: AppColors.textHint, fontSize: 13)),
            ],
          ),
        ),

        // ── Nested Timeline List ────────────────────────────────────────
        ...visits.map((visitWithProc) =>
            _NestedVisitItem(visitWithProc: visitWithProc, profile: profile)),

        const SizedBox(height: 100),
      ],
    );
  }
}

// ─── Dossier Summary Sheet ──────────────────────────────────────────────────

class _DossierSummarySheet extends StatelessWidget {
  final PatientProfile profile;
  const _DossierSummarySheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'بيانات الملف الشخصي'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 40,
                  runSpacing: 20,
                  children: [
                    _DocInfoRow(
                        label: 'الاسم الكامل',
                        value: profile.patient.name,
                        icon: Icons.person),
                    _DocInfoRow(
                        label: 'رقم الهاتف',
                        value: profile.patient.phone ?? '-',
                        icon: Icons.phone),
                    _DocInfoRow(
                        label: 'تاريخ الميلاد',
                        value: profile.patient.birthDate ?? '-',
                        icon: Icons.event),
                    _DocInfoRow(
                        label: 'الجنس',
                        value:
                            profile.patient.gender == 'male' ? 'ذكر' : 'أنثى',
                        icon: Icons.wc),
                    _DocInfoRow(
                        label: 'العنوان',
                        value: profile.patient.address ?? '-',
                        icon: Icons.location_on),
                  ],
                ),
              ),
              Container(
                width: 250,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    _MiniStat(
                        label: 'إجمالي الزيارات',
                        value: '${profile.visits.length}',
                        color: AppColors.primary),
                    const Divider(height: 24),
                    _MiniStat(
                        label: 'الرصيد المفتوح',
                        value:
                            '${NumberFormat('#,##0').format(profile.outstandingBalance)} \$',
                        color: AppColors.error),
                  ],
                ),
              ),
            ],
          ),
          if (profile.patient.notes != null &&
              profile.patient.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const Text('ملاحظات دائمة للملف:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Text(profile.patient.notes!,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DocInfoRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ],
      );
}

// ─── Timeline Items ──────────────────────────────────────────────────────────

// ─── Nested Visit Item ───────────────────────────────────────────────────────

class _NestedVisitItem extends StatelessWidget {
  final VisitWithProcedures visitWithProc;
  final PatientProfile profile;
  const _NestedVisitItem({required this.visitWithProc, required this.profile});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    final visit = visitWithProc.visit;

    // Find related invoices and payments
    final relatedInvoices =
        profile.invoices.where((inv) => inv.visitId == visit.id).toList();
    final relatedPayments = profile.payments
        .where((p) => relatedInvoices.any((inv) => inv.id == p.invoiceId))
        .toList();

    return IntrinsicHeight(
      child: Row(
        children: [
          // ── Dot & Line ──────────────────────────────────────────
          SizedBox(
            width: 80,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
              ],
            ),
          ),
          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visit Header
                    Row(
                      children: [
                        Text(
                            ClinicDateUtils.formatArabicMonth(
                                visit.visitDate, 'd MMMM yyyy'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textHint)),
                        const Spacer(),
                        const _TypeChip(type: DossierEntryType.visit),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('زيارة طبية - ${visit.doctorName ?? 'الطبيب العام'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    if (visit.diagnosis != null) ...[
                      const SizedBox(height: 8),
                      Text('التشخيص: ${visit.diagnosis}',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ],
                    if (visit.notes != null) ...[
                      const SizedBox(height: 8),
                      Text('ملاحظات: ${visit.notes}',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: AppSpacing.md),

                    // Procedures Section
                    if (visitWithProc.procedures.isNotEmpty) ...[
                      const Text('الإجراءات الطبية',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...visitWithProc.procedures.map((proc) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        '${proc.procedureName ?? 'إجراء'} × ${proc.quantity}')),
                                Text('\$${fmt.format(proc.lineTotal)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                      const Divider(height: 16),
                    ],

                    // Invoices Section
                    if (relatedInvoices.isNotEmpty) ...[
                      const Text('الفواتير الصادرة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...relatedInvoices.map((inv) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text('فاتورة #${inv.id}')),
                                Text('\$${fmt.format(inv.netAmount)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Text('مدفوع: \$${fmt.format(inv.paidAmount)}',
                                    style: const TextStyle(
                                        color: AppColors.success)),
                                const SizedBox(width: 8),
                                Text(
                                    'متبقي: \$${fmt.format(inv.netAmount - inv.paidAmount)}',
                                    style: TextStyle(
                                        color:
                                            inv.netAmount - inv.paidAmount > 0
                                                ? AppColors.error
                                                : AppColors.success)),
                              ],
                            ),
                          )),
                      const Divider(height: 16),
                    ],

                    // Payments Section
                    if (relatedPayments.isNotEmpty) ...[
                      const Text('الدفعات المستلمة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...relatedPayments.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        '${p.method} - ${ClinicDateUtils.formatArabicMonth(DateTime.parse(p.paymentDate), 'd/M/yyyy')}')),
                                Text('\$${fmt.format(p.amount)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final DossierEntry entry;
  const _TimelineItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // ── Dot & Line ──────────────────────────────────────────
          SizedBox(
            width: 80,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: _getColor().withValues(alpha: 0.3),
                          blurRadius: 6),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: AppColors.border),
                ),
              ],
            ),
          ),
          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                            ClinicDateUtils.formatArabicMonth(
                                entry.date, 'd MMMM yyyy'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textHint)),
                        const Spacer(),
                        _TypeChip(type: entry.type),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildEntryContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (entry.type) {
      case DossierEntryType.visit:
        return AppColors.primary;
      case DossierEntryType.invoice:
        return Colors.blue;
      case DossierEntryType.payment:
        return AppColors.success;
    }
  }

  Widget _buildEntryContent() {
    final fmt = NumberFormat('#,##0.00', 'ar');
    if (entry.type == DossierEntryType.visit) {
      final VisitWithProcedures item = entry.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('زيارة طبية - ${item.visit.doctorName ?? 'الطبيب العام'}',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (item.visit.diagnosis != null) ...[
            const SizedBox(height: 8),
            Text('التشخيص: ${item.visit.diagnosis}',
                style: const TextStyle(fontSize: 14)),
          ],
          if (item.procedures.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.procedures
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(p.procedureName ?? 'إجراء',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
          ],
        ],
      );
    } else if (entry.type == DossierEntryType.invoice) {
      final Invoice inv = entry.data;
      return Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فاتورة رقم #${inv.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('بمبلغ إجمالي ${fmt.format(inv.netAmount)} \$',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          InvoiceStatusChip(status: inv.status.name),
        ],
      );
    } else {
      final Payment p = entry.data;
      return Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('دفعة نقدية - ${p.method.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.success)),
                Text('تم دفع مبلغ ${fmt.format(p.amount)} \$',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (p.notes != null)
            Text(p.notes!,
                style:
                    const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      );
    }
  }
}

class _TypeChip extends StatelessWidget {
  final DossierEntryType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;
    switch (type) {
      case DossierEntryType.visit:
        label = 'زيارة';
        icon = Icons.medical_services;
        color = AppColors.primary;
        break;
      case DossierEntryType.invoice:
        label = 'فاتورة';
        icon = Icons.receipt_long;
        color = Colors.blue;
        break;
      case DossierEntryType.payment:
        label = 'دفعة';
        icon = Icons.payment;
        color = AppColors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
