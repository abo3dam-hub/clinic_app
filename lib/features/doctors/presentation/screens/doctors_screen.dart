// lib/features/doctors/presentation/screens/doctors_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/doctor.dart';

class DoctorsScreen extends ConsumerWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(doctorNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PrimaryButton(
                label: 'طبيب جديد',
                icon: Icons.add,
                onPressed: () => _showDoctorDialog(context, ref, null),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: doctorsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (doctors) => doctors.isEmpty
                  ? EmptyState(
                      title: 'لا يوجد أطباء',
                      icon: Icons.medical_services_outlined,
                      action: PrimaryButton(
                        label: 'إضافة طبيب',
                        icon: Icons.add,
                        onPressed: () => _showDoctorDialog(context, ref, null),
                      ),
                    )
                  : AppTable(
                      headers: const [
                        'الاسم',
                        'التخصص',
                        'الهاتف',
                        'نسبة العمولة',
                        'إجراءات'
                      ],
                      rows: doctors
                          .map((d) => [
                                Text(d.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(d.specialty ?? '-',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                Text(d.phone ?? '-',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                StatusChip(
                                    label:
                                        '${d.commissionPct.toStringAsFixed(1)}%',
                                    color: AppColors.primary),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconActionButton(
                                      icon: Icons.edit_outlined,
                                      tooltip: 'تعديل',
                                      onPressed: () =>
                                          _showDoctorDialog(context, ref, d),
                                      color: AppColors.primary,
                                      bgColor: AppColors.primarySurface),
                                  const SizedBox(width: 6),
                                  IconActionButton(
                                      icon: Icons.delete_outline,
                                      tooltip: 'حذف',
                                      onPressed: () =>
                                          _confirmDelete(context, ref, d),
                                      color: AppColors.error,
                                      bgColor: AppColors.errorSurface),
                                ]),
                              ])
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDoctorDialog(
      BuildContext context, WidgetRef ref, Doctor? doctor) async {
    final nameCtrl = TextEditingController(text: doctor?.name ?? '');
    final specialtyCtrl = TextEditingController(text: doctor?.specialty ?? '');
    final phoneCtrl = TextEditingController(text: doctor?.phone ?? '');
    final commissionCtrl = TextEditingController(
        text: doctor != null ? doctor.commissionPct.toString() : '0');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doctor == null ? 'إضافة طبيب' : 'تعديل بيانات الطبيب'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppTextField(
                  label: 'الاسم',
                  required: true,
                  controller: nameCtrl,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'التخصص', controller: specialtyCtrl),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                  label: 'الهاتف',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'نسبة العمولة %',
                required: true,
                controller: commissionCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0 || n > 100)
                    return 'أدخل نسبة بين 0 و 100';
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
            label: doctor == null ? 'إضافة' : 'حفظ',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final now = DateTime.now();
              final d = Doctor(
                id: doctor?.id,
                name: nameCtrl.text.trim(),
                specialty: specialtyCtrl.text.trim().isEmpty
                    ? null
                    : specialtyCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                commissionPct: double.tryParse(commissionCtrl.text) ?? 0,
                createdAt: now,
                updatedAt: now,
              );
              try {
                if (doctor == null) {
                  await ref.read(doctorNotifierProvider.notifier).create(d);
                  if (context.mounted) showSnack(context, 'تم إضافة الطبيب');
                } else {
                  await ref
                      .read(doctorNotifierProvider.notifier)
                      .updateDoctor(d);
                  if (context.mounted)
                    showSnack(context, 'تم تحديث بيانات الطبيب');
                }
              } catch (e) {
                if (context.mounted) showSnack(context, 'خطأ: $e', error: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Doctor d) async {
    final ok = await ConfirmDialog.show(context,
        title: 'حذف طبيب',
        message: 'هل تريد حذف "${d.name}"؟',
        confirmLabel: 'حذف',
        isDanger: true);
    if (ok && context.mounted) {
      try {
        await ref.read(doctorNotifierProvider.notifier).delete(d.id!);
        showSnack(context, 'تم الحذف');
      } catch (e) {
        showSnack(context, 'خطأ: $e', error: true);
      }
    }
  }
}
