// lib/features/cash_box/presentation/screens/cash_box_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../../inventory/domain/entities/inventory.dart';

class CashBoxScreen extends ConsumerStatefulWidget {
  const CashBoxScreen({super.key});

  @override
  ConsumerState<CashBoxScreen> createState() => _CashBoxScreenState();
}

class _CashBoxScreenState extends ConsumerState<CashBoxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _fmt = NumberFormat('#,##0.00', 'ar');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          color: AppColors.surfaceCard,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.today_outlined, size: 18), text: 'اليوم'),
              Tab(icon: Icon(Icons.history_outlined, size: 18), text: 'السجل'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TodayTab(fmt: _fmt),
              _HistoryTab(fmt: _fmt),
            ],
          ),
        ),
      ]);
}

// ═══════════════════════════════════════════════════════════════
// TODAY TAB
// ═══════════════════════════════════════════════════════════════

class _TodayTab extends ConsumerWidget {
  final NumberFormat fmt;
  const _TodayTab({required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashBoxAsync = ref.watch(cashBoxTodayProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: cashBoxAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(cashBoxTodayProvider)),
            data: (box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Date + Status ────────────────────────────
                _DayHeader(box: box, fmt: fmt),
                const SizedBox(height: AppSpacing.lg),

                // ── Stat cards ────────────────────────────────
                _StatsGrid(box: box, fmt: fmt),
                const SizedBox(height: AppSpacing.lg),

                // ── Closing balance card ──────────────────────
                _ClosingCard(box: box, fmt: fmt),
                const SizedBox(height: AppSpacing.xl),

                // ── Actions ───────────────────────────────────
                if (!box.isClosed)
                  _CloseBoxButton(box: box, fmt: fmt, ref: ref)
                else
                  _ClosedBanner(box: box, fmt: fmt),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final CashBox box;
  final NumberFormat fmt;
  const _DayHeader({required this.box, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(box.boxDate);
    final day = dt != null
        ? DateFormat('EEEE، d MMMM yyyy', 'ar').format(dt)
        : box.boxDate;

    return AppCard(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(day, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('الرصيد الافتتاحي: ${fmt.format(box.openingBalance)} USD',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
        StatusChip(
          label: box.isClosed ? 'مغلقة' : 'مفتوحة',
          color: box.isClosed ? AppColors.textHint : AppColors.success,
        ),
      ]),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final CashBox box;
  final NumberFormat fmt;
  const _StatsGrid({required this.box, required this.fmt});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          StatCard(
            label: 'الرصيد الافتتاحي',
            value: '${fmt.format(box.openingBalance)} USD',
            icon: Icons.start_outlined,
            color: AppColors.primary,
          ),
          StatCard(
            label: 'إجمالي الإيرادات',
            value: '${fmt.format(box.totalIncome)} USD',
            icon: Icons.trending_up,
            color: AppColors.success,
          ),
          StatCard(
            label: 'إجمالي المصروفات',
            value: '${fmt.format(box.totalExpenses)} USD',
            icon: Icons.trending_down,
            color: AppColors.error,
          ),
        ],
      );
}

class _ClosingCard extends StatelessWidget {
  final CashBox box;
  final NumberFormat fmt;
  const _ClosingCard({required this.box, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final closing = box.calculatedClosingBalance;
    return AppCard(
      color: closing >= 0 ? AppColors.secondarySurface : AppColors.errorSurface,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الرصيد الختامي المحسوب',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          Text('${fmt.format(closing)} USD',
              style: TextStyle(
                  color: closing >= 0 ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // Visual progress
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: box.totalIncome > 0
                ? (box.totalExpenses / box.totalIncome).clamp(0.0, 1.0)
                : 0.0,
            backgroundColor: AppColors.success.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.error),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('الإيرادات: ${fmt.format(box.totalIncome)} USD',
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text('المصروفات: ${fmt.format(box.totalExpenses)} USD',
              style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _CloseBoxButton extends StatelessWidget {
  final CashBox box;
  final NumberFormat fmt;
  final WidgetRef ref;
  const _CloseBoxButton(
      {required this.box, required this.fmt, required this.ref});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: () => _confirmClose(context),
        icon: const Icon(Icons.lock_outline),
        label: Text(
            'إغلاق الصندوق بمبلغ ${fmt.format(box.calculatedClosingBalance)} USD'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      );

  Future<void> _confirmClose(BuildContext ctx) async {
    final ok = await ConfirmDialog.show(ctx,
        title: 'إغلاق الصندوق',
        message: 'سيتم إغلاق خزينة اليوم بالرصيد الختامي '
            '${fmt.format(box.calculatedClosingBalance)} USD. هل تريد المتابعة؟',
        confirmLabel: 'إغلاق');
    if (ok && ctx.mounted) {
      try {
        await ref.read(cashBoxServiceProvider).closeToday();
        ref.invalidate(cashBoxTodayProvider);
        if (ctx.mounted) showSnack(ctx, 'تم إغلاق الصندوق');
      } catch (e) {
        if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
      }
    }
  }
}

class _ClosedBanner extends StatelessWidget {
  final CashBox box;
  final NumberFormat fmt;
  const _ClosedBanner({required this.box, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.lock, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الصندوق مغلقة',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            Text(
              'الرصيد الختامي: ${fmt.format(box.closingBalance ?? box.calculatedClosingBalance)} USD',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ]),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
// HISTORY TAB
// ═══════════════════════════════════════════════════════════════

class _HistoryTab extends ConsumerWidget {
  final NumberFormat fmt;
  const _HistoryTab({required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_cashBoxHistoryProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: historyAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (history) => history.isEmpty
            ? const EmptyState(
                title: 'لا يوجد سجل', icon: Icons.history_outlined)
            : AppTable(
                headers: const [
                  'التاريخ',
                  'الرصيد الافتتاحي',
                  'الإيرادات',
                  'المصروفات',
                  'الرصيد الختامي',
                  'الحالة'
                ],
                rows: history
                    .map((box) => [
                          Text(box.boxDate,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${fmt.format(box.openingBalance)} USD',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          Text('${fmt.format(box.totalIncome)} USD',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                          Text('${fmt.format(box.totalExpenses)} USD',
                              style: const TextStyle(color: AppColors.error)),
                          Text(
                            '${fmt.format(box.closingBalance ?? box.calculatedClosingBalance)} USD',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                          StatusChip(
                            label: box.isClosed ? 'مغلقة' : 'مفتوحة',
                            color: box.isClosed
                                ? AppColors.textHint
                                : AppColors.success,
                          ),
                        ])
                    .toList(),
              ),
      ),
    );
  }
}

final _cashBoxHistoryProvider = FutureProvider<List<CashBox>>(
    (ref) => ref.watch(cashBoxRepositoryProvider).getHistory());
