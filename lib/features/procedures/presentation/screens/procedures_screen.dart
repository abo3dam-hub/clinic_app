// lib/features/procedures/presentation/screens/procedures_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/procedure.dart';

class ProceduresScreen extends ConsumerStatefulWidget {
  const ProceduresScreen({super.key});

  @override
  ConsumerState<ProceduresScreen> createState() => _ProceduresScreenState();
}

class _ProceduresScreenState extends ConsumerState<ProceduresScreen> {
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.00', 'ar');
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proceduresAsync = ref.watch(procedureNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        // Toolbar
        Row(children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'بحث في الإجراءات...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        })
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          PrimaryButton(
            label: 'إجراء جديد',
            icon: Icons.add,
            onPressed: () => _showProcedureDialog(context, ref, null),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),

        // Stats bar
        proceduresAsync.maybeWhen(
          // في حال وجود البيانات، نعرض الـ _StatsBar
          data: (procedures) => _StatsBar(
            total: procedures.length,
            active: procedures.where((p) => p.isActive).length,
            inactive: procedures.where((p) => !p.isActive).length,
            fmt: _fmt,
            avgPrice: procedures.isEmpty
                ? 0
                : procedures
                        .map((p) => p.defaultPrice)
                        .reduce((a, b) => a + b) /
                    procedures.length,
          ),
          // في أي حالة أخرى (تحميل، خطأ، أو لا يوجد بيانات)، نعرض SizedBox.shrink
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.md),

        // Table
        Expanded(
          child: proceduresAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (procedures) => procedures.isEmpty
                ? EmptyState(
                    title: _searching ? 'لا نتائج' : 'لا توجد إجراءات',
                    icon: Icons.medical_services_outlined,
                    action: _searching
                        ? null
                        : PrimaryButton(
                            label: 'إضافة إجراء',
                            icon: Icons.add,
                            onPressed: () =>
                                _showProcedureDialog(context, ref, null),
                          ),
                  )
                : AppTable(
                    headers: const [
                      'الإجراء',
                      'الوصف',
                      'السعر الافتراضي',
                      'الحالة',
                      'إجراءات'
                    ],
                    rows: procedures
                        .map((p) => [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                              Text(p.description ?? '-',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Text('${_fmt.format(p.defaultPrice)} USD',
                                  style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w700)),
                              _ActiveToggle(
                                procedure: p,
                                onToggle: (active) => ref
                                    .read(procedureNotifierProvider.notifier)
                                    .toggle(p.id!, active),
                              ),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconActionButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: 'تعديل',
                                  onPressed: () =>
                                      _showProcedureDialog(context, ref, p),
                                  color: AppColors.primary,
                                  bgColor: AppColors.primarySurface,
                                ),
                                const SizedBox(width: 6),
                                IconActionButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'حذف',
                                  onPressed: () =>
                                      _confirmDelete(context, ref, p),
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

  void _onSearch(String q) {
    if (q.isEmpty) {
      setState(() => _searching = false);
      ref.invalidate(procedureNotifierProvider);
    } else {
      setState(() => _searching = true);
      ref.read(procedureNotifierProvider.notifier).search(q);
    }
  }

  Future<void> _showProcedureDialog(
      BuildContext ctx, WidgetRef ref, Procedure? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
        text: existing?.defaultPrice.toStringAsFixed(2) ?? '0.00');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'إجراء جديد' : 'تعديل الإجراء'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppTextField(
                label: 'اسم الإجراء',
                required: true,
                controller: nameCtrl,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'الوصف', controller: descCtrl, maxLines: 2),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'السعر الافتراضي (USD)',
                required: true,
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return 'أدخل سعراً صحيحاً';
                  return null;
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          PrimaryButton(
            label: existing == null ? 'إضافة' : 'حفظ',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final now = DateTime.now();
              final proc = Procedure(
                id: existing?.id,
                name: nameCtrl.text.trim(),
                description:
                    descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                defaultPrice: double.tryParse(priceCtrl.text) ?? 0,
                createdAt: now,
                updatedAt: now,
              );
              try {
                if (existing == null) {
                  await ref
                      .read(procedureNotifierProvider.notifier)
                      .create(proc);
                  if (ctx.mounted) showSnack(ctx, 'تم إضافة الإجراء');
                } else {
                  await ref
                      .read(procedureNotifierProvider.notifier)
                      .updateProcedure(proc);
                  if (ctx.mounted) showSnack(ctx, 'تم التحديث');
                }
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, WidgetRef ref, Procedure p) async {
    final ok = await ConfirmDialog.show(ctx,
        title: 'حذف إجراء',
        message: 'هل تريد حذف "${p.name}"؟',
        confirmLabel: 'حذف',
        isDanger: true);
    if (ok && ctx.mounted) {
      try {
        await ref.read(procedureNotifierProvider.notifier).delete(p.id!);
        if (ctx.mounted) showSnack(ctx, 'تم الحذف');
      } catch (e) {
        if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
      }
    }
  }
}

// ─── Active Toggle ────────────────────────────────────────────

class _ActiveToggle extends StatelessWidget {
  final Procedure procedure;
  final void Function(bool) onToggle;

  const _ActiveToggle({required this.procedure, required this.onToggle});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: procedure.isActive,
            onChanged: onToggle,
            activeThumbColor: AppColors.success,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            procedure.isActive ? 'نشط' : 'موقوف',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  procedure.isActive ? AppColors.success : AppColors.textHint,
            ),
          ),
        ],
      );
}

// ─── Stats Bar ────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total;
  final int active;
  final int inactive;
  final double avgPrice;
  final NumberFormat fmt;

  const _StatsBar({
    required this.total,
    required this.active,
    required this.inactive,
    required this.avgPrice,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        _Badge('الكل', '$total', AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        _Badge('نشط', '$active', AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        _Badge('موقوف', '$inactive', AppColors.textHint),
        const SizedBox(width: AppSpacing.md),
        const SizedBox(
          height: 24,
          child: VerticalDivider(width: 1),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'متوسط السعر: ${fmt.format(avgPrice)} USD',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ]);
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Badge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}
