// lib/features/accounting/presentation/screens/statement_screen.dart
//
// شاشة كشف الحساب المستقلة
// ─ التايم لاين هو العنصر الأساسي والأكبر
// ─ التواريخ بالتقويم الشامي (نيسان، آذار …)
// ─ الترتيب من الأحدث إلى الأقدم
// ─ باقي العناصر مضغوطة لصالح التايم لاين

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:go_router/go_router.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import 'accounting_screen.dart'
    show
        AccountingPeriod,
        accountingPeriodProvider,
        detailedStatementProvider,
        patientsFilterProvider,
        doctorsFilterProvider;
import '../../data/repositories/ledger_repository.dart'
    show
        DetailedStatement,
        StatementEntry,
        StatementEntryType,
        StatementFilter,
        FilterOption;

// ═══════════════════════════════════════════════════════════════════════════════
//  StatementScreen — الشاشة المستقلة لكشف الحساب
// ═══════════════════════════════════════════════════════════════════════════════

class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key});

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  final _fmt = intl.NumberFormat('#,##0.00', 'en');

  int? _patientId;
  String? _patientName;
  int? _doctorId;
  String? _doctorName;
  bool _showChart = false; // مطوي افتراضياً لإعطاء التايم لاين مساحة أكبر

  StatementFilter get _filter {
    final period = ref.read(accountingPeriodProvider);
    return StatementFilter(
      fromDate: period.fromDate,
      toDate: period.toDate,
      patientId: _patientId,
      patientName: _patientName,
      doctorId: _doctorId,
      doctorName: _doctorName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(accountingPeriodProvider);
    final async = ref.watch(detailedStatementProvider(_filter));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(children: [
        // ── شريط العنوان المدمج ──────────────────────────────────
        _buildCompactHeader(context, ref, period),

        // ── شريط الفلاتر ────────────────────────────────────────
        _buildFilterBar(context),

        const SizedBox(height: 8),

        // ── المحتوى الرئيسي ─────────────────────────────────────
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('خطأ في تحميل البيانات',
                    style: TextStyle(color: AppColors.textHint)),
                const SizedBox(height: 6),
                Text(e.toString(),
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center),
              ]),
            ),
            data: (stmt) => _buildMainContent(stmt),
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  Header
  // ──────────────────────────────────────────────────────────────

  Widget _buildCompactHeader(
      BuildContext context, WidgetRef ref, AccountingPeriod period) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // زر الرجوع
        InkWell(
          onTap: () => context.go('/accounting'),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),

        // العنوان
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.receipt_long_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('كشف الحساب',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 18)),
          ]),
          Text('الحركات المالية من الأحدث إلى الأقدم',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
        ]),

        const Spacer(),

        // منتقي الفترة المدمج
        _CompactPeriodPicker(
          period: period,
          onChanged: (p) =>
              ref.read(accountingPeriodProvider.notifier).state = p,
        ),

        const SizedBox(width: 10),

        // زر التصدير
        _HeaderExportButton(
          onPressed: () => _exportPdf(context),
        ),

        const SizedBox(width: 6),

        // زر التحديث
        InkWell(
          onTap: () {
            ref.invalidate(detailedStatementProvider);
            ref.invalidate(patientsFilterProvider);
            ref.invalidate(doctorsFilterProvider);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(Icons.refresh_rounded, size: 16, color: Colors.grey[600]),
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  Filter Bar
  // ──────────────────────────────────────────────────────────────

  Widget _buildFilterBar(BuildContext context) {
    final patients = ref.watch(patientsFilterProvider).asData?.value ?? [];
    final doctors = ref.watch(doctorsFilterProvider).asData?.value ?? [];
    final hasFilter = _patientId != null || _doctorId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: Colors.white,
      child: Row(children: [
        // فلتر المرضى
        const Icon(Icons.person_search_rounded,
            size: 15, color: AppColors.secondary),
        const SizedBox(width: 5),
        SizedBox(
          width: 160,
          height: 34,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _patientId,
              hint: const Text('كل المرضى',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 12,
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
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ),
          ),
        ),

        Container(
            width: 1,
            height: 22,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 10)),

        // فلتر الأطباء
        const Icon(Icons.medical_services_rounded,
            size: 15, color: AppColors.primary),
        const SizedBox(width: 5),
        SizedBox(
          width: 160,
          height: 34,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _doctorId,
              hint: const Text('كل الأطباء',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 12,
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
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ),
          ),
        ),

        const Spacer(),

        // زر إخفاء/إظهار الرسم البياني
        _ChipButton(
          icon: _showChart ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
          label: _showChart ? 'إخفاء الرسم' : 'الرسم البياني',
          active: _showChart,
          onTap: () => setState(() => _showChart = !_showChart),
        ),

        // زر إزالة الفلاتر
        if (hasFilter) ...[
          const SizedBox(width: 8),
          _ChipButton(
            icon: Icons.filter_alt_off_rounded,
            label: 'إزالة الفلاتر',
            active: true,
            activeColor: AppColors.error,
            onTap: () => setState(() {
              _patientId = null;
              _patientName = null;
              _doctorId = null;
              _doctorName = null;
            }),
          ),
        ],
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  المحتوى الرئيسي
  // ──────────────────────────────────────────────────────────────

  Widget _buildMainContent(DetailedStatement stmt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        const SizedBox(height: 10),

        // ── ملخص مضغوط (شريط أفقي صغير) ──────────────────────
        _CompactSummaryBar(stmt: stmt, fmt: _fmt),

        const SizedBox(height: 8),

        // ── الرسم البياني (اختياري) ────────────────────────────
        if (_showChart && stmt.entries.isNotEmpty) ...[
          _CompactDailyChart(dailyData: stmt.dailyAggregates, fmt: _fmt),
          const SizedBox(height: 8),
        ],

        // ── رأس التايم لاين ───────────────────────────────────
        _TimelineHeaderRow(),

        const SizedBox(height: 6),

        // ── التايم لاين (العنصر الأساسي) ──────────────────────
        Expanded(
          child: stmt.entries.isEmpty ? _buildEmpty() : _buildTimeline(stmt),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  التايم لاين — من الأحدث إلى الأقدم
  // ──────────────────────────────────────────────────────────────

  Widget _buildTimeline(DetailedStatement stmt) {
    final grouped = <String, List<StatementEntry>>{};
    for (final e in stmt.entries) {
      (grouped[e.date] ??= []).add(e);
    }

    // ترتيب تنازلي — الأحدث أولاً
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final flat = <dynamic>[];
    for (final d in dates) {
      flat.add(d);
      flat.addAll(grouped[d]!);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 40),
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
          return _StmtDayHeader(
            date: item,
            dayRevenue: dr,
            dayExpenses: dx,
            fmt: _fmt,
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: -0.06, duration: 350.ms);
        }

        final entry = item as StatementEntry;
        final isLast = i == flat.length - 1 || flat[i + 1] is String;

        return _StmtTimelineRow(
          entry: entry,
          fmt: _fmt,
          isLast: isLast,
          delay: Duration(milliseconds: (i % 8) * 35),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('لا توجد حركات مالية في هذه الفترة',
            style: TextStyle(
                color: AppColors.textHint,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        if (_patientId != null || _doctorId != null) ...[
          const SizedBox(height: 8),
          Text('جرّب إزالة الفلاتر المحددة',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ],
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  تصدير PDF
  // ──────────────────────────────────────────────────────────────

  Future<void> _exportPdf(BuildContext context) async {
    try {
      showSnack(context, 'جاري إنشاء تقرير PDF...');
      final stmt = await ref.read(detailedStatementProvider(_filter).future);
      final pdf = ref.read(pdfExportServiceProvider);
      final bytes = await pdf.generateDetailedStatementPdf(stmt);
      await pdf.printOrShare(bytes,
          name: 'كشف_الحساب_${_filter.fromDate.replaceAll('-', '_')}');
    } catch (e) {
      if (context.mounted) {
        showSnack(context, 'خطأ أثناء التصدير: $e', error: true);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _CompactPeriodPicker
// ═══════════════════════════════════════════════════════════════════════════════

class _CompactPeriodPicker extends StatelessWidget {
  final AccountingPeriod period;
  final Function(AccountingPeriod) onChanged;
  const _CompactPeriodPicker({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_month_rounded,
            size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        _SmallDateField(
            date: period.fromDate,
            onTap: (v) => onChanged(
                AccountingPeriod(fromDate: v, toDate: period.toDate))),
        Text('  ←  ',
            style: TextStyle(
                fontSize: 11, color: AppColors.primary.withOpacity(0.5))),
        _SmallDateField(
            date: period.toDate,
            onTap: (v) => onChanged(
                AccountingPeriod(fromDate: period.fromDate, toDate: v))),
      ]),
    );
  }
}

class _SmallDateField extends StatelessWidget {
  final String date;
  final Function(String) onTap;
  const _SmallDateField({required this.date, required this.onTap});

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
      child: Text(date,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _HeaderExportButton
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderExportButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _HeaderExportButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.picture_as_pdf_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 5),
          const Text('PDF',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _ChipButton
// ═══════════════════════════════════════════════════════════════════════════════

class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _ChipButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap,
      this.activeColor});

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.08) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color.withOpacity(0.25) : Colors.grey[200]!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? color : AppColors.textHint),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: active ? color : AppColors.textHint,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _CompactSummaryBar  — شريط الملخص المضغوط
// ═══════════════════════════════════════════════════════════════════════════════

class _CompactSummaryBar extends StatelessWidget {
  final DetailedStatement stmt;
  final intl.NumberFormat fmt;
  const _CompactSummaryBar({required this.stmt, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isProfit = stmt.netBalance >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // الإيرادات
        _MiniStat(
          label: 'الإيرادات',
          value: fmt.format(stmt.totalRevenue),
          color: const Color(0xFF16A34A),
          icon: Icons.trending_up_rounded,
        ),
        _Divider(),
        // المصروفات
        _MiniStat(
          label: 'المصروفات',
          value: fmt.format(stmt.totalExpenses),
          color: AppColors.error,
          icon: Icons.trending_down_rounded,
        ),
        _Divider(),
        // الصافي
        _MiniStat(
          label: isProfit ? 'صافي الربح' : 'صافي الخسارة',
          value: '${isProfit ? '+' : '−'}${fmt.format(stmt.netBalance.abs())}',
          color: isProfit ? AppColors.primary : AppColors.error,
          icon: isProfit
              ? Icons.account_balance_wallet_rounded
              : Icons.money_off_rounded,
          highlighted: true,
        ),
        _Divider(),
        // عدد الحركات
        _MiniStat(
          label: 'الحركات',
          value: stmt.totalTransactions.toString(),
          color: AppColors.secondary,
          icon: Icons.receipt_long_rounded,
          isCount: true,
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool highlighted;
  final bool isCount;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.highlighted = false,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: highlighted
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 6),
        decoration: highlighted
            ? BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: isCount ? 16 : 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'monospace')),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1,
        height: 32,
        color: Colors.grey[200],
        margin: const EdgeInsets.symmetric(horizontal: 4));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _CompactDailyChart
// ═══════════════════════════════════════════════════════════════════════════════

class _CompactDailyChart extends StatelessWidget {
  final Map<String, ({double revenue, double expense})> dailyData;
  final intl.NumberFormat fmt;
  const _CompactDailyChart({required this.dailyData, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final dates = dailyData.keys.toList()..sort();
    final show = dates.length > 40 ? dates.sublist(dates.length - 40) : dates;
    final maxVal = show
        .expand((d) => [dailyData[d]!.revenue, dailyData[d]!.expense])
        .fold(0.0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          const Text('الحركات اليومية',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
          const Spacer(),
          _LegendDot2(color: const Color(0xFF16A34A), label: 'إيرادات'),
          const SizedBox(width: 10),
          _LegendDot2(color: AppColors.error, label: 'مصروفات'),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: show.map((date) {
              final d = dailyData[date]!;
              final rH = d.revenue / maxVal * 65;
              final eH = d.expense / maxVal * 65;
              return Expanded(
                child:
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (d.revenue > 0)
                          _Bar2(
                              h: rH,
                              color: const Color(0xFF16A34A),
                              tip: fmt.format(d.revenue)),
                        const SizedBox(width: 1),
                        if (d.expense > 0)
                          _Bar2(
                              h: eH,
                              color: AppColors.error,
                              tip: fmt.format(d.expense)),
                      ]),
                  const SizedBox(height: 2),
                  Text(date.substring(5),
                      style: const TextStyle(
                          fontSize: 6, color: AppColors.textHint),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _LegendDot2 extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot2({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
    ]);
  }
}

class _Bar2 extends StatelessWidget {
  final double h;
  final Color color;
  final String tip;
  const _Bar2({required this.h, required this.color, required this.tip});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: h.clamp(2.0, 200.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Container(
          width: 7,
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

// ═══════════════════════════════════════════════════════════════════════════════
//  رأس التايم لاين
// ═══════════════════════════════════════════════════════════════════════════════

class _TimelineHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        flex: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.errorSurface,
              borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.trending_down_rounded, size: 12, color: AppColors.error),
            SizedBox(width: 5),
            Text('المصروفات',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error)),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      const SizedBox(
        width: 96,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.swap_horiz_rounded, size: 13, color: AppColors.textHint),
            Text('خط الزمن',
                style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(
        flex: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('الإيرادات',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A))),
            SizedBox(width: 5),
            Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF16A34A)),
          ]),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _StmtDayHeader — رأس اليوم بالتقويم الشامي
// ═══════════════════════════════════════════════════════════════════════════════

class _StmtDayHeader extends StatelessWidget {
  final String date;
  final double dayRevenue;
  final double dayExpenses;
  final intl.NumberFormat fmt;
  const _StmtDayHeader(
      {required this.date,
      required this.dayRevenue,
      required this.dayExpenses,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);

    // اسم اليوم بالعربية
    final dayName =
        parsed != null ? intl.DateFormat('EEEE', 'ar').format(parsed) : '';

    // التاريخ بالأشهر الشامية (نيسان، آذار …)
    final displayDate = parsed != null
        ? ClinicDateUtils.formatArabicMonth(parsed, 'd MMMM yyyy')
        : date;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey[200])),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.08),
                AppColors.primary.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_rounded,
                size: 11, color: AppColors.primary),
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
                  height: 10,
                  color: AppColors.primary.withOpacity(0.2)),
              const SizedBox(width: 8),
              if (dayRevenue > 0)
                Text('+${fmt.format(dayRevenue)}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              if (dayRevenue > 0 && dayExpenses > 0) const SizedBox(width: 5),
              if (dayExpenses > 0)
                Text('-${fmt.format(dayExpenses)}',
                    style: const TextStyle(
                        fontSize: 10,
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

// ═══════════════════════════════════════════════════════════════════════════════
//  _StmtTimelineRow — صف التايم لاين
// ═══════════════════════════════════════════════════════════════════════════════

class _StmtTimelineRow extends StatefulWidget {
  final StatementEntry entry;
  final intl.NumberFormat fmt;
  final bool isLast;
  final Duration delay;
  const _StmtTimelineRow(
      {required this.entry,
      required this.fmt,
      required this.isLast,
      required this.delay});

  @override
  State<_StmtTimelineRow> createState() => _StmtTimelineRowState();
}

class _StmtTimelineRowState extends State<_StmtTimelineRow> {
  bool _expanded = false;
  bool get _isRev => widget.entry.type == StatementEntryType.revenue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── يسار: المصروف ──────────────────────────────────────
          Expanded(
            flex: 4,
            child: _isRev
                ? const SizedBox()
                : _buildExpCard()
                    .animate(delay: widget.delay)
                    .fadeIn(duration: 280.ms)
                    .slideX(begin: -0.1, end: 0, duration: 280.ms),
          ),

          // ── العمود الوسطي (الخط والنقطة والرصيد) ───────────────
          SizedBox(
            width: 96,
            child: Column(children: [
              Container(width: 2, height: 12, color: Colors.grey[200]),
              // النقطة الملونة
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
              // الرصيد الجاري
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
                      fontSize: 8,
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

          // ── يمين: الإيراد ───────────────────────────────────────
          Expanded(
            flex: 4,
            child: !_isRev
                ? const SizedBox()
                : _buildRevCard()
                    .animate(delay: widget.delay)
                    .fadeIn(duration: 280.ms)
                    .slideX(begin: 0.1, end: 0, duration: 280.ms),
          ),
        ]),
      ),
    );
  }

  // ── بطاقة المصروف ───────────────────────────────────────────

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
                color: AppColors.error.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(9),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.remove_circle_outline_rounded,
                      size: 10, color: AppColors.error),
                  const SizedBox(width: 3),
                  Text(e.expenseCategory ?? 'مصروف',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const Spacer(),
              Text(widget.fmt.format(e.amount),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                      fontFamily: 'monospace')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 0, 9, 4),
            child: Text(e.description,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                maxLines: _expanded ? null : 1,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 9, endIndent: 9),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(children: [
                if (e.notes != null && e.notes!.isNotEmpty)
                  _IRow(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظات',
                      value: e.notes!),
                _IRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'التاريخ',
                    value: _formatLevantine(e.date)),
                _IRow(
                    icon: Icons.tag_rounded,
                    label: 'رقم التسجيل',
                    value: '#${e.id}'),
              ]),
            ),
          ],
          _ExpandToggle(expanded: _expanded, rtl: false),
        ]),
      ),
    );
  }

  // ── بطاقة الإيراد ───────────────────────────────────────────

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
                color: const Color(0xFF16A34A).withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Padding(
            padding: const EdgeInsets.all(9),
            child: Row(children: [
              Text(widget.fmt.format(e.amount),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF16A34A),
                      fontFamily: 'monospace')),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(methodIcon, size: 10, color: const Color(0xFF16A34A)),
                  const SizedBox(width: 3),
                  Text(methodAr,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          if (e.patientName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 0, 9, 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(e.patientName!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 3),
                const Icon(Icons.person_rounded,
                    size: 12, color: AppColors.secondary),
              ]),
            ),
          if (e.doctorName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 0, 9, 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(e.doctorName!,
                    style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                const SizedBox(width: 3),
                const Icon(Icons.medical_services_rounded,
                    size: 11, color: AppColors.textHint),
              ]),
            ),
          if (e.invoiceId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 0, 9, 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(4)),
                child: Text('فاتورة #${e.invoiceId}',
                    style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 9, endIndent: 9),
            Padding(
              padding: const EdgeInsets.all(9),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _IRowRtl(
                    icon: Icons.calendar_today_rounded,
                    label: 'التاريخ',
                    value: _formatLevantine(e.date)),
                if (e.invoiceGross != null)
                  _IRowRtl(
                      icon: Icons.receipt_rounded,
                      label: 'إجمالي الفاتورة',
                      value: widget.fmt.format(e.invoiceGross!)),
                if ((e.invoiceDiscount ?? 0) > 0)
                  _IRowRtl(
                      icon: Icons.discount_rounded,
                      label: 'الخصم',
                      value: '- ${widget.fmt.format(e.invoiceDiscount!)}',
                      valueColor: AppColors.warning),
                if (e.invoiceNet != null)
                  _IRowRtl(
                      icon: Icons.calculate_rounded,
                      label: 'صافي الفاتورة',
                      value: widget.fmt.format(e.invoiceNet!),
                      isBold: true),
                if (e.invoiceStatus != null)
                  _IRowRtl(
                      icon: Icons.info_outline_rounded,
                      label: 'حالة الفاتورة',
                      value: _statusAr(e.invoiceStatus!),
                      valueColor: _statusColor(e.invoiceStatus!)),
                if (e.patientPhone != null)
                  _IRowRtl(
                      icon: Icons.phone_rounded,
                      label: 'هاتف المريض',
                      value: e.patientPhone!),
                if (e.notes != null && e.notes!.isNotEmpty)
                  _IRowRtl(
                      icon: Icons.notes_rounded,
                      label: 'ملاحظات',
                      value: e.notes!),
                if (e.invoiceItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                                horizontal: 9, vertical: 5),
                            child: Row(children: [
                              Text('المجموع',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('خدمة / إجراء',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          const Divider(height: 1),
                          ...e.invoiceItems.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                child: Row(children: [
                                  Text(widget.fmt.format(item.total),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontFamily: 'monospace')),
                                  if (item.discount > 0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                        '(-${widget.fmt.format(item.discount)})',
                                        style: const TextStyle(
                                            fontSize: 8,
                                            color: AppColors.warning)),
                                  ],
                                  const SizedBox(width: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(3)),
                                    child: Text('×${item.quantity}',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(item.description,
                                        style: const TextStyle(
                                            fontSize: 10,
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
          _ExpandToggle(expanded: _expanded, rtl: true),
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

  /// تنسيق التاريخ بالتقويم الشامي
  String _formatLevantine(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return ClinicDateUtils.formatArabicMonth(parsed, 'd MMMM yyyy');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  مساعدات UI
// ═══════════════════════════════════════════════════════════════════════════════

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final bool rtl;
  const _ExpandToggle({required this.expanded, required this.rtl});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: rtl ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!rtl)
          Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: AppColors.textHint),
        if (!rtl) const SizedBox(width: 2),
        Text(expanded ? 'إخفاء' : 'تفاصيل',
            style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
        if (rtl) const SizedBox(width: 2),
        if (rtl)
          Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: AppColors.textHint),
      ],
    );
    return Padding(padding: const EdgeInsets.fromLTRB(9, 2, 9, 5), child: row);
  }
}

class _IRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  const _IRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 11, color: AppColors.textHint),
        const SizedBox(width: 5),
        Text('$label: ',
            style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        Flexible(
          child: Text(value,
              style: TextStyle(
                  fontSize: 10,
                  color: valueColor ?? AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _IRowRtl extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  const _IRowRtl(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(
          child: Text(value,
              style: TextStyle(
                  fontSize: 10,
                  color: valueColor ?? AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right),
        ),
        const SizedBox(width: 4),
        Text('$label ',
            style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        Icon(icon, size: 11, color: AppColors.textHint),
      ]),
    );
  }
}
