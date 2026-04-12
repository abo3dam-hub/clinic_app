// lib/features/inventory/presentation/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/inventory.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'ar');

    return Column(children: [
      // Tab bar
      Container(
        color: AppColors.surfaceCard,
        child: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'الأصناف'),
            Tab(
                icon: Icon(Icons.swap_horiz_outlined, size: 18),
                text: 'حركات المخزون'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _ItemsTab(fmt: fmt),
            _MovementsTab(fmt: fmt),
          ],
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// ITEMS TAB
// ═══════════════════════════════════════════════════════════════

class _ItemsTab extends ConsumerWidget {
  final NumberFormat fmt;
  const _ItemsTab({required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final lowAsync = ref.watch(lowStockProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        Row(children: [
          // Low stock warning
          lowAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (low) => low.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warningSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Text('${low.length} صنف تحت الحد الأدنى',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ]),
                  ),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'صنف جديد',
            icon: Icons.add,
            onPressed: () => _showItemDialog(context, ref, null),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: itemsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (items) => items.isEmpty
                ? EmptyState(
                    title: 'لا توجد أصناف',
                    icon: Icons.inventory_2_outlined,
                    action: PrimaryButton(
                      label: 'إضافة صنف',
                      icon: Icons.add,
                      onPressed: () => _showItemDialog(context, ref, null),
                    ),
                  )
                : AppTable(
                    headers: const [
                      'الصنف',
                      'الوحدة',
                      'الكمية',
                      'الحد الأدنى',
                      'التكلفة',
                      'الحالة',
                      'إجراءات'
                    ],
                    rows: items
                        .map((item) => [
                              Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(item.unit ?? '-',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              Text(
                                item.quantity.toStringAsFixed(
                                    item.quantity % 1 == 0 ? 0 : 2),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: item.isBelowMinimum
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                ),
                              ),
                              Text('${item.minQuantity.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              Text('${fmt.format(item.unitCost)} USD',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              StatusChip(
                                label: item.isBelowMinimum ? 'منخفض' : 'طبيعي',
                                color: item.isBelowMinimum
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconActionButton(
                                  icon: Icons.add_circle_outline,
                                  tooltip: 'إضافة حركة',
                                  onPressed: () =>
                                      _showMovementDialog(context, ref, item),
                                  color: AppColors.secondary,
                                  bgColor: AppColors.secondarySurface,
                                ),
                                const SizedBox(width: 6),
                                IconActionButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: 'تعديل',
                                  onPressed: () =>
                                      _showItemDialog(context, ref, item),
                                  color: AppColors.primary,
                                  bgColor: AppColors.primarySurface,
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

  Future<void> _showItemDialog(
      BuildContext ctx, WidgetRef ref, InventoryItem? item) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final unitCtrl = TextEditingController(text: item?.unit ?? '');
    final minQtyCtrl = TextEditingController(
        text: item?.minQuantity.toStringAsFixed(0) ?? '0');
    final costCtrl =
        TextEditingController(text: item?.unitCost.toStringAsFixed(2) ?? '0');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'صنف جديد' : 'تعديل الصنف'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppTextField(
                label: 'اسم الصنف',
                required: true,
                controller: nameCtrl,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                    child: AppTextField(
                        label: 'الوحدة',
                        hint: 'قطعة / علبة ...',
                        controller: unitCtrl)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: AppTextField(
                  label: 'الحد الأدنى',
                  controller: minQtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                )),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'تكلفة الوحدة (USD)',
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          PrimaryButton(
            label: item == null ? 'إضافة' : 'حفظ',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final now = DateTime.now();
              final newItem = InventoryItem(
                id: item?.id,
                name: nameCtrl.text.trim(),
                unit:
                    unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
                minQuantity: double.tryParse(minQtyCtrl.text) ?? 0,
                quantity: item?.quantity ?? 0,
                unitCost: double.tryParse(costCtrl.text) ?? 0,
                createdAt: now,
                updatedAt: now,
              );
              try {
                final repo = ref.read(inventoryRepositoryProvider);
                if (item == null) {
                try {
                  await repo.createItem(newItem);
                  if (ctx.mounted) {
                    showSnack(ctx, 'تم إضافة الصنف بنجاح');
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    showSnack(ctx, 'خطأ أثناء إضافة الصنف: $e', error: true);
                  }
                }
                } else {
                  await repo.updateItem(newItem);
                  if (ctx.mounted) showSnack(ctx, 'تم التحديث');
                }
                ref.invalidate(inventoryItemsProvider);
                ref.invalidate(lowStockProvider);
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showMovementDialog(
      BuildContext ctx, WidgetRef ref, InventoryItem item) async {
    String type = 'in';
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text('حركة مخزون — ${item.name}'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('الكمية الحالية: ${item.quantity}',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              AppDropdown<String>(
                label: 'نوع الحركة',
                value: type,
                items: const [
                  DropdownMenuItem(value: 'in', child: Text('وارد (إضافة)')),
                  DropdownMenuItem(value: 'out', child: Text('صادر (إخراج)')),
                  DropdownMenuItem(value: 'adjustment', child: Text('تعديل')),
                ],
                onChanged: (v) => setSt(() => type = v ?? 'in'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'الكمية',
                required: true,
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'ملاحظات', controller: notesCtrl),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            PrimaryButton(
              label: 'تأكيد',
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text);
                if (qty == null || qty <= 0) {
                  showSnack(ctx, 'أدخل كمية صحيحة', error: true);
                  return;
                }
                Navigator.pop(ctx);
                final now = DateTime.now();
                final movement = StockMovement(
                  itemId: item.id!,
                  type: StockMovementTypeX.fromString(type),
                  quantity: qty,
                  movementDate: ClinicDateUtils.todayString(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: now,
                );
                try {
                  await ref
                      .read(inventoryRepositoryProvider)
                      .addMovement(movement);
                  ref.invalidate(inventoryItemsProvider);
                  ref.invalidate(lowStockProvider);
                  ref.invalidate(stockMovementsProvider(null));
                  if (ctx.mounted) showSnack(ctx, 'تمت الحركة بنجاح');
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
}

// ═══════════════════════════════════════════════════════════════
// MOVEMENTS TAB
// ═══════════════════════════════════════════════════════════════

class _MovementsTab extends ConsumerWidget {
  final NumberFormat fmt;
  const _MovementsTab({required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movAsync = ref.watch(stockMovementsProvider(null));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        // Toolbar
        Row(children: [
          const Text('سجل حركات المخزون',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary)),
          const Spacer(),
          SecondaryButton(
            label: 'تحديث',
            icon: Icons.refresh,
            compact: true,
            onPressed: () => ref.invalidate(stockMovementsProvider(null)),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),

        Expanded(
          child: movAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (movements) => movements.isEmpty
                ? const EmptyState(
                    title: 'لا توجد حركات', icon: Icons.swap_horiz_outlined)
                : AppTable(
                    headers: const [
                      'التاريخ',
                      'الصنف',
                      'النوع',
                      'الكمية',
                      'ملاحظات'
                    ],
                    rows: movements.map((m) {
                      final (typeLabel, typeColor) = switch (m.type) {
                        StockMovementType.inward => ('وارد', AppColors.success),
                        StockMovementType.outward => ('صادر', AppColors.error),
                        StockMovementType.adjustment => (
                            'تعديل',
                            AppColors.warning
                          ),
                      };
                      return [
                        Text(m.movementDate,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        Text(m.itemName ?? '-',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        StatusChip(label: typeLabel, color: typeColor),
                        Text(
                          m.quantity
                              .toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: typeColor),
                        ),
                        Text(m.notes ?? '-',
                            style: const TextStyle(
                                color: AppColors.textHint, fontSize: 12)),
                      ];
                    }).toList(),
                  ),
          ),
        ),
      ]),
    );
  }
}
