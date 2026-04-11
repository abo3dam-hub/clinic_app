// lib/features/visits/presentation/screens/visits_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/visit.dart';
import '../../../../core/providers/repository_providers.dart';

class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Toolbar
          Row(
            children: [
              Expanded(child: _VisitFilters()),
              const SizedBox(width: AppSpacing.md),
              PrimaryButton(
                label: 'زيارة جديدة',
                icon: Icons.add,
                onPressed: () => context.go('/visits/new'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: visitsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (visits) => visits.isEmpty
                  ? EmptyState(
                      title: 'لا توجد زيارات',
                      icon: Icons.local_hospital_outlined,
                      action: PrimaryButton(
                        label: 'إضافة زيارة',
                        icon: Icons.add,
                        onPressed: () => context.go('/visits/new'),
                      ),
                    )
                  : AppTable(
                      headers: const [
                        'المريض',
                        'الطبيب',
                        'التاريخ',
                        'التشخيص',
                        'الحالة',
                        'إجراءات'
                      ],
                      rows: visits
                          .map((v) => [
                                Text(v.patientName ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                                Text(v.doctorName ?? '-',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                Text(v.visitDate,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                Text(v.diagnosis ?? '-',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis),
                                StatusChip(
                                  label: v.isLocked ? 'مقفلة' : 'مفتوحة',
                                  color: v.isLocked
                                      ? AppColors.textHint
                                      : AppColors.success,
                                ),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconActionButton(
                                    icon: Icons.edit_outlined,
                                    tooltip: 'تعديل',
                                    onPressed: v.isLocked
                                        ? null
                                        : () => context.go('/visits/${v.id}'),
                                    color: AppColors.primary,
                                    bgColor: AppColors.primarySurface,
                                  ),
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
}

class _VisitFilters extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(visitFilterProvider);
    return Row(children: [
      SizedBox(
        width: 180,
        child: TextField(
          readOnly: true,
          decoration: const InputDecoration(
              hintText: 'من تاريخ',
              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
          controller: TextEditingController(text: filter.fromDate ?? ''),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              locale: const Locale('ar'),
            );
            if (picked != null) {
              final s = '${picked.year.toString().padLeft(4, '0')}-'
                  '${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
              ref.read(visitFilterProvider.notifier).state =
                  VisitFilter(fromDate: s, toDate: filter.toDate);
            }
          },
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// lib/features/visits/presentation/screens/visit_form_screen.dart
// ═══════════════════════════════════════════════════════════════

class VisitFormScreen extends ConsumerStatefulWidget {
  final int? visitId;
  const VisitFormScreen({super.key, this.visitId});

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends ConsumerState<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int? _patientId;
  int? _doctorId;
  String _visitDate = '';
  bool _loading = false;

  bool get _isEdit => widget.visitId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visitDate = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patientId == null) {
      showSnack(context, 'اختر المريض', error: true);
      return;
    }
    if (_doctorId == null) {
      showSnack(context, 'اختر الطبيب', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final visit = Visit(
        id: widget.visitId,
        patientId: _patientId!,
        doctorId: _doctorId!,
        visitDate: _visitDate,
        diagnosis: _diagnosisCtrl.text.trim().isEmpty
            ? null
            : _diagnosisCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(visitRepositoryProvider);
      if (_isEdit) {
        await repo.update(visit);
        if (mounted) showSnack(context, 'تم تحديث الزيارة');
      } else {
        await repo.create(visit);
        if (mounted) showSnack(context, 'تم إضافة الزيارة');
      }
      ref.invalidate(visitsProvider);
      if (mounted) context.go('/visits');
    } catch (e) {
      if (mounted) showSnack(context, 'خطأ: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientNotifierProvider);
    final doctorsAsync = ref.watch(doctorNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    IconActionButton(
                        icon: Icons.arrow_back,
                        tooltip: 'رجوع',
                        onPressed: () => context.go('/visits')),
                    const SizedBox(width: AppSpacing.md),
                    Text(_isEdit ? 'تعديل الزيارة' : 'زيارة جديدة',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ]),
                  const SizedBox(height: AppSpacing.xl),

                  // Patient + Doctor
                  Row(children: [
                    Expanded(
                        child: patientsAsync.when(
                      loading: () => const LoadingView(),
                      error: (e, _) => ErrorView(message: e.toString()),
                      data: (patients) => AppDropdown<int>(
                        label: 'المريض',
                        required: true,
                        value: _patientId,
                        items: patients
                            .map((p) => DropdownMenuItem(
                                value: p.id!, child: Text(p.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _patientId = v),
                      ),
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: doctorsAsync.when(
                      loading: () => const LoadingView(),
                      error: (e, _) => ErrorView(message: e.toString()),
                      data: (doctors) => AppDropdown<int>(
                        label: 'الطبيب',
                        required: true,
                        value: _doctorId,
                        items: doctors
                            .map((d) => DropdownMenuItem(
                                value: d.id!, child: Text(d.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _doctorId = v),
                      ),
                    )),
                  ]),
                  const SizedBox(height: AppSpacing.md),

                  AppDateField(
                    label: 'تاريخ الزيارة',
                    required: true,
                    value: _visitDate,
                    onChanged: (v) => setState(() => _visitDate = v),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                      label: 'التشخيص',
                      controller: _diagnosisCtrl,
                      maxLines: 2),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                      label: 'ملاحظات', controller: _notesCtrl, maxLines: 3),
                  const SizedBox(height: AppSpacing.xl),

                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    SecondaryButton(
                        label: 'إلغاء', onPressed: () => context.go('/visits')),
                    const SizedBox(width: AppSpacing.md),
                    PrimaryButton(
                      label: _isEdit ? 'حفظ التعديلات' : 'إضافة الزيارة',
                      icon: _isEdit ? Icons.save_outlined : Icons.add,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
