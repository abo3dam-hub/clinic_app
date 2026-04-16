// lib/features/accounting/presentation/screens/accounting_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart' as intl;

import 'package:clinic_app/core/providers/repository_providers.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ─── Providers (Logic Restored Exactly) ──────────────────────────────────────

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

// ─── Main Screen ─────────────────────────────────────────────────────────────

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _fmt = intl.NumberFormat('#,##0.00', 'en');

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

    return Scaffold(
      backgroundColor: Colors.grey[50], // خلفية هادئة لإبراز البطاقات
      body: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref, period),
            const SizedBox(height: AppSpacing.lg),
            _buildActionToolbar(context, ref, period),
            const SizedBox(height: AppSpacing.md),
            _buildCustomTabBar(),
            const SizedBox(height: AppSpacing.md),
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
          ],
        ),
      ),
    );
  }

  // هيدر علوي حديث يحتوي على العنوان والفلترة
  Widget _buildHeader(
      BuildContext context, WidgetRef ref, AccountingPeriod period) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'التقارير الختامية',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            Text(
              'نظرة شاملة على الأداء المالي للمنشأة',
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        _ModernPeriodPicker(
          period: period,
          onChanged: (p) =>
              ref.read(accountingPeriodProvider.notifier).state = p,
        ),
      ],
    );
  }

  // شريط العمليات (تحديث وتصدير)
  Widget _buildActionToolbar(
      BuildContext context, WidgetRef ref, AccountingPeriod period) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          _SmallIconButton(
            icon: Icons.refresh_rounded,
            label: 'تحديث البيانات',
            onTap: () => _refreshAll(ref, period),
            color: AppColors.primary,
          ),
          const Spacer(),
          Text('تصدير التقرير الحالي:',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          const SizedBox(width: 12),
          _ExportButton(
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF',
            onPressed: () => _handleExport(context, ref, isPdf: true),
          ),
          const SizedBox(width: 8),
          _ExportButton(
            icon: Icons.table_chart_rounded,
            label: 'Excel',
            onPressed: () => _handleExport(context, ref, isPdf: false),
            isExcel: true,
          ),
        ],
      ),
    );
  }

  // تصميم مخصص للـ Tabs يشبه الـ Segmented Control
  Widget _buildCustomTabBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
          ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textHint,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'ميزان المراجعة'),
          Tab(text: 'قائمة الدخل'),
          Tab(text: 'الميزانية العمومية'),
        ],
      ),
    );
  }

  // ─── Export Logic (Restored) ───────────────────────────────────────────

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
        final data = await ref.read(incomeStatementProvider(period).future);
        name = 'قائمة_الدخل_${_safeName(period.fromDate)}';
        bytes = isPdf
            ? await pdfService.generateIncomeStatementPdf(data)
            : await excelService.generateIncomeStatementExcel(data);
      } else {
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

// ─── Modern Components ───────────────────────────────────────────────────────

class _ModernPeriodPicker extends StatelessWidget {
  final AccountingPeriod period;
  final Function(AccountingPeriod) onChanged;
  const _ModernPeriodPicker({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DateCompactField(
            label: 'من',
            date: period.fromDate,
            onTap: (v) =>
                onChanged(AccountingPeriod(fromDate: v, toDate: period.toDate)),
          ),
          Container(
              width: 1,
              height: 24,
              color: Colors.grey[300],
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          _DateCompactField(
            label: 'إلى',
            date: period.toDate,
            onTap: (v) => onChanged(
                AccountingPeriod(fromDate: period.fromDate, toDate: v)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.calendar_month_rounded,
              color: AppColors.primary, size: 20),
        ],
      ),
    );
  }
}

class _DateCompactField extends StatelessWidget {
  final String label;
  final String date;
  final Function(String) onTap;
  const _DateCompactField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(date) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onTap(ClinicDateUtils.toDbDate(picked));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: AppColors.textHint)),
          Text(date,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Tab 1: Trial Balance ────────────────────────────────────────────────────

class _TrialBalanceTab extends ConsumerWidget {
  final AccountingPeriod period;
  final intl.NumberFormat fmt;
  const _TrialBalanceTab({required this.period, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trialBalanceProvider(period));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (balances) {
        final totalDr = balances.fold(0.0, (s, b) => s + b.totalDebit);
        final totalCr = balances.fold(0.0, (s, b) => s + b.totalCredit);
        final isBalanced = (totalDr - totalCr).abs() < 0.01;

        return AppCard(
          child: Column(
            children: [
              _buildBalanceHeader(isBalanced),
              const Divider(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: AppTable(
                    headers: const ['الكود', 'الحساب', 'النوع', 'مدين', 'دائن'],
                    rows: [
                      ...balances.map((b) => [
                            Text(b.account.code,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Colors.blueGrey)),
                            Text(b.account.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            _AccountTypeBadge(type: b.account.type),
                            _AmountText(
                                amount: b.totalDebit, fmt: fmt, isDebit: true),
                            _AmountText(
                                amount: b.totalCredit,
                                fmt: fmt,
                                isDebit: false),
                          ]),
                      // Totals row with distinct styling
                      [
                        const Text(''),
                        const Text('إجمالي الأرصدة',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary)),
                        const Text(''),
                        _AmountText(
                            amount: totalDr,
                            fmt: fmt,
                            isDebit: true,
                            isTotal: true),
                        _AmountText(
                            amount: totalCr,
                            fmt: fmt,
                            isDebit: false,
                            isTotal: true),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceHeader(bool isBalanced) {
    return Row(
      children: [
        const SectionHeader(title: 'ميزان المراجعة التحليلي'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isBalanced
                ? AppColors.success.withOpacity(0.1)
                : AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(isBalanced ? Icons.check_circle : Icons.warning,
                  size: 16,
                  color: isBalanced ? AppColors.success : AppColors.error),
              const SizedBox(width: 6),
              Text(
                isBalanced ? 'الحسابات متوازنة' : 'يوجد فرق في الأرصدة',
                style: TextStyle(
                  color: isBalanced ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tab 2: Income Statement ─────────────────────────────────────────────────

class _IncomeStatementTab extends ConsumerWidget {
  final AccountingPeriod period;
  final intl.NumberFormat fmt;
  const _IncomeStatementTab({required this.period, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomeStatementProvider(period));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (pl) => SingleChildScrollView(
        child: Column(
          children: [
            _FinancialSummaryCard(
              title: 'صافي الدخل',
              amount: pl.netIncome,
              fmt: fmt,
              isProfit: pl.netIncome >= 0,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ModernSectionCard(
                    title: 'الإيرادات',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    lines: pl.revenueLines,
                    total: pl.totalRevenue,
                    fmt: fmt,
                    ref: ref,
                    period: period,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ModernSectionCard(
                    title: 'المصروفات',
                    icon: Icons.trending_down_rounded,
                    color: AppColors.error,
                    lines: pl.expenseLines,
                    total: pl.totalExpenses,
                    fmt: fmt,
                    ref: ref,
                    period: period,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 3: Balance Sheet ────────────────────────────────────────────────────

class _BalanceSheetTab extends ConsumerWidget {
  final String asOfDate;
  final intl.NumberFormat fmt;
  const _BalanceSheetTab({required this.asOfDate, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(balanceSheetProvider(asOfDate));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (bs) => SingleChildScrollView(
        child: Column(
          children: [
            _BalanceEquationBar(
              totalAssets: bs.totalAssets,
              totalLiabEquity: bs.totalLiabilities + bs.totalEquity,
              isBalanced: bs.isBalanced,
              fmt: fmt,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assets Column
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'الأصول (Assets)'),
                        const Divider(),
                        ...bs.assetLines.map((l) => _FinancialRow(
                            label: l.accountName, amount: l.amount, fmt: fmt)),
                        const Divider(height: 32),
                        _FinancialRow(
                          label: 'إجمالي الأصول',
                          amount: bs.totalAssets,
                          fmt: fmt,
                          isBold: true,
                          textColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Liabilities & Equity Column
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'الالتزامات وحقوق الملكية'),
                        const Divider(),
                        Text('الالتزامات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontSize: 13)),
                        ...bs.liabilityLines.map((l) => _FinancialRow(
                            label: l.accountName, amount: l.amount, fmt: fmt)),
                        const SizedBox(height: 12),
                        Text('حقوق الملكية',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                fontSize: 13)),
                        ...bs.equityLines.map((l) => _FinancialRow(
                            label: l.accountName, amount: l.amount, fmt: fmt)),
                        _FinancialRow(
                          label: 'صافي دخل الفترة',
                          amount: bs.netIncome,
                          fmt: fmt,
                          textColor: bs.netIncome >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const Divider(height: 32),
                        _FinancialRow(
                          label: 'الإجمالي العام',
                          amount: bs.totalLiabilities + bs.totalEquity,
                          fmt: fmt,
                          isBold: true,
                          textColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UI Helper Widgets ───────────────────────────────────────────────────────

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SmallIconButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: color.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isExcel;

  const _ExportButton(
      {required this.icon,
      required this.label,
      required this.onPressed,
      this.isExcel = false});

  @override
  Widget build(BuildContext context) {
    final color = isExcel ? Colors.green[700]! : Colors.red[700]!;
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _AccountTypeBadge extends StatelessWidget {
  final AccountType type;
  const _AccountTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      AccountType.asset => ('أصل', Colors.blue),
      AccountType.liability => ('التزام', Colors.orange),
      AccountType.equity => ('ملكية', Colors.purple),
      AccountType.revenue => ('إيراد', Colors.green),
      AccountType.expense => ('مصروف', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _AmountText extends StatelessWidget {
  final double amount;
  final intl.NumberFormat fmt;
  final bool isDebit;
  final bool isTotal;

  const _AmountText(
      {required this.amount,
      required this.fmt,
      required this.isDebit,
      this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    if (amount == 0 && !isTotal)
      return const Text('—', style: TextStyle(color: Colors.grey));
    return Text(
      '${fmt.format(amount)}',
      style: TextStyle(
        color: isDebit ? AppColors.primary : AppColors.secondary,
        fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
        fontSize: isTotal ? 15 : 13,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final intl.NumberFormat fmt;
  final bool isProfit;

  const _FinancialSummaryCard(
      {required this.title,
      required this.amount,
      required this.fmt,
      required this.isProfit});

  @override
  Widget build(BuildContext context) {
    final color = isProfit ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(
            '\$${fmt.format(amount.abs())}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1),
          ),
          if (!isProfit)
            const Text('(خسارة)',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ModernSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<dynamic> lines; // تم التغيير إلى dynamic لتجنب خطأ التعريف
  final double total;
  final intl.NumberFormat fmt;
  final WidgetRef ref;
  final AccountingPeriod period;

  const _ModernSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
    required this.total,
    required this.fmt,
    required this.ref,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 24),
          // قمنا بالتأكد من الوصول للخصائص بشكل سليم
          ...lines.map((l) => _FinancialRow(
                label: l.accountName, // الآن سيقرأها بشكل صحيح
                amount: l.amount, // الآن سيقرأها بشكل صحيح
                fmt: fmt,
                onTap: () =>
                    _showAccountLedgerDialog(context, ref, l.accountId, period),
              )),
          const Divider(height: 32),
          _FinancialRow(
            label: 'الإجمالي',
            amount: total,
            fmt: fmt,
            isBold: true,
            textColor: color,
          ),
        ],
      ),
    );
  }

  void _showAccountLedgerDialog(BuildContext context, WidgetRef ref,
      int accountId, AccountingPeriod period) async {
    final ledgerFuture = ref.read(ledgerRepositoryProvider).getGeneralLedger(
          accountId: accountId,
          fromDate: period.fromDate,
          toDate: period.toDate,
        );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كشف حساب تفصيلي'),
        content: SizedBox(
          width: 800,
          height: 500,
          child: FutureBuilder<List<LedgerEntry>>(
            future: ledgerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('خطأ: ${snapshot.error}'));
              final entries = snapshot.data ?? const [];
              return entries.isEmpty
                  ? const Center(child: Text('لا توجد حركات مسجلة'))
                  : SingleChildScrollView(
                      child: AppTable(
                        headers: const [
                          'التاريخ',
                          'الوصف',
                          'مدين',
                          'دائن',
                          'الرصيد'
                        ],
                        rows: entries
                            .map((e) => [
                                  Text(e.date,
                                      style: const TextStyle(fontSize: 12)),
                                  Text(e.description,
                                      style: const TextStyle(fontSize: 12)),
                                  Text(fmt.format(e.debit),
                                      style: const TextStyle(
                                          color: AppColors.primary)),
                                  Text(fmt.format(e.credit),
                                      style: const TextStyle(
                                          color: AppColors.secondary)),
                                  Text(fmt.format(e.runningBalance),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ])
                            .toList(),
                      ),
                    );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final double amount;
  final intl.NumberFormat fmt;
  final bool isBold;
  final Color? textColor;
  final VoidCallback? onTap;

  const _FinancialRow(
      {required this.label,
      required this.amount,
      required this.fmt,
      this.isBold = false,
      this.textColor,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color:
                      isBold ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.ads_click, size: 22, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              fmt.format(amount),
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: textColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceEquationBar extends StatelessWidget {
  final double totalAssets;
  final double totalLiabEquity;
  final bool isBalanced;
  final intl.NumberFormat fmt;

  const _BalanceEquationBar(
      {required this.totalAssets,
      required this.totalLiabEquity,
      required this.isBalanced,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBalanced ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isBalanced ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _EqPart(label: 'إجمالي الأصول', amount: totalAssets, fmt: fmt),
          Icon(Icons.drag_handle_rounded,
              color: isBalanced ? Colors.green : Colors.red),
          _EqPart(
              label: 'الالتزامات + الملكية', amount: totalLiabEquity, fmt: fmt),
          if (isBalanced)
            const Icon(Icons.check_circle, color: Colors.green)
          else
            const Icon(Icons.warning, color: Colors.red),
        ],
      ),
    );
  }
}

class _EqPart extends StatelessWidget {
  final String label;
  final double amount;
  final intl.NumberFormat fmt;
  const _EqPart({required this.label, required this.amount, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(fmt.format(amount),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primary)),
      ],
    );
  }
}
