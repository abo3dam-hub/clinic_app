// lib/features/patients/presentation/screens/patient_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:clinic_app/core/providers/service_providers.dart';
import 'package:clinic_app/core/theme/app_theme.dart';
import 'package:clinic_app/shared/widgets/app_widgets.dart';
import 'package:clinic_app/features/patients/domain/entities/patient.dart';
import 'package:clinic_app/features/invoices/domain/entities/invoice.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final int patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider(widget.patientId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.refresh(patientProfileProvider(widget.patientId))),
        data: (profile) {
          if (profile == null) return const Center(child: Text('المريض غير موجود'));
          
          return Column(
            children: [
              // ── Patient Header ──────────────────────────────────────────
              _ProfileHeader(profile: profile),
              
              // ── Tab Bar ─────────────────────────────────────────────────
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'نظرة عامة', icon: Icon(Icons.info_outline, size: 20)),
                    Tab(text: 'السجل الطبي والزيارات', icon: Icon(Icons.history, size: 20)),
                    Tab(text: 'السجل المالي', icon: Icon(Icons.account_balance_wallet_outlined, size: 20)),
                  ],
                ),
              ),
              
              // ── Tab Views ───────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(profile: profile),
                    _VisitsTab(profile: profile),
                    _FinancialsTab(profile: profile),
                  ],
                ),
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
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (!profile.patient.isActive)
                      const StatusChip(label: 'غير نشط', color: AppColors.error),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(profile.patient.phone ?? 'لا يوجد هاتف', 
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 24),
                    Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('مسجل منذ: ${DateFormat('yyyy-MM-dd').format(profile.patient.createdAt)}', 
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          
          // Quick Balance Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: profile.outstandingBalance > 0 ? AppColors.errorSurface : AppColors.successSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('الرصيد المتبقي', 
                  style: TextStyle(color: profile.outstandingBalance > 0 ? AppColors.error : AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${fmt.format(profile.outstandingBalance)} \$', 
                  style: TextStyle(
                    color: profile.outstandingBalance > 0 ? AppColors.error : AppColors.success, 
                    fontSize: 20, 
                    fontWeight: FontWeight.w900
                  )),
              ],
            ),
          ),
          
          const SizedBox(width: AppSpacing.lg),
          PrimaryButton(
            label: 'زيارة جديدة',
            icon: Icons.add,
            onPressed: () => context.push('/visits/new?patientId=${profile.patient.id}'),
          ),
        ],
      ),
    );
  }
}

// ─── Tabs ────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final PatientProfile profile;
  const _OverviewTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'المعلومات الأساسية'),
                          const SizedBox(height: AppSpacing.lg),
                          _InfoRow(label: 'الاسم الكامل', value: profile.patient.name),
                          _InfoRow(label: 'رقم الهاتف', value: profile.patient.phone ?? '-'),
                          _InfoRow(label: 'البريد الإلكتروني', value: profile.patient.email ?? '-'),
                          _InfoRow(label: 'تاريخ الميلاد', value: profile.patient.birthDate ?? '-'),
                          _InfoRow(label: 'الجنس', value: profile.patient.gender == 'male' ? 'ذكر' : 'أنثى'),
                          _InfoRow(label: 'العنوان', value: profile.patient.address ?? '-'),
                          const Divider(height: 32),
                          const SectionHeader(title: 'ملاحظات طبية'),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withOpacity(0.2)),
                            ),
                            child: Text(profile.patient.notes ?? 'لا توجد ملاحظات', 
                              style: const TextStyle(fontSize: 14, height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _SummaryStat(
                            title: 'إجمالي الزيارات',
                            value: '${profile.visits.length}',
                            icon: Icons.personal_injury,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _SummaryStat(
                            title: 'آخر زيارة',
                            value: profile.visits.isNotEmpty 
                                ? DateFormat('yyyy-MM-dd').format(profile.visits.first.visit.visitDate) 
                                : 'لا يوجد',
                            icon: Icons.event,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VisitsTab extends StatelessWidget {
  final PatientProfile profile;
  const _VisitsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.visits.isEmpty) {
      return const EmptyState(title: 'لا يوجد سجل زيارات', icon: Icons.history);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: profile.visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final item = profile.visits[index];
        return _VisitExpandableCard(item: item);
      },
    );
  }
}

class _FinancialsTab extends StatelessWidget {
  final PatientProfile profile;
  const _FinancialsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _FinancialCard(title: 'إجمالي الفواتير', value: profile.totalInvoiced, color: AppColors.primary)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _FinancialCard(title: 'إجمالي المتدفعات', value: profile.totalPaid, color: AppColors.success)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _FinancialCard(title: 'المبلغ المتبقي', value: profile.outstandingBalance, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'سجل الفواتير'),
          const SizedBox(height: AppSpacing.md),
          AppTable(
            headers: const ['التاريخ', 'رقم الفاتورة', 'المبلغ الإجمالي', 'المدفوع', 'المتبقي', 'الحالة'],
            rows: profile.invoices.map<List<Widget>>((inv) => [
              Text(inv.invoiceDate),
              Text('#${inv.id}'),
              Text('${fmt.format(inv.netAmount)} \$'),
              Text('${fmt.format(inv.paidAmount)} \$'),
              Text('${fmt.format(inv.netAmount - inv.paidAmount)} \$', style: const TextStyle(fontWeight: FontWeight.bold)),
              InvoiceStatusChip(status: inv.status.name),
            ]).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'سجل المدفوعات'),
          const SizedBox(height: AppSpacing.md),
          AppTable(
            headers: const ['التاريخ', 'رقم الفاتورة', 'المبلغ', 'طريقة الدفع', 'ملاحظات'],
            rows: profile.payments.map<List<Widget>>((p) => [
              Text(p.paymentDate),
              Text('#${p.invoiceId}'),
              Text('${fmt.format(p.amount)} \$', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
               Text(p.method.name == 'cash' ? 'نقدي' : p.method.name == 'card' ? 'بطاقة' : 'تحويل'),
              Text(p.notes ?? '-'),
            ]).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _VisitExpandableCard extends StatefulWidget {
  final VisitWithProcedures item;
  const _VisitExpandableCard({required this.item});

  @override
  State<_VisitExpandableCard> createState() => _VisitExpandableCardState();
}

class _VisitExpandableCardState extends State<_VisitExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppRadius.card,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medical_services, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('EEEE، d MMMM yyyy', 'ar').format(widget.item.visit.visitDate), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('الطبيب: ${widget.item.visit.doctorName ?? 'غير محدد'}', 
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (widget.item.visit.isLocked)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.lock_outline, size: 18, color: AppColors.textHint),
                    ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textHint),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.item.visit.diagnosis != null && widget.item.visit.diagnosis!.isNotEmpty) ...[
                    const Text('التشخيص:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(widget.item.visit.diagnosis!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (widget.item.procedures.isEmpty)
                    const Text('لا توجد إجراءات مسجلة لهذه الزيارة', style: TextStyle(color: AppColors.textHint, fontSize: 13, fontStyle: FontStyle.italic))
                  else ...[
                    const Text('الإجراءات والعمليات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.item.procedures.length,
                      itemBuilder: (context, pIdx) {
                        final p = widget.item.procedures[pIdx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(child: Text(p.procedureName ?? 'إجراء غير معروف', style: const TextStyle(fontSize: 14))),
                              Text('${p.unitPrice} \$', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  if (widget.item.visit.notes != null && widget.item.visit.notes!.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('ملاحظات الزيارة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(widget.item.visit.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SecondaryButton(
                      label: 'تفاصيل الزيارة الكاملة',
                      compact: true,
                      onPressed: () => context.push('/visits/${widget.item.visit.id}'),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w600))),
            Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
          ],
        ),
      );
}

class _SummaryStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryStat({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  const _FinancialCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${fmt.format(value)} \$', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
