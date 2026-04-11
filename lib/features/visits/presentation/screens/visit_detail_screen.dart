// lib/features/visits/presentation/screens/visit_detail_screen.dart
//
// ROOT-CAUSE FIX: replaces the old router mapping of /visits/:id →
// VisitFormScreen (which had no procedure UI, caused RenderFlex overflow,
// and never pre-populated fields).
//
// This screen is the single source of truth for an existing visit:
//   • Displays visit metadata (patient, doctor, date, diagnosis)
//   • Lists visit procedures with add / remove
//   • Shows linked invoice summary (auto-synced via InvoiceService)
//   • Invalidates dailyReportProvider after every mutation so the
//     dashboard "Today Visits" counter is always accurate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/visit.dart';
import '../../../invoices/domain/entities/invoice.dart';

// ─── Provider for a single visit ─────────────────────────────────────────────
final visitByIdProvider = FutureProvider.family<Visit?, int>(
  (ref, id) => ref.watch(visitRepositoryProvider).getById(id),
);

// ─── Provider for visit's linked invoice ─────────────────────────────────────
final visitInvoiceProvider = FutureProvider.family<Invoice?, int>(
  (ref, visitId) => ref.watch(invoiceRepositoryProvider).getByVisitId(visitId),
);

// ─────────────────────────────────────────────────────────────────────────────

class VisitDetailScreen extends ConsumerWidget {
  final int visitId;
  const VisitDetailScreen({super.key, required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(visitByIdProvider(visitId));

    return visitAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: ErrorView(message: e.toString())),
      data: (visit) {
        if (visit == null) {
          return const Center(child: ErrorView(message: 'الزيارة غير موجودة'));
        }
        return _VisitDetailBody(visit: visit);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VisitDetailBody extends ConsumerWidget {
  final Visit visit;
  const _VisitDetailBody({required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proceduresAsync = ref.watch(visitProceduresProvider(visit.id!));
    final invoiceAsync = ref.watch(visitInvoiceProvider(visit.id!));
    final fmt = NumberFormat('#,##0.00', 'en');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(children: [
            IconActionButton(
              icon: Icons.arrow_back,
              tooltip: 'رجوع',
              onPressed: () => context.go('/visits'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'زيارة #${visit.id}  —  ${visit.patientName ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!visit.isLocked)
              SecondaryButton(
                label: 'تعديل بيانات الزيارة',
                icon: Icons.edit_outlined,
                compact: true,
                onPressed: () => context.go('/visits/${visit.id}/edit'),
              ),
          ]),
          const SizedBox(height: AppSpacing.lg),

          // ── Two-column layout ────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return Column(
                children: [
                  _VisitInfoCard(visit: visit),
                  const SizedBox(height: AppSpacing.md),
                  _ProceduresCard(
                      visit: visit, proceduresAsync: proceduresAsync, fmt: fmt),
                  const SizedBox(height: AppSpacing.md),
                  _InvoiceSummaryCard(invoiceAsync: invoiceAsync, fmt: fmt),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    _VisitInfoCard(visit: visit),
                    const SizedBox(height: AppSpacing.md),
                    _ProceduresCard(
                        visit: visit,
                        proceduresAsync: proceduresAsync,
                        fmt: fmt),
                  ]),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child:
                      _InvoiceSummaryCard(invoiceAsync: invoiceAsync, fmt: fmt),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Visit Info Card ──────────────────────────────────────────────────────────

class _VisitInfoCard extends StatelessWidget {
  final Visit visit;
  const _VisitInfoCard({required this.visit});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'بيانات الزيارة'),
            const SizedBox(height: AppSpacing.md),
            _InfoRow('المريض', visit.patientName ?? '-'),
            _InfoRow('الطبيب', visit.doctorName ?? '-'),
            _InfoRow('التاريخ', visit.visitDate),
            if (visit.diagnosis != null) _InfoRow('التشخيص', visit.diagnosis!),
            if (visit.notes != null) _InfoRow('ملاحظات', visit.notes!),
            _InfoRow(
              'الحالة',
              visit.isLocked ? 'مقفلة' : 'مفتوحة',
              valueColor:
                  visit.isLocked ? AppColors.textHint : AppColors.success,
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textHint, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary)),
          ),
        ]),
      );
}

// ─── Procedures Card ──────────────────────────────────────────────────────────

class _ProceduresCard extends ConsumerWidget {
  final Visit visit;
  final AsyncValue<List<VisitProcedureItem>> proceduresAsync;
  final NumberFormat fmt;
  const _ProceduresCard(
      {required this.visit, required this.proceduresAsync, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'الإجراءات الطبية',
              action: visit.isLocked
                  ? null
                  : PrimaryButton(
                      label: 'إضافة إجراء',
                      icon: Icons.add,
                      compact: true,
                      onPressed: () => _showAddProcedureDialog(context, ref),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            proceduresAsync.when(
              // FIX: Use SizedBox-constrained loading — not raw LoadingView()
              // inside Expanded, which caused the RenderFlex overflow (black
              // screen). Give the loading indicator a fixed height.
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (procedures) => procedures.isEmpty
                  ? const EmptyState(
                      title: 'لا توجد إجراءات',
                      icon: Icons.medical_services_outlined,
                    )
                  : Column(
                      children: [
                        AppTable(
                          headers: const [
                            'الإجراء',
                            'الكمية',
                            'السعر',
                            'الخصم %',
                            'الإجمالي',
                            ''
                          ],
                          rows: procedures
                              .map((p) => [
                                    Text(p.procedureName ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text('${p.quantity}'),
                                    Text('\$${fmt.format(p.unitPrice)}'),
                                    Text('${p.discount.toStringAsFixed(0)}%'),
                                    Text('\$${fmt.format(p.lineTotal)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary)),
                                    visit.isLocked
                                        ? const SizedBox.shrink()
                                        : IconActionButton(
                                            icon: Icons.delete_outline,
                                            tooltip: 'حذف',
                                            color: AppColors.error,
                                            bgColor: AppColors.errorSurface,
                                            onPressed: () => _deleteProcedure(
                                                context, ref, p),
                                          ),
                                  ])
                              .toList(),
                        ),
                        const Divider(height: 24),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            'الإجمالي: \$${fmt.format(procedures.fold(0.0, (s, p) => s + p.lineTotal))}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );

  Future<void> _showAddProcedureDialog(
      BuildContext context, WidgetRef ref) async {
    final proceduresAsync = ref.read(procedureNotifierProvider);
    final allProcedures = proceduresAsync.maybeWhen(
      data: (procedures) => procedures,
      orElse: () => [],
    );
    final activeProcedures = allProcedures.where((p) => p.isActive).toList();

    if (activeProcedures.isEmpty) {
      showSnack(context, 'لا توجد إجراءات متاحة. أضف إجراءات أولاً.',
          error: true);
      return;
    }

    int? selectedProcedureId;
    double price = 0;
    int quantity = 1;
    double discount = 0;
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final discCtrl = TextEditingController(text: '0');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة إجراء طبي'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdown<int>(
                  label: 'الإجراء',
                  required: true,
                  value: selectedProcedureId,
                  items: activeProcedures
                      .map((p) => DropdownMenuItem<int>(
                            value: p.id!,
                            child: Text(
                                '${p.name}  —  \$${p.defaultPrice.toStringAsFixed(2)}'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setSt(() {
                      selectedProcedureId = v;
                      if (v != null) {
                        final proc =
                            activeProcedures.firstWhere((p) => p.id == v);
                        price = proc.defaultPrice;
                        priceCtrl.text = price.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label: 'الكمية',
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => quantity = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'السعر (\$)',
                      controller: priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => price = double.tryParse(v) ?? 0,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'خصم (%)',
                  controller: discCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => discount = double.tryParse(v) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            PrimaryButton(
              label: 'إضافة',
              onPressed: () async {
                if (selectedProcedureId == null) return;
                Navigator.pop(ctx);
                await _doAddProcedure(
                  context: context,
                  ref: ref,
                  procedureId: selectedProcedureId!,
                  quantity: quantity,
                  unitPrice: price,
                  discount: discount.clamp(0, 100),
                );
              },
            ),
          ],
        ),
      ),
    );

    priceCtrl.dispose();
    qtyCtrl.dispose();
    discCtrl.dispose();
  }

  Future<void> _doAddProcedure({
    required BuildContext context,
    required WidgetRef ref,
    required int procedureId,
    required int quantity,
    required double unitPrice,
    required double discount,
  }) async {
    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final invoiceService = ref.read(invoiceServiceProvider);
      final today = ClinicDateUtils.todayString();

      // 1. Insert the procedure row
      await visitRepo.addProcedure(VisitProcedureItem(
        visitId: visit.id!,
        procedureId: procedureId,
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
        createdAt: DateTime.now(),
      ));

      // 2. Sync / create the invoice atomically
      await invoiceService.syncInvoiceForVisit(visit.id!, visit.patientId);

      // 3. Invalidate dependent providers
      ref.invalidate(visitProceduresProvider(visit.id!));
      ref.invalidate(visitInvoiceProvider(visit.id!));
      ref.invalidate(invoicesProvider);
      ref.invalidate(dailyReportProvider(today));

      if (context.mounted)
        showSnack(context, 'تمت إضافة الإجراء وتحديث الفاتورة');
    } catch (e) {
      if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
    }
  }

  Future<void> _deleteProcedure(
      BuildContext context, WidgetRef ref, VisitProcedureItem proc) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'حذف إجراء',
      message: 'هل تريد حذف "${proc.procedureName}"؟',
      isDanger: true,
    );
    if (!ok) return;

    try {
      final visitRepo = ref.read(visitRepositoryProvider);
      final invoiceService = ref.read(invoiceServiceProvider);
      final today = ClinicDateUtils.todayString();

      await visitRepo.removeProcedure(proc.id!);
      await invoiceService.syncInvoiceForVisit(visit.id!, visit.patientId);

      ref.invalidate(visitProceduresProvider(visit.id!));
      ref.invalidate(visitInvoiceProvider(visit.id!));
      ref.invalidate(invoicesProvider);
      ref.invalidate(dailyReportProvider(today));

      if (context.mounted) showSnack(context, 'تم حذف الإجراء');
    } catch (e) {
      if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
    }
  }
}

// ─── Invoice Summary Card ─────────────────────────────────────────────────────

class _InvoiceSummaryCard extends ConsumerWidget {
  final AsyncValue<Invoice?> invoiceAsync;
  final NumberFormat fmt;
  const _InvoiceSummaryCard({required this.invoiceAsync, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'ملخص الفاتورة'),
            const SizedBox(height: AppSpacing.md),
            invoiceAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (invoice) => invoice == null
                  ? const EmptyState(
                      title: 'لا توجد فاتورة بعد',
                      icon: Icons.receipt_long_outlined,
                    )
                  : Column(
                      children: [
                        _SummaryRow('إجمالي الفاتورة',
                            '\$${fmt.format(invoice.netAmount)}'),
                        _SummaryRow(
                            'المدفوع', '\$${fmt.format(invoice.paidAmount)}',
                            color: AppColors.success),
                        _SummaryRow('المتبقي',
                            '\$${fmt.format(invoice.remainingAmount)}',
                            color: invoice.remainingAmount > 0
                                ? AppColors.error
                                : AppColors.textHint,
                            bold: true),
                        const Divider(height: 20),
                        InvoiceStatusChip(status: invoice.status.value),
                        const SizedBox(height: 12),
                        if (invoice.id != null)
                          SecondaryButton(
                            label: 'فتح الفاتورة الكاملة',
                            icon: Icons.open_in_new,
                            compact: true,
                            onPressed: () =>
                                context.go('/invoices/${invoice.id}'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color:
                        bold ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            Text(value,
                style: TextStyle(
                    color: color ?? AppColors.textPrimary,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );
}
