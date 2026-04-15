// lib/features/invoices/presentation/screens/invoices_screen.dart
//
// Refined ERP Invoice Management:
//   • Lists all invoices with advanced filtering.
//   • Added "New Manual Invoice" creation without requiring a visit.
//   • Added "Quick Payment" directly from the list.
//   • Fixed character encoding issues and UI freezes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/invoice.dart';

import '../../../../core/utils/date_utils.dart';

// ─── Currency helper — single source of truth ─────────────────────────────────
String _money(NumberFormat fmt, double amount) => '\$${fmt.format(amount)}';

class InvoicesScreen extends ConsumerStatefulWidget {
  final Map<String, String>? queryParams;
  const InvoicesScreen({super.key, this.queryParams});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  bool _queryParamsApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyQueryParamsIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queryParams != oldWidget.queryParams) {
      _queryParamsApplied = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyQueryParamsIfNeeded();
      });
    }
  }

  void _applyQueryParamsIfNeeded() {
    final params = widget.queryParams;
    if (!_queryParamsApplied && params != null && params.isNotEmpty) {
      final queryFilter = _filterFromQueryParams(params);
      ref.read(invoiceFilterProvider.notifier).state = queryFilter;
      _queryParamsApplied = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final fmt = NumberFormat('#,##0.00', 'en');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Toolbar Row
          Row(
            children: [
              Expanded(
                child: _InvoiceFilters(
                  filter: filter,
                  onFilterChanged: (f) =>
                      ref.read(invoiceFilterProvider.notifier).state = f,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PrimaryButton(
                label: 'فاتورة جديدة',
                icon: Icons.add,
                onPressed: () => _showManualInvoiceDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: invoicesAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (invoices) => invoices.isEmpty
                  ? const EmptyState(
                      title: 'لا توجد فواتير',
                      icon: Icons.receipt_long_outlined,
                    )
                  : AppTable(
                      headers: const [
                        '#',
                        'المريض',
                        'التاريخ',
                        'الإجمالي',
                        'المدفوع',
                        'المتبقي',
                        'الحالة',
                        'إجراءات'
                      ],
                      rows: invoices
                          .map((inv) => [
                                Text('#${inv.id}',
                                    style: const TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 12)),
                                Text(inv.patientName ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(inv.invoiceDate,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                Text(_money(fmt, inv.netAmount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(_money(fmt, inv.paidAmount),
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600)),
                                Text(_money(fmt, inv.remainingAmount),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: inv.remainingAmount > 0
                                            ? AppColors.error
                                            : AppColors.textHint)),
                                InvoiceStatusChip(status: inv.status.value),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!inv.isLocked)
                                      IconActionButton(
                                        icon: Icons.edit_outlined,
                                        tooltip: 'تعديل',
                                        onPressed: () => context
                                            .go('/invoices/${inv.id}'),
                                        color: AppColors.primary,
                                        bgColor: AppColors.primarySurface,
                                      ),
                                    const SizedBox(width: 8),
                                    if (inv.status != InvoiceStatus.paid &&
                                        !inv.isLocked)
                                      IconActionButton(
                                        icon: Icons.add_card_outlined,
                                        tooltip: 'دفع سريع',
                                        onPressed: () =>
                                            _showQuickPaymentDialog(
                                                context, ref, inv, fmt),
                                        color: AppColors.success,
                                        bgColor: AppColors.successSurface,
                                      ),
                                    const SizedBox(width: 8),
                                    IconActionButton(
                                      icon: Icons.visibility_outlined,
                                      tooltip: 'عرض',
                                      onPressed: () =>
                                          context.go('/invoices/${inv.id}'),
                                      color: AppColors.primary,
                                      bgColor: AppColors.primarySurface,
                                    ),
                                  ],
                                ),
                              ])
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filters ──────────────────────────────────────────────────────────────────

class _InvoiceFilters extends StatelessWidget {
  final InvoiceFilter filter;
  final void Function(InvoiceFilter) onFilterChanged;

  const _InvoiceFilters({required this.filter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: filter.status,
              decoration: const InputDecoration(
                  labelText: 'الحالة', prefixIcon: Icon(Icons.filter_list)),
              items: const [
                DropdownMenuItem(value: null, child: Text('كل الحالات')),
                DropdownMenuItem(value: 'open', child: Text('معلقة')),
                DropdownMenuItem(value: 'unpaid', child: Text('غير مدفوعة')),
                DropdownMenuItem(value: 'partial', child: Text('جزئية')),
                DropdownMenuItem(value: 'paid', child: Text('مدفوعة')),
              ],
              onChanged: (v) => onFilterChanged(InvoiceFilter(
                  status: v, fromDate: filter.fromDate, toDate: filter.toDate)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _DateFilter(
              label: 'من تاريخ',
              value: filter.fromDate,
              onChanged: (v) => onFilterChanged(InvoiceFilter(
                  fromDate: v, toDate: filter.toDate, status: filter.status)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _DateFilter(
              label: 'إلى تاريخ',
              value: filter.toDate,
              onChanged: (v) => onFilterChanged(InvoiceFilter(
                  fromDate: filter.fromDate, toDate: v, status: filter.status)),
            ),
          ),
        ],
      );
}

InvoiceFilter _filterFromQueryParams(Map<String, String>? params) {
  final patientId = params != null && params['patientId'] != null
      ? int.tryParse(params['patientId']!)
      : null;
  final status = params != null ? params['status'] : null;
  final fromDate = params != null ? params['fromDate'] : null;
  final toDate = params != null ? params['toDate'] : null;
  return InvoiceFilter(
    fromDate: fromDate,
    toDate: toDate,
    status: status,
    patientId: patientId,
  );
}

bool _isSameFilter(InvoiceFilter a, InvoiceFilter b) {
  return a.fromDate == b.fromDate &&
      a.toDate == b.toDate &&
      a.status == b.status &&
      a.patientId == b.patientId;
}

class _DateFilter extends StatelessWidget {
  final String label;
  final String? value;
  final void Function(String?) onChanged;

  const _DateFilter({required this.label, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      readOnly: true,
      hint: 'اختر التاريخ',
      prefix: const Icon(Icons.calendar_today_outlined, size: 18),
      controller: TextEditingController(text: value ?? ''),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value != null
              ? DateTime.tryParse(value!) ?? DateTime.now()
              : DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: const Locale('ar'),
        );
        if (picked != null) {
          onChanged(ClinicDateUtils.toDbDate(picked));
        }
      },
    );
  }
}

// ─── Invoice Detail Screen ────────────────────────────────────────────────────

class InvoiceDetailScreen extends ConsumerWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(invoiceId));
    final itemsAsync = ref.watch(invoiceItemsProvider(invoiceId));
    final paymentsAsync = ref.watch(invoicePaymentsProvider(invoiceId));
    final fmt = NumberFormat('#,##0.00', 'en');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: invoiceAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (invoice) {
          if (invoice == null) {
            return const ErrorView(message: 'الفاتورة غير موجودة');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                IconActionButton(
                    icon: Icons.arrow_back,
                    tooltip: 'رجوع',
                    onPressed: () => context.go('/invoices')),
                const SizedBox(width: AppSpacing.md),
                Text('فاتورة #${invoice.id}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: AppSpacing.md),
                InvoiceStatusChip(status: invoice.status.value),
                if (invoice.isLocked) ...[
                  const SizedBox(width: 8),
                  const StatusChip(label: 'مقفلة', color: AppColors.textHint),
                ] else ...[
                  const SizedBox(width: 8),
                  SecondaryButton(
                    label: 'تعديل',
                    icon: Icons.edit_outlined,
                    compact: true,
                    onPressed: () =>
                        _showEditInvoiceDialog(context, ref, invoice, fmt),
                  ),
                ],
              ]),
              const SizedBox(height: AppSpacing.lg),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Invoice Items
                  Expanded(
                    flex: 3,
                    child: Column(children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'بيانات الفاتورة'),
                            const SizedBox(height: AppSpacing.md),
                            _InfoRow('المريض', invoice.patientName ?? '-'),
                            _InfoRow('التاريخ', invoice.invoiceDate),
                            if (invoice.notes != null)
                              _InfoRow('ملاحظات', invoice.notes!),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'بنود الفاتورة'),
                            const SizedBox(height: AppSpacing.md),
                            itemsAsync.when(
                              loading: () => const LoadingView(),
                              error: (e, _) => ErrorView(message: e.toString()),
                              data: (items) => items.isEmpty
                                  ? const EmptyState(title: 'لا توجد بنود')
                                  : AppTable(
                                      headers: const [
                                        'الوصف',
                                        'الكمية',
                                        'السعر',
                                        'الخصم',
                                        'الإجمالي'
                                      ],
                                      rows: items
                                          .map((item) => [
                                                Text(item.description),
                                                Text('${item.quantity}'),
                                                Text(_money(
                                                    fmt, item.unitPrice)),
                                                Text(
                                                    _money(fmt, item.discount)),
                                                Text(_money(fmt, item.total),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ])
                                          .toList(),
                                    ),
                            ),
                            const Divider(height: AppSpacing.lg),
                            _TotalRow(
                                'الإجمالي', _money(fmt, invoice.totalAmount)),
                            _TotalRow('الخصم', _money(fmt, invoice.discount),
                                color: AppColors.warning),
                            _TotalRow('الصافي', _money(fmt, invoice.netAmount),
                                bold: true),
                            _TotalRow(
                                'المدفوع', _money(fmt, invoice.paidAmount),
                                color: AppColors.success),
                            _TotalRow(
                                'المتبقي', _money(fmt, invoice.remainingAmount),
                                color: invoice.remainingAmount > 0
                                    ? AppColors.error
                                    : AppColors.textHint,
                                bold: true),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Right Side: Payments
                  Expanded(
                    flex: 2,
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'المدفوعات',
                            action: invoice.status != InvoiceStatus.paid &&
                                    !invoice.isLocked
                                ? PrimaryButton(
                                    label: 'إضافة دفعة',
                                    icon: Icons.add,
                                    compact: true,
                                    onPressed: () => _showQuickPaymentDialog(
                                        context, ref, invoice, fmt),
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          paymentsAsync.when(
                            loading: () => const LoadingView(),
                            error: (e, _) => ErrorView(message: e.toString()),
                            data: (payments) => payments.isEmpty
                                ? const EmptyState(
                                    title: 'لا توجد دفعات',
                                    icon: Icons.payments_outlined)
                                : Column(
                                    children: payments
                                        .map((p) => _PaymentTile(
                                              payment: p,
                                              fmt: fmt,
                                              onDelete: invoice.isLocked
                                                  ? null
                                                  : () => _deletePayment(
                                                      context, ref, p.id!),
                                            ))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deletePayment(
      BuildContext context, WidgetRef ref, int paymentId) async {
    final ok = await ConfirmDialog.show(context,
        title: 'حذف دفعة',
        message: 'هل تريد حذف هذه الدفعة؟ سيتم تحديث حالة الفاتورة تلقائياً.',
        isDanger: true);
    if (ok) {
      try {
        final inv =
            await ref.read(invoiceRepositoryProvider).getById(invoiceId);
        await ref.read(invoiceRepositoryProvider).deletePayment(paymentId);
        ref.invalidate(invoiceByIdProvider(invoiceId));
        ref.invalidate(invoicePaymentsProvider(invoiceId));
        ref.invalidate(invoicesProvider);
        ref.invalidate(dailyReportProvider(ClinicDateUtils.todayString()));
        ref.invalidate(cashBoxTodayProvider);
        if (inv?.patientId != null) {
          ref.invalidate(patientProfileProvider(inv!.patientId));
          ref.invalidate(pendingBalancesProvider);
        }
        if (context.mounted) showSnack(context, 'تم حذف الدفعة');
      } catch (e) {
        if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
      }
    }
  }

  Future<void> _showEditInvoiceDialog(BuildContext context, WidgetRef ref,
      Invoice invoice, NumberFormat fmt) async {
    double additionalDiscount = 0.0;
    final discountCtrl = TextEditingController(text: '0.00');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تعديل الفاتورة'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الإجمالي الحالي: ${_money(fmt, invoice.totalAmount)}'),
                Text('الخصم الحالي: ${_money(fmt, invoice.discount)}'),
                Text('الصافي الحالي: ${_money(fmt, invoice.netAmount)}'),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'خصم إضافي (\$)',
                  controller: discountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) =>
                      additionalDiscount = double.tryParse(v) ?? 0.0,
                ),
                const SizedBox(height: 8),
                Text(
                  'الصافي الجديد: ${_money(fmt, (invoice.netAmount - additionalDiscount).clamp(0.0, double.infinity))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            PrimaryButton(
              label: 'تطبيق',
              onPressed: () async {
                if (additionalDiscount < 0) {
                  showSnack(ctx, 'الخصم لا يمكن أن يكون سالباً', error: true);
                  return;
                }
                final newDiscount = invoice.discount + additionalDiscount;
                if (newDiscount > invoice.totalAmount) {
                  showSnack(ctx, 'الخصم الإجمالي لا يمكن أن يتجاوز الإجمالي',
                      error: true);
                  return;
                }
                final newNet = invoice.totalAmount - newDiscount;
                if (newNet < invoice.paidAmount - 0.001) {
                  showSnack(ctx, 'الخصم يجعل الصافي أقل من المدفوع',
                      error: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(invoiceRepositoryProvider).updateFinancials(
                        invoiceId: invoice.id!,
                        discount: newDiscount,
                        netAmount: newNet,
                      );
                  ref.invalidate(invoiceByIdProvider(invoiceId));
                  ref.invalidate(invoicesProvider);
                  if (invoice.patientId != null) {
                    ref.invalidate(patientProfileProvider(invoice.patientId));
                    ref.invalidate(pendingBalancesProvider);
                  }
                  if (context.mounted) showSnack(context, 'تم تطبيق الخصم');
                } catch (e) {
                  if (context.mounted)
                    showSnack(context, 'خطأ: $e', error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────

Future<void> _showManualInvoiceDialog(
    BuildContext context, WidgetRef ref) async {
  int? selectedPatientId;
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final patientsAsync = ref.read(patientNotifierProvider);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('فاتورة يدوية جديدة'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                patientsAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (patients) => AppDropdown<int>(
                    label: 'المريض',
                    required: true,
                    value: selectedPatientId,
                    items: patients
                        .map((p) =>
                            DropdownMenuItem(value: p.id!, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) => setSt(() => selectedPatientId = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'الوصف / الخدمة',
                  required: true,
                  controller: descCtrl,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'المبلغ (\$)',
                  required: true,
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'ملاحظات',
                  controller: notesCtrl,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          PrimaryButton(
            label: 'إصدار الفاتورة',
            onPressed: () async {
              if (selectedPatientId == null || descCtrl.text.isEmpty) return;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (price <= 0) return;

              Navigator.pop(ctx);
              try {
                final now = DateTime.now();
                final invoiceId =
                    await ref.read(invoiceRepositoryProvider).create(Invoice(
                          patientId: selectedPatientId!,
                          invoiceDate: ClinicDateUtils.todayString(),
                          totalAmount: price,
                          netAmount: price,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          createdAt: now,
                          updatedAt: now,
                        ));

                await ref.read(invoiceRepositoryProvider).addItem(InvoiceItem(
                      invoiceId: invoiceId,
                      description: descCtrl.text,
                      unitPrice: price,
                      total: price,
                      createdAt: now,
                    ));

                ref.invalidate(invoicesProvider);
                ref.invalidate(
                    dailyReportProvider(ClinicDateUtils.todayString()));
                ref.invalidate(patientProfileProvider(selectedPatientId!));
                ref.invalidate(pendingBalancesProvider);

                if (context.mounted) {
                  showSnack(context, 'تم إصدار الفاتورة بنجاح');
                  context.go('/invoices/$invoiceId');
                }
              } catch (e) {
                if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
              }
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _showQuickPaymentDialog(
    BuildContext context, WidgetRef ref, Invoice inv, NumberFormat fmt) async {
  final amtCtrl =
      TextEditingController(text: inv.remainingAmount.toStringAsFixed(2));
  String method = 'cash';

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text('دفع سريع للفاتورة #${inv.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المبلغ المتبقي: \$${fmt.format(inv.remainingAmount)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'مبلغ الدفع (\$)',
              required: true,
              controller: amtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'طريقة الدفع',
              value: method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
              ],
              onChanged: (v) => setSt(() => method = v ?? 'cash'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          PrimaryButton(
            label: 'تأكيد الدفع',
            onPressed: () async {
              final amount = double.tryParse(amtCtrl.text);
              if (amount == null || amount <= 0) return;

              Navigator.pop(ctx);
              try {
                final now = DateTime.now();
                await ref.read(invoiceRepositoryProvider).addPayment(Payment(
                      invoiceId: inv.id!,
                      amount: amount,
                      paymentDate: ClinicDateUtils.todayString(),
                      method: PaymentMethodX.fromString(method),
                      createdAt: now,
                    ));

                ref.invalidate(invoicesProvider);
                ref.invalidate(invoiceByIdProvider(inv.id!));
                ref.invalidate(
                    dailyReportProvider(ClinicDateUtils.todayString()));
                ref.invalidate(cashBoxTodayProvider);
                ref.invalidate(patientProfileProvider(inv.patientId));
                ref.invalidate(pendingBalancesProvider);

                if (context.mounted)
                  showSnack(context, 'تم تسجيل الدفعة بنجاح');
              } catch (e) {
                if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
              }
            },
          ),
        ],
      ),
    ),
  );
}

// ─── Helper Row Widgets ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _TotalRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ]),
      );
}

class _PaymentTile extends StatelessWidget {
  final Payment payment;
  final NumberFormat fmt;
  final VoidCallback? onDelete;
  const _PaymentTile({required this.payment, required this.fmt, this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.successSurface,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.payments_outlined,
                color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_money(fmt, payment.amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.success)),
              Text('${payment.paymentDate} · ${payment.method.label}',
                  style:
                      const TextStyle(color: AppColors.textHint, fontSize: 12)),
            ],
          )),
          if (onDelete != null)
            IconActionButton(
                icon: Icons.delete_outline,
                tooltip: 'حذف',
                onPressed: onDelete,
                color: AppColors.error,
                bgColor: AppColors.errorSurface),
        ]),
      );
}
