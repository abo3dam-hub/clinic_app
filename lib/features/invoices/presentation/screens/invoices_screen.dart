// lib/features/invoices/presentation/screens/invoices_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/invoice.dart';
import '../../../../core/providers/repository_providers.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final fmt = NumberFormat('#,##0.00', 'ar');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // ── Filters ──────────────────────────────────────────
          _InvoiceFilters(
            filter: filter,
            onFilterChanged: (f) =>
                ref.read(invoiceFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Table ────────────────────────────────────────────
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
                                Text('${fmt.format(inv.netAmount)} USD',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text('${fmt.format(inv.paidAmount)} USD',
                                    style: const TextStyle(
                                        color: AppColors.success)),
                                Text('${fmt.format(inv.remainingAmount)} USD',
                                    style: TextStyle(
                                        color: inv.remainingAmount > 0
                                            ? AppColors.error
                                            : AppColors.textHint)),
                                InvoiceStatusChip(status: inv.status.value),
                                IconActionButton(
                                  icon: Icons.visibility_outlined,
                                  tooltip: 'عرض',
                                  onPressed: () =>
                                      context.go('/invoices/${inv.id}'),
                                  color: AppColors.primary,
                                  bgColor: AppColors.primarySurface,
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

class _InvoiceFilters extends StatelessWidget {
  final InvoiceFilter filter;
  final void Function(InvoiceFilter) onFilterChanged;

  const _InvoiceFilters({required this.filter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // Status filter
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: filter.status,
              decoration: const InputDecoration(
                  labelText: 'الحالة', prefixIcon: Icon(Icons.filter_list)),
              items: const [
                DropdownMenuItem(value: null, child: Text('الكل')),
                DropdownMenuItem(value: 'unpaid', child: Text('غير مدفوعة')),
                DropdownMenuItem(value: 'partial', child: Text('جزئية')),
                DropdownMenuItem(value: 'paid', child: Text('مدفوعة')),
              ],
              onChanged: (v) => onFilterChanged(InvoiceFilter(
                  status: v, fromDate: filter.fromDate, toDate: filter.toDate)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date from
          Expanded(
            child: _DateFilter(
              label: 'من تاريخ',
              value: filter.fromDate,
              onChanged: (v) => onFilterChanged(InvoiceFilter(
                  fromDate: v, toDate: filter.toDate, status: filter.status)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date to
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

class _DateFilter extends StatelessWidget {
  final String label;
  final String? value;
  final void Function(String?) onChanged;

  const _DateFilter({required this.label, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: value ?? '');
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  ctrl.clear();
                  onChanged(null);
                })
            : null,
      ),
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
          final s = '${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}';
          ctrl.text = s;
          onChanged(s);
        }
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Invoice Detail Screen
// ═══════════════════════════════════════════════════════════════

// lib/features/invoices/presentation/screens/invoice_detail_screen.dart

class InvoiceDetailScreen extends ConsumerWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(invoiceId));
    final itemsAsync = ref.watch(invoiceItemsProvider(invoiceId));
    final paymentsAsync = ref.watch(invoicePaymentsProvider(invoiceId));
    final fmt = NumberFormat('#,##0.00', 'ar');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: invoiceAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (invoice) {
          if (invoice == null)
            return const ErrorView(message: 'الفاتورة غير موجودة');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + title
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
                ],
              ]),
              const SizedBox(height: AppSpacing.lg),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: items + summary ──────────────────
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
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

                        // Items
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: 'بنود الفاتورة'),
                              const SizedBox(height: AppSpacing.md),
                              itemsAsync.when(
                                loading: () => const LoadingView(),
                                error: (e, _) =>
                                    ErrorView(message: e.toString()),
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
                                                  Text(
                                                      '${fmt.format(item.unitPrice)} USD'),
                                                  Text(
                                                      '${fmt.format(item.discount)} USD'),
                                                  Text(
                                                      '${fmt.format(item.total)} USD',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                ])
                                            .toList(),
                                      ),
                              ),
                              const Divider(height: AppSpacing.lg),
                              // Totals
                              _TotalRow(
                                  'الإجمالي', fmt.format(invoice.totalAmount)),
                              _TotalRow('الخصم', fmt.format(invoice.discount),
                                  color: AppColors.warning),
                              _TotalRow('الصافي', fmt.format(invoice.netAmount),
                                  bold: true),
                              _TotalRow(
                                  'المدفوع', fmt.format(invoice.paidAmount),
                                  color: AppColors.success),
                              _TotalRow('المتبقي',
                                  fmt.format(invoice.remainingAmount),
                                  color: invoice.remainingAmount > 0
                                      ? AppColors.error
                                      : AppColors.textHint,
                                  bold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // ── Right: payments ────────────────────────
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
                                    onPressed: () => _showAddPaymentDialog(
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

  Future<void> _showAddPaymentDialog(BuildContext context, WidgetRef ref,
      Invoice inv, NumberFormat fmt) async {
    final amtCtrl = TextEditingController();
    String method = 'cash';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة دفعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المتبقي: ${fmt.format(inv.remainingAmount)} USD',
                  style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'المبلغ',
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
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                onChanged: (v) => setSt(() => method = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            PrimaryButton(
              label: 'تأكيد',
              onPressed: () async {
                final amount = double.tryParse(amtCtrl.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx);
                try {
                  final now = DateTime.now();
                  await ref.read(invoiceRepositoryProvider).addPayment(Payment(
                        invoiceId: inv.id!,
                        amount: amount,
                        paymentDate: '${now.year.toString().padLeft(4, '0')}-'
                            '${now.month.toString().padLeft(2, '0')}-'
                            '${now.day.toString().padLeft(2, '0')}',
                        method: PaymentMethodX.fromString(method),
                        createdAt: now,
                      ));
                  ref.invalidate(invoiceByIdProvider(inv.id!));
                  ref.invalidate(invoicePaymentsProvider(inv.id!));
                  if (context.mounted) showSnack(context, 'تم تسجيل الدفعة');
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

  Future<void> _deletePayment(
      BuildContext context, WidgetRef ref, int paymentId) async {
    final ok = await ConfirmDialog.show(context,
        title: 'حذف دفعة', message: 'هل تريد حذف هذه الدفعة؟', isDanger: true);
    if (ok) {
      try {
        await ref.read(invoiceRepositoryProvider).deletePayment(paymentId);
        ref.invalidate(invoiceByIdProvider(invoiceId));
        ref.invalidate(invoicePaymentsProvider(invoiceId));
        if (context.mounted) showSnack(context, 'تم حذف الدفعة');
      } catch (e) {
        if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
      }
    }
  }
}

// ─── Helper Widgets ───────────────────────────────────────────

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
          Text('$value USD',
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
              Text('${fmt.format(payment.amount)} USD',
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
