// lib/features/accounting/presentation/screens/accounting_screen.dart
//
// Presents three financial statements derived from journal data:
//   1. Trial Balance
//   2. Income Statement (Profit & Loss)
//   3. Balance Sheet

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // Required for StateProvider in Riverpod 3.x
import 'package:intl/intl.dart';

import 'package:clinic_app/core/providers/repository_providers.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

class AccountingPeriod {
  final String fromDate;
  final String toDate;
  const AccountingPeriod({required this.fromDate, required this.toDate});
  @override
  bool operator ==(Object o) =>
      o is AccountingPeriod && o.fromDate == fromDate && o.toDate == toDate;
  @override
  int get hashCode => Object.hash(fromDate, toDate);
}

final accountingPeriodProvider = StateProvider<AccountingPeriod>((ref) {
  final now = DateTime.now();
  return AccountingPeriod(
    fromDate: ClinicDateUtils.yearStart(now.year),
    toDate: ClinicDateUtils.yearEnd(now.year),
  );
});

final trialBalanceProvider =
    FutureProvider.family<List<LedgerBalance>, AccountingPeriod>(
        (ref, period) => ref
            .watch(ledgerRepositoryProvider)
            .getTrialBalance(fromDate: period.fromDate, toDate: period.toDate));

final incomeStatementProvider =
    FutureProvider.family<IncomeStatement, AccountingPeriod>((ref, period) =>
        ref.watch(ledgerRepositoryProvider).getIncomeStatement(
            fromDate: period.fromDate, toDate: period.toDate));

final balanceSheetProvider = FutureProvider.family<BalanceSheet, String>(
    (ref, asOfDate) =>
        ref.watch(ledgerRepositoryProvider).getBalanceSheet(asOfDate));

final accountLedgerProvider =
    FutureProvider.family<List<LedgerEntry>, Map<String, dynamic>>(
        (ref, params) => ref.watch(ledgerRepositoryProvider).getGeneralLedger(
            accountId: params['accountId'],
            fromDate: params['fromDate'],
            toDate: params['toDate']));

// ─────────────────────────────────────────────────────────────────────────────

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _fmt = NumberFormat('#,##0.00', 'en');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(accountingPeriodProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        // ── Period picker ────────────────────────────────────────
        _PeriodBar(
          period: period,
          onChanged: (p) =>
              ref.read(accountingPeriodProvider.notifier).state = p,
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Refresh Button ───────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SecondaryButton(
              label: 'تحديث',
              icon: Icons.refresh,
              onPressed: () => _refreshAll(ref, period),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Tabs ─────────────────────────────────────────────────
        AppCard(
          padding: EdgeInsets.zero,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'ميزان المراجعة'),
              Tab(text: 'قائمة الدخل'),
              Tab(text: 'الميزانية العمومية'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Export Toolbar ───────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SecondaryButton(
              label: 'تصدير PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () => _handleExport(context, ref, isPdf: true),
            ),
            const SizedBox(width: AppSpacing.sm),
            SecondaryButton(
              label: 'تصدير Excel',
              icon: Icons.table_view_outlined,
              onPressed: () => _handleExport(context, ref, isPdf: false),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Tab bodies ───────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TrialBalanceTab(period: period, fmt: _fmt),
              _IncomeStatementTab(period: period, fmt: _fmt),
              _BalanceSheetTab(asOfDate: period.toDate, fmt: _fmt),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref,
      {required bool isPdf}) async {
    final period = ref.read(accountingPeriodProvider);
    final tabIndex = _tabs.index;
    final pdfService = ref.read(pdfExportServiceProvider);
    final excelService = ref.read(excelExportServiceProvider);

    try {
      showSnack(context, 'جاري تحضير الملف...');
      Uint8List bytes;
      String name;

      if (tabIndex == 0) {
        // Trial Balance
        final data = await ref.read(trialBalanceProvider(period).future);
        name = 'ميزان_المراجعة_${_safeName(period.fromDate)}';
        bytes = isPdf
            ? await pdfService.generateTrialBalancePdf(
                balances: data,
                fromDate: period.fromDate,
                toDate: period.toDate)
            : await excelService.generateTrialBalanceExcel(
                balances: data,
                fromDate: period.fromDate,
                toDate: period.toDate);
      } else if (tabIndex == 1) {
        // Income Statement
        final data = await ref.read(incomeStatementProvider(period).future);
        name = 'قائمة_الدخل_${_safeName(period.fromDate)}';
        bytes = isPdf
            ? await pdfService.generateIncomeStatementPdf(data)
            : await excelService.generateIncomeStatementExcel(data);
      } else {
        // Balance Sheet
        final data = await ref.read(balanceSheetProvider(period.toDate).future);
        name = 'الميزانية_العمومية_${_safeName(period.toDate)}';
        bytes = isPdf
            ? await pdfService.generateBalanceSheetPdf(data)
            : await excelService.generateBalanceSheetExcel(data);
      }

      await pdfService.printOrShare(bytes, name: name);
    } catch (e) {
      if (context.mounted)
        showSnack(context, 'خطأ أثناء التصدير: $e', error: true);
    }
  }

  void _refreshAll(WidgetRef ref, AccountingPeriod period) {
    ref.invalidate(trialBalanceProvider(period));
    ref.invalidate(incomeStatementProvider(period));
    ref.invalidate(balanceSheetProvider(period.toDate));
  }

  String _safeName(String s) => s.replaceAll('-', '_');
}

// ─── Period Bar ───────────────────────────────────────────────────────────────

class _PeriodBar extends StatelessWidget {
  final AccountingPeriod period;
  final void Function(AccountingPeriod) onChanged;
  const _PeriodBar({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          const Icon(Icons.date_range_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('الفترة:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: _DatePickerField(
              label: 'من',
              value: period.fromDate,
              onChanged: (v) => onChanged(
                  AccountingPeriod(fromDate: v, toDate: period.toDate)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DatePickerField(
              label: 'إلى',
              value: period.toDate,
              onChanged: (v) => onChanged(
                  AccountingPeriod(fromDate: period.fromDate, toDate: v)),
            ),
          ),
        ]),
      );
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String) onChanged;
  const _DatePickerField(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: value);
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(2000),
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

// ─── Trial Balance Tab ────────────────────────────────────────────────────────

class _TrialBalanceTab extends ConsumerWidget {
  final AccountingPeriod period;
  final NumberFormat fmt;
  const _TrialBalanceTab({required this.period, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialBalanceProvider(period));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (balances) {
        final totalDr = balances.fold(0.0, (s, b) => s + b.totalDebit);
        final totalCr = balances.fold(0.0, (s, b) => s + b.totalCredit);
        final isBalanced = (totalDr - totalCr).abs() < 0.01;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const SectionHeader(title: 'ميزان المراجعة'),
                const Spacer(),
                StatusChip(
                  label: isBalanced ? 'متوازن ✓' : 'غير متوازن ✗',
                  color: isBalanced ? AppColors.success : AppColors.error,
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AppTable(
                  headers: const ['الكود', 'الحساب', 'النوع', 'مدين', 'دائن'],
                  rows: [
                    ...balances.map((b) => [
                          Text(b.account.code,
                              style: const TextStyle(
                                  color: AppColors.textHint,
                                  fontFamily: 'monospace')),
                          Text(b.account.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          _AccountTypeChip(type: b.account.type),
                          Text(
                            b.totalDebit > 0
                                ? '\$${fmt.format(b.totalDebit)}'
                                : '—',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            b.totalCredit > 0
                                ? '\$${fmt.format(b.totalCredit)}'
                                : '—',
                            style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                    // Totals row
                    [
                      const Text(''),
                      const Text('الإجمالي',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const Text(''),
                      Text('\$${fmt.format(totalDr)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                      Text('\$${fmt.format(totalCr)}',
                          style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Income Statement Tab ─────────────────────────────────────────────────────

class _IncomeStatementTab extends ConsumerWidget {
  final AccountingPeriod period;
  final NumberFormat fmt;
  const _IncomeStatementTab({required this.period, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomeStatementProvider(period));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (pl) => SingleChildScrollView(
        child: Column(children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'الإيرادات'),
                const SizedBox(height: AppSpacing.md),
                ...pl.revenueLines.map((l) => _FinLine(
                    label: l.accountName,
                    value: '\$${fmt.format(l.amount)}',
                    onDetailsPressed: () => _showAccountLedgerDialog(
                        context, ref, l.accountId, period))),
                const Divider(height: 20),
                _FinLine(
                    label: 'إجمالي الإيرادات',
                    value: '\$${fmt.format(pl.totalRevenue)}',
                    bold: true,
                    color: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'المصروفات'),
                const SizedBox(height: AppSpacing.md),
                ...pl.expenseLines.map((l) => _FinLine(
                    label: l.accountName,
                    value: '\$${fmt.format(l.amount)}',
                    onDetailsPressed: () => _showAccountLedgerDialog(
                        context, ref, l.accountId, period))),
                const Divider(height: 20),
                _FinLine(
                    label: 'إجمالي المصروفات',
                    value: '\$${fmt.format(pl.totalExpenses)}',
                    bold: true,
                    color: AppColors.error),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: pl.netIncome >= 0
                ? AppColors.successSurface
                : AppColors.errorSurface,
            child: _FinLine(
              label: pl.netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة',
              value: '\$${fmt.format(pl.netIncome.abs())}',
              bold: true,
              color: pl.netIncome >= 0 ? AppColors.success : AppColors.error,
              large: true,
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showAccountLedgerDialog(BuildContext context, WidgetRef ref,
      int accountId, AccountingPeriod period) async {
    final ledgerAsync = ref.watch(accountLedgerProvider({
      'accountId': accountId,
      'fromDate': period.fromDate,
      'toDate': period.toDate,
    }));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كشف الحساب التفصيلي'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ledgerAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (entries) => entries.isEmpty
                ? const Center(child: Text('لا توجد حركات'))
                : SingleChildScrollView(
                    child: AppTable(
                      headers: const [
                        'التاريخ',
                        'الوصف',
                        'المرجع',
                        'مدين',
                        'دائن',
                        'الرصيد'
                      ],
                      rows: entries
                          .map((e) => [
                                Text(e.date),
                                Text(e.description),
                                Text(e.reference ?? '-'),
                                Text(
                                    '\$${NumberFormat('#,##0.00', 'en').format(e.debit)}'),
                                Text(
                                    '\$${NumberFormat('#,##0.00', 'en').format(e.credit)}'),
                                Text(
                                    '\$${NumberFormat('#,##0.00', 'en').format(e.runningBalance)}'),
                              ])
                          .toList(),
                    ),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

// ─── Balance Sheet Tab ────────────────────────────────────────────────────────

class _BalanceSheetTab extends ConsumerWidget {
  final String asOfDate;
  final NumberFormat fmt;
  const _BalanceSheetTab({required this.asOfDate, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(balanceSheetProvider(asOfDate));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (bs) => SingleChildScrollView(
        child: Column(children: [
          // Assets
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'الأصول'),
                const SizedBox(height: AppSpacing.md),
                ...bs.assetLines.map((l) => _FinLine(
                    label: l.accountName, value: '\$${fmt.format(l.amount)}')),
                const Divider(height: 20),
                _FinLine(
                    label: 'إجمالي الأصول',
                    value: '\$${fmt.format(bs.totalAssets)}',
                    bold: true,
                    color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Liabilities + Equity
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'الالتزامات وحقوق الملكية'),
                const SizedBox(height: AppSpacing.md),
                ...bs.liabilityLines.map((l) => _FinLine(
                    label: l.accountName, value: '\$${fmt.format(l.amount)}')),
                ...bs.equityLines.map((l) => _FinLine(
                    label: l.accountName, value: '\$${fmt.format(l.amount)}')),
                _FinLine(
                    label: 'صافي الدخل (الفترة الحالية)',
                    value: '\$${fmt.format(bs.netIncome)}',
                    color: bs.netIncome >= 0
                        ? AppColors.success
                        : AppColors.error),
                const Divider(height: 20),
                _FinLine(
                    label: 'إجمالي الالتزامات وحقوق الملكية',
                    value:
                        '\$${fmt.format(bs.totalLiabilities + bs.totalEquity)}',
                    bold: true,
                    color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Equation check
          AppCard(
            color: bs.isBalanced
                ? AppColors.successSurface
                : AppColors.errorSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  bs.isBalanced
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: bs.isBalanced ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  bs.isBalanced
                      ? 'الميزانية متوازنة: الأصول = الالتزامات + حقوق الملكية'
                      : 'تحذير: الميزانية غير متوازنة',
                  style: TextStyle(
                    color: bs.isBalanced ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _AccountTypeChip extends StatelessWidget {
  final AccountType type;
  const _AccountTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      AccountType.asset => ('أصل', AppColors.primary),
      AccountType.liability => ('التزام', AppColors.warning),
      AccountType.equity => ('ملكية', AppColors.secondary),
      AccountType.revenue => ('إيراد', AppColors.success),
      AccountType.expense => ('مصروف', AppColors.error),
    };
    return StatusChip(label: label, color: color);
  }
}

class _FinLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final bool large;
  final VoidCallback? onDetailsPressed;
  const _FinLine(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color,
      this.large = false,
      this.onDetailsPressed});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color:
                        bold ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: large ? 16 : 14,
                  )),
            ),
            if (onDetailsPressed != null)
              TextButton(
                onPressed: onDetailsPressed,
                child: const Text('تفاصيل', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            const SizedBox(width: 8),
            Text(value,
                style: TextStyle(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: large ? 18 : 14,
                )),
          ],
        ),
      );
}
