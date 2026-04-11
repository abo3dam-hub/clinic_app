// lib/features/patients/presentation/screens/patients_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/patient.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    if (q.isEmpty) {
      setState(() => _searching = false);
      ref.invalidate(patientNotifierProvider);
    } else {
      setState(() => _searching = true);
      ref.read(patientNotifierProvider.notifier).search(q);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Toolbar ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PrimaryButton(
                label: 'مريض جديد',
                icon: Icons.add,
                onPressed: () => context.go('/patients/new'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Table ────────────────────────────────────────────
          Expanded(
            child: patientsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'خطأ في تحميل المرضى: $e',
                onRetry: () => ref.invalidate(patientNotifierProvider),
              ),
              data: (patients) => patients.isEmpty
                  ? EmptyState(
                      title: _searching ? 'لا نتائج' : 'لا يوجد مرضى',
                      subtitle: _searching
                          ? 'جرب البحث بكلمة أخرى'
                          : 'أضف أول مريض بالضغط على زر "مريض جديد"',
                      icon: Icons.people_outline,
                      action: _searching
                          ? null
                          : PrimaryButton(
                              label: 'إضافة مريض',
                              icon: Icons.add,
                              onPressed: () => context.go('/patients/new'),
                            ),
                    )
                  : _PatientsTable(
                      patients: patients,
                      onEdit: (p) => context.go('/patients/${p.id}/edit'),
                      onDelete: (p) => _confirmDelete(context, ref, p),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Patient p) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'حذف مريض',
      message: 'هل أنت متأكد من حذف "${p.name}"؟ لن يتم حذف بياناته نهائياً.',
      confirmLabel: 'حذف',
      isDanger: true,
    );
    if (confirmed && context.mounted) {
      try {
        await ref.read(patientNotifierProvider.notifier).delete(p.id!);
        showSnack(context, 'تم حذف المريض بنجاح');
      } catch (e) {
        showSnack(context, 'خطأ: $e', error: true);
      }
    }
  }
}

// ─── Patients Table ───────────────────────────────────────────

class _PatientsTable extends StatelessWidget {
  final List<Patient> patients;
  final void Function(Patient) onEdit;
  final void Function(Patient) onDelete;

  const _PatientsTable({
    required this.patients,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => AppTable(
        headers: const ['الاسم', 'الهاتف', 'الجنس', 'تاريخ الميلاد', 'الحالة', 'إجراءات'],
        rows: patients
            .map((p) => [
                  Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.primary)),
                  Text(p.phone ?? '-',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  Text(_genderLabel(p.gender),
                      style: const TextStyle(color: AppColors.textSecondary)),
                  Text(p.birthDate ?? '-',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  StatusChip(
                    label: p.isActive ? 'نشط' : 'غير نشط',
                    color: p.isActive ? AppColors.success : AppColors.textHint,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'تعديل',
                        onPressed: () => onEdit(p),
                        color: AppColors.primary,
                        bgColor: AppColors.primarySurface,
                      ),
                      const SizedBox(width: 6),
                      IconActionButton(
                        icon: Icons.delete_outline,
                        tooltip: 'حذف',
                        onPressed: () => onDelete(p),
                        color: AppColors.error,
                        bgColor: AppColors.errorSurface,
                      ),
                    ],
                  ),
                ])
            .toList(),
      );

  String _genderLabel(String? g) => switch (g) {
        'male'   => 'ذكر',
        'female' => 'أنثى',
        _        => '-',
      };
}
