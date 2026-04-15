// lib/features/expenses/presentation/screens/expenses_screen.dart

import 'package:clinic_app/core/providers/service_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../accounting/presentation/screens/accounting_screen.dart';

// ─── Local providers ──────────────────────────────────────────

final _expensesProvider = FutureProvider.autoDispose
    .family<List<Expense>, _ExpenseFilter>(
        (ref, filter) => ref.watch(expenseRepositoryProvider).getAll(
              fromDate: filter.fromDate,
              toDate: filter.toDate,
              category: filter.category,
            ));

final _categoriesProvider = FutureProvider<List<String>>(
    (ref) => ref.watch(expenseRepositoryProvider).getCategories());

class _ExpenseFilter {
  final String? fromDate;
  final String? toDate;
  final String? category;

  const _ExpenseFilter({this.fromDate, this.toDate, this.category});

  @override
  bool operator ==(Object o) =>
      o is _ExpenseFilter &&
      o.fromDate == fromDate &&
      o.toDate == toDate &&
      o.category == category;

  @override
  int get hashCode => Object.hash(fromDate, toDate, category);
}

// ─── Screen ───────────────────────────────────────────────────

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  _ExpenseFilter _filter = _ExpenseFilter(
    fromDate: ClinicDateUtils.currentMonthStart(),
    toDate: ClinicDateUtils.currentMonthEnd(),
  );

  final _fmt = NumberFormat('#,##0.00', 'ar');

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(_expensesProvider(_filter));
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        // ── Filters ─────────────────────────────────────────────
        _FiltersRow(
          filter: _filter,
          categories: categoriesAsync.value ?? [],
          onChanged: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Summary ──────────────────────────────────────────────
        expensesAsync.whenData((expenses) {
              final total = expenses.fold<double>(0, (s, e) => s + e.amount);
              return _SummaryBar(
                  total: total, count: expenses.length, fmt: _fmt);
            }).value ??
            const SizedBox.shrink(),
        const SizedBox(height: AppSpacing.md),

        // ── Table + Add button ────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          PrimaryButton(
            label: 'مصروف جديد',
            icon: Icons.add,
            onPressed: () => _showExpenseDialog(context, ref, null),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),

        Expanded(
          child: expensesAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (expenses) => expenses.isEmpty
                ? const EmptyState(
                    title: 'لا توجد مصروفات', icon: Icons.payments_outlined)
                : AppTable(
                    headers: const [
                      'التاريخ',
                      'الفئة',
                      'الوصف',
                      'المبلغ',
                      'إجراءات'
                    ],
                    rows: expenses
                        .map((e) => [
                              Text(e.expenseDate,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              StatusChip(
                                  label: e.category, color: AppColors.primary),
                              Text(e.description,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              Text('${_fmt.format(e.amount)} USD',
                                  style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconActionButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: 'تعديل',
                                  onPressed: () =>
                                      _showExpenseDialog(context, ref, e),
                                  color: AppColors.primary,
                                  bgColor: AppColors.primarySurface,
                                ),
                                const SizedBox(width: 6),
                                IconActionButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'حذف',
                                  onPressed: () =>
                                      _confirmDelete(context, ref, e),
                                  color: AppColors.error,
                                  bgColor: AppColors.errorSurface,
                                ),
                              ]),
                            ])
                        .toList(),
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> _showExpenseDialog(
      BuildContext ctx, WidgetRef ref, Expense? existing) async {
    final categories = ref.read(_categoriesProvider).value ?? [];
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final amtCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    String date = existing?.expenseDate ?? ClinicDateUtils.todayString();
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (innerCtx) => StatefulBuilder(
        builder: (innerCtx, setSt) => AlertDialog(
          title: Text(existing == null ? 'مصروف جديد' : 'تعديل المصروف'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Category (autocomplete from existing ones)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('الفئة',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const Text(' *',
                          style: TextStyle(color: AppColors.error)),
                    ]),
                    const SizedBox(height: 6),
                    Autocomplete<String>(
                      initialValue:
                          TextEditingValue(text: existing?.category ?? ''),
                      optionsBuilder: (v) => categories
                          .where((c) =>
                              c.toLowerCase().contains(v.text.toLowerCase()))
                          .toList(),
                      onSelected: (v) => catCtrl.text = v,
                      fieldViewBuilder: (_, ctrl, focus, __) {
                        ctrl.text = catCtrl.text;
                        ctrl.addListener(() => catCtrl.text = ctrl.text);
                        return TextFormField(
                          controller: ctrl,
                          focusNode: focus,
                          decoration: const InputDecoration(
                              hintText: 'رواتب / إيجار / مستلزمات ...'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'الفئة مطلوبة'
                              : null,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'الوصف',
                  required: true,
                  controller: descCtrl,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'الوصف مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                      child: AppTextField(
                    label: 'المبلغ (USD)',
                    required: true,
                    controller: amtCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
                      return null;
                    },
                  )),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                      child: AppDateField(
                    label: 'التاريخ',
                    required: true,
                    value: date,
                    onChanged: (d) => setSt(() => date = d),
                  )),
                ]),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    label: 'ملاحظات', controller: notesCtrl, maxLines: 2),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(innerCtx),
                child: const Text('إلغاء')),
            PrimaryButton(
              label: existing == null ? 'إضافة' : 'حفظ',
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(innerCtx);
                final now = DateTime.now();
                final expense = Expense(
                  id: existing?.id,
                  category: catCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  amount: double.parse(amtCtrl.text),
                  expenseDate: date,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                try {
                  final repo = ref.read(expenseRepositoryProvider);
                  if (existing == null) {
                    await repo.create(expense);
                    if (ctx.mounted) showSnack(ctx, 'تم إضافة المصروف');
                  } else {
                    await repo.update(expense);
                    if (ctx.mounted) showSnack(ctx, 'تم التحديث');
                  }
                  ref.invalidate(_expensesProvider(_filter));
                  ref.invalidate(_categoriesProvider);
                  final todayStr =
                      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  ref.invalidate(dailyReportProvider(todayStr));
                  ref.invalidate(cashBoxTodayProvider);
                  // Invalidate accounting providers
                  ref.invalidate(trialBalanceProvider(AccountingPeriod(fromDate: '2020-01-01', toDate: DateTime.now().toIso8601String().split('T')[0])));
                  ref.invalidate(incomeStatementProvider(AccountingPeriod(fromDate: '2020-01-01', toDate: DateTime.now().toIso8601String().split('T')[0])));
                  ref.invalidate(balanceSheetProvider(DateTime.now().toIso8601String().split('T')[0]));
                } catch (e) {
                  if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, WidgetRef ref, Expense expense) async {
    final ok = await ConfirmDialog.show(ctx,
        title: 'حذف مصروف',
        message: 'هل تريد حذف "${expense.description}"؟',
        confirmLabel: 'حذف',
        isDanger: true);
    if (ok && ctx.mounted) {
      try {
        await ref.read(expenseRepositoryProvider).delete(expense.id!);
        ref.invalidate(_expensesProvider(_filter));
        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        ref.invalidate(dailyReportProvider(todayStr));
        ref.invalidate(cashBoxTodayProvider);
        // Invalidate accounting providers
        ref.invalidate(trialBalanceProvider(AccountingPeriod(fromDate: '2020-01-01', toDate: DateTime.now().toIso8601String().split('T')[0])));
        ref.invalidate(incomeStatementProvider(AccountingPeriod(fromDate: '2020-01-01', toDate: DateTime.now().toIso8601String().split('T')[0])));
        ref.invalidate(balanceSheetProvider(DateTime.now().toIso8601String().split('T')[0]));
        if (ctx.mounted) showSnack(ctx, 'تم الحذف');
      } catch (e) {
        if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
      }
    }
  }

  // expose filter for use in child widget
  _ExpenseFilter get filter => _filter;
  set filter(_ExpenseFilter f) => setState(() => _filter = f);
}

// ─── Filters Row ──────────────────────────────────────────────

class _FiltersRow extends StatelessWidget {
  final _ExpenseFilter filter;
  final List<String> categories;
  final void Function(_ExpenseFilter) onChanged;

  const _FiltersRow({
    required this.filter,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _DatePickerField(
          label: 'من',
          value: filter.fromDate,
          onChanged: (v) => onChanged(_ExpenseFilter(
              fromDate: v, toDate: filter.toDate, category: filter.category)),
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child: _DatePickerField(
          label: 'إلى',
          value: filter.toDate,
          onChanged: (v) => onChanged(_ExpenseFilter(
              fromDate: filter.fromDate, toDate: v, category: filter.category)),
        )),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue:
                categories.contains(filter.category) ? filter.category : null,
            decoration: const InputDecoration(
                labelText: 'الفئة',
                prefixIcon: Icon(Icons.category_outlined, size: 18)),
            items: [
              const DropdownMenuItem(value: null, child: Text('كل الفئات')),
              ...categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => onChanged(_ExpenseFilter(
                fromDate: filter.fromDate, toDate: filter.toDate, category: v)),
          ),
        ),
      ]);
}

// ─── Summary Bar ──────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double total;
  final int count;
  final NumberFormat fmt;

  const _SummaryBar(
      {required this.total, required this.count, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.errorSurface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.payments_outlined, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Text('إجمالي المصروفات:',
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${fmt.format(total)} USD',
              style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(width: 16),
          Text('($count مصروف)',
              style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
        ]),
      );
}

// ─── Date picker field ─────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final void Function(String?) onChanged;

  const _DatePickerField({
    required this.label,
    this.value,
    required this.onChanged,
  });

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
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          locale: const Locale('ar'),
        );
        if (picked != null) {
          final s = ClinicDateUtils.toDbDate(picked);
          ctrl.text = s;
          onChanged(s);
        }
      },
    );
  }
}
