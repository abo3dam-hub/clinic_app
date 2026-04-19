// lib/features/accounting/presentation/screens/accounting_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart' as intl;
import 'package:go_router/go_router.dart';

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

final detailedStatementProvider =
    FutureProvider.family<DetailedStatement, StatementFilter>((ref, filter) =>
        ref.watch(ledgerRepositoryProvider).getDetailedStatement(filter));

final patientsFilterProvider = FutureProvider<List<FilterOption>>(
    (ref) => ref.watch(ledgerRepositoryProvider).getPatientsForFilter());

final doctorsFilterProvider = FutureProvider<List<FilterOption>>(
    (ref) => ref.watch(ledgerRepositoryProvider).getDoctorsForFilter());

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
      backgroundColor: Colors.grey[50],
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

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, AccountingPeriod period) {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التقارير الختامية',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        Text('نظرة شاملة على الأداء المالي للمنشأة',
            style: TextStyle(color: AppColors.textHint, fontSize: 14)),
      ]),
      const Spacer(),
      _ModernPeriodPicker(
        period: period,
        onChanged: (p) => ref.read(accountingPeriodProvider.notifier).state = p,
      ),
    ]);
  }

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
      child: Row(children: [
        _SmallIconButton(
          icon: Icons.refresh_rounded,
          label: 'تحديث البيانات',
          onTap: () => _refreshAll(ref, period),
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        // زر الانتقال لشاشة كشف الحساب المستقلة
        _StatementNavButton(onTap: () => context.push('/statement')),
        const Spacer(),
        Text('تصدير التقرير الحالي:',
            style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        const SizedBox(width: 12),
        _ExportButton(
            icon: Icons.picture_as_pdf_rounded,
            label: 'PDF',
            onPressed: () => _handleExport(context, ref, isPdf: true)),
        const SizedBox(width: 8),
        _ExportButton(
            icon: Icons.table_chart_rounded,
            label: 'Excel',
            onPressed: () => _handleExport(context, ref, isPdf: false),
            isExcel: true),
      ]),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'ميزان المراجعة'),
          Tab(text: 'قائمة الدخل'),
          Tab(text: 'الميزانية العمومية'),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref,
      {required bool isPdf}) async {
    final period = ref.read(accountingPeriodProvider);
    final pdfService = ref.read(pdfExportServiceProvider);
    final excelService = ref.read(excelExportServiceProvider);
    try {
      showSnack(context, 'جاري تحضير الملف...');
      Uint8List bytes;
      String name;
      if (_tabs.index == 0) {
        final data = await ref.read(trialBalanceProvider(period).future);
        name = 'ميزان_المراجعة_${_s(period.fromDate)}';
        bytes = isPdf
            ? await pdfService.generateTrialBalancePdf(
                balances: data,
                fromDate: period.fromDate,
                toDate: period.toDate)
            : await excelService.generateTrialBalanceExcel(
                balances: data,
                fromDate: period.fromDate,
                toDate: period.toDate);
      } else if (_tabs.index == 1) {
        final data = await ref.read(incomeStatementProvider(period).future);
        name = 'قائمة_الدخل_${_s(period.fromDate)}';
        bytes = isPdf
            ? await pdfService.generateIncomeStatementPdf(data)
            : await excelService.generateIncomeStatementExcel(data);
      } else {
        final data = await ref.read(balanceSheetProvider(period.toDate).future);
        name = 'الميزانية_العمومية_${_s(period.toDate)}';
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

  String _s(String s) => s.replaceAll('-', '_');
}

// ─── Period Picker ────────────────────────────────────────────────────────────

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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _DateField(
            label: 'من',
            date: period.fromDate,
            onTap: (v) => onChanged(
                AccountingPeriod(fromDate: v, toDate: period.toDate))),
        Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 12)),
        _DateField(
            label: 'إلى',
            date: period.toDate,
            onTap: (v) => onChanged(
                AccountingPeriod(fromDate: period.fromDate, toDate: v))),
        const SizedBox(width: 8),
        const Icon(Icons.calendar_month_rounded,
            color: AppColors.primary, size: 20),
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String date;
  final Function(String) onTap;
  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(date) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (p != null) onTap(ClinicDateUtils.toDbDate(p));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
        Text(date,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ─── Tab 1: Trial Balance ─────────────────────────────────────────────────────

class _TrialBalanceTab extends ConsumerWidget {
  final AccountingPeriod period;
  final intl.NumberFormat fmt;
  const _TrialBalanceTab({required this.period, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(trialBalanceProvider(period)).when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (balances) {
            final totalDr = balances.fold(0.0, (s, b) => s + b.totalDebit);
            final totalCr = balances.fold(0.0, (s, b) => s + b.totalCredit);
            final ok = (totalDr - totalCr).abs() < 0.01;
            return AppCard(
              child: Column(children: [
                Row(children: [
                  const SectionHeader(title: 'ميزان المراجعة التحليلي'),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ok
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Icon(ok ? Icons.check_circle : Icons.warning,
                          size: 16,
                          color: ok ? AppColors.success : AppColors.error),
                      const SizedBox(width: 6),
                      Text(ok ? 'الحسابات متوازنة' : 'يوجد فرق في الأرصدة',
                          style: TextStyle(
                              color: ok ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ]),
                  ),
                ]),
                const Divider(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: AppTable(
                      headers: const [
                        'الكود',
                        'الحساب',
                        'النوع',
                        'مدين',
                        'دائن'
                      ],
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
                              _AmountCell(
                                  amount: b.totalDebit,
                                  fmt: fmt,
                                  isDebit: true),
                              _AmountCell(
                                  amount: b.totalCredit,
                                  fmt: fmt,
                                  isDebit: false),
                            ]),
                        [
                          const Text(''),
                          const Text('إجمالي الأرصدة',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary)),
                          const Text(''),
                          _AmountCell(
                              amount: totalDr,
                              fmt: fmt,
                              isDebit: true,
                              isTotal: true),
                          _AmountCell(
                              amount: totalCr,
                              fmt: fmt,
                              isDebit: false,
                              isTotal: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ]),
            );
          },
        );
  }
}

// ─── Tab 2: Income Statement ──────────────────────────────────────────────────

class _IncomeStatementTab extends ConsumerWidget {
  final AccountingPeriod period;
  final intl.NumberFormat fmt;
  const _IncomeStatementTab({required this.period, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(incomeStatementProvider(period)).when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (pl) => SingleChildScrollView(
            child: Column(children: [
              _FinancialSummaryCard(
                  title: 'صافي الدخل',
                  amount: pl.netIncome,
                  fmt: fmt,
                  isProfit: pl.netIncome >= 0),
              const SizedBox(height: AppSpacing.md),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _ModernSectionCard(
                        title: 'الإيرادات',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                        lines: pl.revenueLines,
                        total: pl.totalRevenue,
                        fmt: fmt,
                        ref: ref,
                        period: period)),
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
                        period: period)),
              ]),
            ]),
          ),
        );
  }
}

// ─── Tab 3: Balance Sheet ─────────────────────────────────────────────────────

class _BalanceSheetTab extends ConsumerWidget {
  final String asOfDate;
  final intl.NumberFormat fmt;
  const _BalanceSheetTab({required this.asOfDate, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(balanceSheetProvider(asOfDate)).when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (bs) => SingleChildScrollView(
            child: Column(children: [
              _BalanceEquationBar(
                  totalAssets: bs.totalAssets,
                  totalLiabEquity: bs.totalLiabilities + bs.totalEquity,
                  isBalanced: bs.isBalanced,
                  fmt: fmt),
              const SizedBox(height: AppSpacing.md),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'الأصول (Assets)'),
                          const Divider(),
                          ...bs.assetLines.map((l) => _FinancialRow(
                              label: l.accountName,
                              amount: l.amount,
                              fmt: fmt)),
                          const Divider(height: 32),
                          _FinancialRow(
                              label: 'إجمالي الأصول',
                              amount: bs.totalAssets,
                              fmt: fmt,
                              isBold: true,
                              textColor: AppColors.primary),
                        ]),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                              title: 'الالتزامات وحقوق الملكية'),
                          const Divider(),
                          Text('الالتزامات',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[800],
                                  fontSize: 13)),
                          ...bs.liabilityLines.map((l) => _FinancialRow(
                              label: l.accountName,
                              amount: l.amount,
                              fmt: fmt)),
                          const SizedBox(height: 12),
                          Text('حقوق الملكية',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                  fontSize: 13)),
                          ...bs.equityLines.map((l) => _FinancialRow(
                              label: l.accountName,
                              amount: l.amount,
                              fmt: fmt)),
                          _FinancialRow(
                              label: 'صافي دخل الفترة',
                              amount: bs.netIncome,
                              fmt: fmt,
                              textColor: bs.netIncome >= 0
                                  ? AppColors.success
                                  : AppColors.error),
                          const Divider(height: 32),
                          _FinancialRow(
                              label: 'الإجمالي العام',
                              amount: bs.totalLiabilities + bs.totalEquity,
                              fmt: fmt,
                              isBold: true,
                              textColor: AppColors.primary),
                        ]),
                  ),
                ),
              ]),
            ]),
          ),
        );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 4 — كشف الحساب التفصيلي
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailedStatementTab extends ConsumerStatefulWidget {
  final AccountingPeriod period;
  final intl.NumberFormat fmt;
  const _DetailedStatementTab({required this.period, required this.fmt});

  @override
  ConsumerState<_DetailedStatementTab> createState() =>
      _DetailedStatementTabState();
}

class _DetailedStatementTabState extends ConsumerState<_DetailedStatementTab> {
  int? _patientId;
  String? _patientName;
  int? _doctorId;
  String? _doctorName;
  bool _showChart = true;

  StatementFilter get _filter => StatementFilter(
        fromDate: widget.period.fromDate,
        toDate: widget.period.toDate,
        patientId: _patientId,
        patientName: _patientName,
        doctorId: _doctorId,
        doctorName: _doctorName,
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(detailedStatementProvider(_filter));
    return Column(children: [
      _buildFilterBar(context),
      const SizedBox(height: 10),
      Expanded(
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => ErrorView(message: e.toString()),
          data: _buildContent,
        ),
      ),
    ]);
  }

  // ── Filter Bar ──────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context) {
    final patients = ref.watch(patientsFilterProvider).asData?.value ?? [];
    final doctors = ref.watch(doctorsFilterProvider).asData?.value ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(children: [
        const Icon(Icons.person_search_rounded,
            size: 18, color: AppColors.secondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 185,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _patientId,
              hint: const Text('كل المرضى',
                  style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo'),
              onChanged: (v) => setState(() {
                _patientId = v;
                _patientName =
                    patients.where((p) => p.id == v).firstOrNull?.name;
              }),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('كل المرضى')),
                ...patients.map((p) => DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    )),
              ],
            ),
          ),
        ),
        Container(
            width: 1,
            height: 28,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 12)),
        const Icon(Icons.medical_services_rounded,
            size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        SizedBox(
          width: 185,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _doctorId,
              hint: const Text('كل الأطباء',
                  style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo'),
              onChanged: (v) => setState(() {
                _doctorId = v;
                _doctorName = doctors.where((d) => d.id == v).firstOrNull?.name;
              }),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('كل الأطباء')),
                ...doctors.map((d) => DropdownMenuItem<int?>(
                      value: d.id,
                      child: Text(d.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    )),
              ],
            ),
          ),
        ),
        const Spacer(),
        _SmallIconButton(
          icon: _showChart ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
          label: _showChart ? 'إخفاء الرسم' : 'إظهار الرسم',
          onTap: () => setState(() => _showChart = !_showChart),
          color: AppColors.secondary,
        ),
        const SizedBox(width: 8),
        if (_patientId != null || _doctorId != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: () => setState(() {
                _patientId = null;
                _patientName = null;
                _doctorId = null;
                _doctorName = null;
              }),
              icon: const Icon(Icons.clear_all_rounded, size: 15),
              label:
                  const Text('إزالة الفلاتر', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
          ),
        _ExportButton(
            icon: Icons.picture_as_pdf_rounded,
            label: 'تصدير PDF',
            onPressed: () => _exportPdf(context)),
      ]),
    );
  }

  // ── Content ─────────────────────────────────────────────────

  Widget _buildContent(DetailedStatement stmt) {
    return Column(children: [
      _buildSummaryRow(stmt),
      const SizedBox(height: 10),
      if (_showChart && stmt.entries.isNotEmpty) ...[
        _DailyBarChart(dailyData: stmt.dailyAggregates, fmt: widget.fmt),
        const SizedBox(height: 10),
      ],
      _buildTimelineHeaders(),
      const SizedBox(height: 6),
      Expanded(
          child: stmt.entries.isEmpty ? _buildEmpty() : _buildTimeline(stmt)),
    ]);
  }

  Widget _buildSummaryRow(DetailedStatement stmt) {
    final cntFmt = intl.NumberFormat('#,##0', 'en');
    return Row(children: [
      _SummaryCard(
          label: 'إجمالي الإيرادات',
          amount: stmt.totalRevenue,
          fmt: widget.fmt,
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF16A34A),
          bg: const Color(0xFFF0FDF4)),
      const SizedBox(width: 10),
      _SummaryCard(
          label: 'إجمالي المصروفات',
          amount: stmt.totalExpenses,
          fmt: widget.fmt,
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          bg: AppColors.errorSurface),
      const SizedBox(width: 10),
      _SummaryCard(
          label: 'صافي الربح',
          amount: stmt.netBalance,
          fmt: widget.fmt,
          icon: stmt.netBalance >= 0
              ? Icons.account_balance_wallet_rounded
              : Icons.money_off_rounded,
          color: stmt.netBalance >= 0 ? AppColors.primary : AppColors.error,
          bg: stmt.netBalance >= 0
              ? AppColors.primarySurface
              : AppColors.errorSurface,
          isNet: true),
      const SizedBox(width: 10),
      _SummaryCard(
          label: 'عدد الحركات',
          amount: stmt.totalTransactions.toDouble(),
          fmt: cntFmt,
          icon: Icons.receipt_long_rounded,
          color: AppColors.secondary,
          bg: AppColors.secondarySurface,
          isCount: true),
    ]);
  }

  Widget _buildTimelineHeaders() {
    return Row(children: [
      Expanded(
        flex: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: AppColors.errorSurface,
              borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.trending_down_rounded, size: 13, color: AppColors.error),
            SizedBox(width: 6),
            Text('المصروفات',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error)),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      const SizedBox(
        width: 100,
        child: Center(
          child: Text('خط الزمن',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(
        flex: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('الإيرادات',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A))),
            SizedBox(width: 6),
            Icon(Icons.trending_up_rounded, size: 13, color: Color(0xFF16A34A)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTimeline(DetailedStatement stmt) {
    final grouped = <String, List<StatementEntry>>{};
    for (final e in stmt.entries) {
      (grouped[e.date] ??= []).add(e);
    }
    final dates = grouped.keys.toList()..sort();
    final flat = <dynamic>[];
    for (final d in dates) {
      flat.add(d);
      flat.addAll(grouped[d]!);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final item = flat[i];
        if (item is String) {
          final de = grouped[item]!;
          final dr = de
              .where((e) => e.type == StatementEntryType.revenue)
              .fold(0.0, (s, e) => s + e.amount);
          final dx = de
              .where((e) => e.type == StatementEntryType.expense)
              .fold(0.0, (s, e) => s + e.amount);
          return _DayGroupHeader(
                  date: item, dayRevenue: dr, dayExpenses: dx, fmt: widget.fmt)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: -0.08, end: 0, duration: 350.ms);
        }
        final entry = item as StatementEntry;
        final isLast = i == flat.length - 1 || flat[i + 1] is String;
        return _TimelineRow(
          entry: entry,
          fmt: widget.fmt,
          isLast: isLast,
          delay: Duration(milliseconds: (i % 8) * 40),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('لا توجد حركات مالية في هذه الفترة',
            style: TextStyle(color: AppColors.textHint, fontSize: 15)),
        if (_patientId != null || _doctorId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('جرب إزالة الفلاتر المحددة',
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ),
      ]),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      showSnack(context, 'جاري إنشاء تقرير PDF...');
      final stmt = await ref.read(detailedStatementProvider(_filter).future);
      final pdf = ref.read(pdfExportServiceProvider);
      final bytes = await pdf.generateDetailedStatementPdf(stmt);
      await pdf.printOrShare(bytes,
          name: 'كشف_الحساب_${_filter.fromDate.replaceAll('-', '_')}');
    } catch (e) {
      if (context.mounted)
        showSnack(context, 'خطأ أثناء التصدير: $e', error: true);
    }
  }
}

// ─── Day Group Header ─────────────────────────────────────────────────────────

class _DayGroupHeader extends StatelessWidget {
  final String date;
  final double dayRevenue;
  final double dayExpenses;
  final intl.NumberFormat fmt;
  const _DayGroupHeader(
      {required this.date,
      required this.dayRevenue,
      required this.dayExpenses,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final dayName =
        parsed != null ? intl.DateFormat('EEEE', 'ar').format(parsed) : '';
    final displayDate = parsed != null
        ? intl.DateFormat('d MMMM yyyy', 'ar').format(parsed)
        : date;

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey[200])),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_rounded,
                size: 12, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('$dayName  $displayDate',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            if (dayRevenue > 0 || dayExpenses > 0) ...[
              const SizedBox(width: 10),
              Container(
                  width: 1,
                  height: 12,
                  color: AppColors.primary.withOpacity(0.25)),
              const SizedBox(width: 8),
              if (dayRevenue > 0)
                Text('+${fmt.format(dayRevenue)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              if (dayRevenue > 0 && dayExpenses > 0) const SizedBox(width: 6),
              if (dayExpenses > 0)
                Text('-${fmt.format(dayExpenses)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
            ],
          ]),
        ),
        Expanded(child: Divider(color: Colors.grey[200])),
      ]),
    );
  }
}

// ─── Timeline Row ─────────────────────────────────────────────────────────────

class _TimelineRow extends StatefulWidget {
  final StatementEntry entry;
  final intl.NumberFormat fmt;
  final bool isLast;
  final Duration delay;
  const _TimelineRow(
      {required this.entry,
      required this.fmt,
      required this.isLast,
      required this.delay});

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  bool _expanded = false;
  bool get _isRev => widget.entry.type == StatementEntryType.revenue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── LEFT (expense) ────────────────────────────────────
          Expanded(
            flex: 4,
            child: _isRev
                ? const SizedBox()
                : _buildExpCard()
                    .animate(delay: widget.delay)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.12, end: 0, duration: 300.ms),
          ),

          // ── CENTER SPINE ──────────────────────────────────────
          SizedBox(
            width: 100,
            child: Column(children: [
              Container(width: 2, height: 14, color: Colors.grey[200]),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRev ? const Color(0xFF16A34A) : AppColors.error,
                  boxShadow: [
                    BoxShadow(
                        color:
                            (_isRev ? const Color(0xFF16A34A) : AppColors.error)
                                .withOpacity(0.35),
                        blurRadius: 6,
                        spreadRadius: 1)
                  ],
                ),
                child: Center(
                  child: Icon(
                      _isRev
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 8,
                      color: Colors.white),
                ),
              ),
              // Running Balance Badge
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.entry.runningBalance >= 0
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: widget.entry.runningBalance >= 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                      width: 0.8),
                ),
                child: Text(
                  widget.fmt.format(widget.entry.runningBalance),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: widget.entry.runningBalance >= 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFDC2626),
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              if (!widget.isLast)
                Expanded(child: Container(width: 2, color: Colors.grey[200])),
            ]),
          ),

          // ── RIGHT (revenue) ───────────────────────────────────
          Expanded(
            flex: 4,
            child: !_isRev
                ? const SizedBox()
                : _buildRevCard()
                    .animate(delay: widget.delay)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.12, end: 0, duration: 300.ms),
          ),
        ]),
      ),
    );
  }

  // ── EXPENSE CARD ────────────────────────────────────────────

  Widget _buildExpCard() {
    final e = widget.entry;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(left: 4, right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _expanded
                  ? AppColors.error.withOpacity(0.4)
                  : const Color(0xFFFECACA),
              width: _expanded ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: AppColors.error.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove_circle_outline_rounded,
                      size: 11, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(e.expenseCategory ?? 'مصروف',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const Spacer(),
              Text(widget.fmt.format(e.amount),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                      fontFamily: 'monospace')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(e.description,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: _expanded ? null : 1,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, indent: 10, endIndent: 10),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                if (e.notes != null && e.notes!.isNotEmpty)
                  _InfoRow(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظات',
                      value: e.notes!),
                _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'التاريخ',
                    value: e.date),
                _InfoRow(
                    icon: Icons.tag_rounded,
                    label: 'رقم التسجيل',
                    value: '#${e.id}'),
              ]),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Row(children: [
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AppColors.textHint),
              const SizedBox(width: 2),
              Text(_expanded ? 'إخفاء' : 'تفاصيل',
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── REVENUE CARD ────────────────────────────────────────────

  Widget _buildRevCard() {
    final e = widget.entry;
    final methodIcon = switch (e.paymentMethod ?? 'cash') {
      'card' => Icons.credit_card_rounded,
      'transfer' => Icons.account_balance_rounded,
      _ => Icons.payments_rounded,
    };
    final methodAr = switch (e.paymentMethod ?? 'cash') {
      'cash' => 'نقدي',
      'card' => 'بطاقة',
      'transfer' => 'تحويل',
      _ => 'أخرى',
    };

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(left: 6, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _expanded
                  ? const Color(0xFF16A34A).withOpacity(0.4)
                  : const Color(0xFFBBF7D0),
              width: _expanded ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF16A34A).withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Text(widget.fmt.format(e.amount),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A),
                      fontFamily: 'monospace')),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(methodIcon, size: 11, color: const Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text(methodAr,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          // Patient
          if (e.patientName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(e.patientName!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 4),
                const Icon(Icons.person_rounded,
                    size: 14, color: AppColors.secondary),
              ]),
            ),
          // Doctor
          if (e.doctorName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(e.doctorName!,
                    style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(width: 4),
                const Icon(Icons.medical_services_rounded,
                    size: 12, color: AppColors.textHint),
              ]),
            ),
          // Invoice badge
          if (e.invoiceId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(4)),
                child: Text('فاتورة #${e.invoiceId}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          // ── Expanded Details ──────────────────────────────────
          if (_expanded) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, indent: 10, endIndent: 10),
            Padding(
              padding: const EdgeInsets.all(10),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (e.invoiceGross != null)
                  _InfoRowRtl(
                      icon: Icons.receipt_rounded,
                      label: 'إجمالي الفاتورة',
                      value: widget.fmt.format(e.invoiceGross!)),
                if ((e.invoiceDiscount ?? 0) > 0)
                  _InfoRowRtl(
                      icon: Icons.discount_rounded,
                      label: 'الخصم',
                      value: '- ${widget.fmt.format(e.invoiceDiscount!)}',
                      valueColor: AppColors.warning),
                if (e.invoiceNet != null)
                  _InfoRowRtl(
                      icon: Icons.calculate_rounded,
                      label: 'صافي الفاتورة',
                      value: widget.fmt.format(e.invoiceNet!),
                      isBold: true),
                if (e.invoiceStatus != null)
                  _InfoRowRtl(
                      icon: Icons.info_outline_rounded,
                      label: 'حالة الفاتورة',
                      value: _statusAr(e.invoiceStatus!),
                      valueColor: _statusColor(e.invoiceStatus!)),
                if (e.patientPhone != null)
                  _InfoRowRtl(
                      icon: Icons.phone_rounded,
                      label: 'هاتف المريض',
                      value: e.patientPhone!),
                if (e.doctorSpecialty != null)
                  _InfoRowRtl(
                      icon: Icons.workspace_premium_rounded,
                      label: 'التخصص',
                      value: e.doctorSpecialty!),
                if (e.visitDiagnosis != null && e.visitDiagnosis!.isNotEmpty)
                  _InfoRowRtl(
                      icon: Icons.healing_rounded,
                      label: 'التشخيص',
                      value: e.visitDiagnosis!),
                if (e.notes != null && e.notes!.isNotEmpty)
                  _InfoRowRtl(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظات',
                      value: e.notes!),

                // Invoice items table
                if (e.invoiceItems.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Row(children: [
                              Text('المجموع',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('خدمة / إجراء',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          const Divider(height: 1),
                          ...e.invoiceItems.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                child: Row(children: [
                                  Text(widget.fmt.format(item.total),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontFamily: 'monospace')),
                                  if (item.discount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                        '(-${widget.fmt.format(item.discount)})',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.warning)),
                                  ],
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: Text('×${item.quantity}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(item.description,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right),
                                  ),
                                ]),
                              )),
                        ]),
                  ),
                ],
              ]),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(_expanded ? 'إخفاء' : 'تفاصيل',
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textHint)),
              const SizedBox(width: 2),
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AppColors.textHint),
            ]),
          ),
        ]),
      ),
    );
  }

  String _statusAr(String s) => switch (s) {
        'paid' => 'مدفوعة بالكامل',
        'partial' => 'مدفوعة جزئياً',
        'unpaid' => 'غير مدفوعة',
        'cancelled' => 'ملغاة',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'paid' => AppColors.success,
        'partial' => AppColors.warning,
        'cancelled' => AppColors.textHint,
        _ => AppColors.error,
      };
}

// ─── Info Row Helpers ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        Flexible(
          child: Text(value,
              style: TextStyle(
                  fontSize: 11,
                  color: valueColor ?? AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _InfoRowRtl extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  const _InfoRowRtl(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(
          child: Text(value,
              style: TextStyle(
                  fontSize: 11,
                  color: valueColor ?? AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right),
        ),
        const SizedBox(width: 4),
        Text('$label ',
            style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        Icon(icon, size: 13, color: AppColors.textHint),
      ]),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final intl.NumberFormat fmt;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool isNet;
  final bool isCount;
  const _SummaryCard(
      {required this.label,
      required this.amount,
      required this.fmt,
      required this.icon,
      required this.color,
      required this.bg,
      this.isNet = false,
      this.isCount = false});

  @override
  Widget build(BuildContext context) {
    final display =
        isCount ? amount.toInt().toString() : fmt.format(amount.abs());
    final prefix = isNet && amount < 0 ? '−' : '';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text('$prefix$display',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─── Daily Bar Chart ──────────────────────────────────────────────────────────

class _DailyBarChart extends StatelessWidget {
  final Map<String, ({double revenue, double expense})> dailyData;
  final intl.NumberFormat fmt;
  const _DailyBarChart({required this.dailyData, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final dates = dailyData.keys.toList()..sort();
    final show = dates.length > 30 ? dates.sublist(dates.length - 30) : dates;
    final maxVal = show
        .expand((d) => [dailyData[d]!.revenue, dailyData[d]!.expense])
        .fold(0.0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text('الحركات اليومية',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
          const Spacer(),
          _LegendDot(color: const Color(0xFF16A34A), label: 'إيرادات'),
          const SizedBox(width: 12),
          _LegendDot(color: AppColors.error, label: 'مصروفات'),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: show.map((date) {
              final d = dailyData[date]!;
              final rH = d.revenue / maxVal * 80;
              final eH = d.expense / maxVal * 80;
              return Expanded(
                child:
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (d.revenue > 0)
                          _Bar(
                              h: rH,
                              color: const Color(0xFF16A34A),
                              tip: fmt.format(d.revenue)),
                        const SizedBox(width: 1),
                        if (d.expense > 0)
                          _Bar(
                              h: eH,
                              color: AppColors.error,
                              tip: fmt.format(d.expense)),
                      ]),
                  const SizedBox(height: 3),
                  Text(date.substring(5),
                      style: TextStyle(fontSize: 7, color: AppColors.textHint),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final double h;
  final Color color;
  final String tip;
  const _Bar({required this.h, required this.color, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: h.clamp(2.0, 200.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Container(
          width: 8,
          height: v,
          decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3))),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
    ]);
  }
}

// ─── Shared Accounting Widgets ────────────────────────────────────────────────

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
    final c = isExcel ? Colors.green[700]! : Colors.red[700]!;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: c.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
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

class _AmountCell extends StatelessWidget {
  final double amount;
  final intl.NumberFormat fmt;
  final bool isDebit;
  final bool isTotal;
  const _AmountCell(
      {required this.amount,
      required this.fmt,
      required this.isDebit,
      this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    if (amount == 0 && !isTotal)
      return const Text('—', style: TextStyle(color: Colors.grey));
    return Text(fmt.format(amount),
        style: TextStyle(
            color: isDebit ? AppColors.primary : AppColors.secondary,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            fontSize: isTotal ? 15 : 13,
            fontFamily: 'monospace'));
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
    final c = isProfit ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [c.withOpacity(0.8), c],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: c.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text('\$${fmt.format(amount.abs())}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        if (!isProfit)
          const Text('(خسارة)',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _ModernSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<dynamic> lines;
  final double total;
  final intl.NumberFormat fmt;
  final WidgetRef ref;
  final AccountingPeriod period;
  const _ModernSectionCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.lines,
      required this.total,
      required this.fmt,
      required this.ref,
      required this.period});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const Divider(height: 24),
        ...lines.map((l) => _FinancialRow(
            label: l.accountName,
            amount: l.amount,
            fmt: fmt,
            onTap: () => _showLedger(context, l.accountId))),
        const Divider(height: 32),
        _FinancialRow(
            label: 'الإجمالي',
            amount: total,
            fmt: fmt,
            isBold: true,
            textColor: color),
      ]),
    );
  }

  void _showLedger(BuildContext context, int accountId) async {
    final future = ref.read(ledgerRepositoryProvider).getGeneralLedger(
        accountId: accountId, fromDate: period.fromDate, toDate: period.toDate);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كشف حساب تفصيلي'),
        content: SizedBox(
          width: 800,
          height: 500,
          child: FutureBuilder<List<LedgerEntry>>(
            future: future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snap.hasError)
                return Center(child: Text('خطأ: ${snap.error}'));
              final entries = snap.data ?? [];
              return entries.isEmpty
                  ? const Center(child: Text('لا توجد حركات'))
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
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: isBold
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
          ),
          if (onTap != null)
            const Icon(Icons.ads_click, size: 22, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(fmt.format(amount),
              style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                  color: textColor ?? AppColors.textPrimary)),
        ]),
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _EqPart(label: 'إجمالي الأصول', amount: totalAssets, fmt: fmt),
        Icon(Icons.drag_handle_rounded,
            color: isBalanced ? Colors.green : Colors.red),
        _EqPart(
            label: 'الالتزامات + الملكية', amount: totalLiabEquity, fmt: fmt),
        Icon(isBalanced ? Icons.check_circle : Icons.warning,
            color: isBalanced ? Colors.green : Colors.red),
      ]),
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
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      Text(fmt.format(amount),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _StatementNavButton — زر كشف الحساب التفاعلي
//  • MouseRegion  → cursor يتغير لـ click
//  • AnimatedContainer → scale + shadow + glow عند hover
//  • نبضة خفيفة عند الضغط
// ═══════════════════════════════════════════════════════════════════════════════

class _StatementNavButton extends StatefulWidget {
  final VoidCallback onTap;
  const _StatementNavButton({required this.onTap});

  @override
  State<_StatementNavButton> createState() => _StatementNavButtonState();
}

class _StatementNavButtonState extends State<_StatementNavButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  // أيقونة الحركة المتحركة
  late final AnimationController _iconAnim;
  late final Animation<double> _iconSlide;

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _iconSlide = Tween<double>(begin: 0, end: 4).animate(CurvedAnimation(
      parent: _iconAnim,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _iconAnim.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    setState(() => _hovered = true);
    _iconAnim.repeat(reverse: true);
  }

  void _onHoverExit() {
    setState(() => _hovered = false);
    _iconAnim.stop();
    _iconAnim.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    // الألوان الأساسية
    const Color c1 = AppColors.primary;
    const Color c2 = AppColors.secondary;

    final double elevation = _hovered ? 14 : 4;
    final double scale = _pressed ? 0.96 : (_hovered ? 1.04 : 1.0);
    final double glowOpacity = _hovered ? 0.45 : 0.2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -2.0 : 0.0)
            ..scale(scale),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [c2, c1] // ينعكس الـ gradient عند hover
                  : [c1, c2],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              // ظل رئيسي
              BoxShadow(
                color: c1.withOpacity(glowOpacity),
                blurRadius: elevation,
                spreadRadius: _hovered ? 1 : 0,
                offset: Offset(0, _hovered ? 5 : 3),
              ),
              // هالة ضوئية عند hover
              if (_hovered)
                BoxShadow(
                  color: c2.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // أيقونة تتحرك يميناً ويساراً عند hover
            AnimatedBuilder(
              animation: _iconSlide,
              builder: (_, __) => Transform.translate(
                offset: Offset(-_iconSlide.value, 0),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 17, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),

            // النص الرئيسي
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: _hovered ? 14 : 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                letterSpacing: _hovered ? 0.4 : 0,
              ),
              child: const Text('كشف الحساب'),
            ),

            const SizedBox(width: 6),

            // سهم يتحرك يساراً عند hover
            AnimatedBuilder(
              animation: _iconSlide,
              builder: (_, __) => Transform.translate(
                offset: Offset(_iconSlide.value, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hovered ? 1.0 : 0.65,
                  child: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
