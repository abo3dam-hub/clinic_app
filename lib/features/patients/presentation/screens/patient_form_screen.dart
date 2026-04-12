// lib/features/patients/presentation/screens/patient_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/patient.dart';
import '../../../../features/invoices/domain/entities/invoice.dart';

final patientInvoicesProvider = FutureProvider.family<List<Invoice>, int>((ref, patientId) async {
  return ref.watch(invoiceRepositoryProvider).getAll(patientId: patientId);
});

class PatientFormScreen extends ConsumerStatefulWidget {
  final int? patientId;
  const PatientFormScreen({super.key, this.patientId});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  String? _gender;
  String? _birthDate;
  bool _loading = false;
  bool _isInit = false;

  bool get _isEdit => widget.patientId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController();
    _phoneCtrl   = TextEditingController();
    _emailCtrl   = TextEditingController();
    _addressCtrl = TextEditingController();
    _notesCtrl   = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _populate(Patient p) {
    if (_isInit) return;
    _isInit = true;
    _nameCtrl.text    = p.name;
    _phoneCtrl.text   = p.phone   ?? '';
    _emailCtrl.text   = p.email   ?? '';
    _addressCtrl.text = p.address ?? '';
    _notesCtrl.text   = p.notes   ?? '';
    // FIX: Use setState safely via post-frame callback to avoid calling
    // setState during an active build cycle (which caused the black screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _gender    = p.gender;
          _birthDate = p.birthDate;
        });
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final patient = Patient(
        id: widget.patientId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        birthDate: _birthDate,
        gender: _gender,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes:   _notesCtrl.text.trim().isEmpty  ? null : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      if (_isEdit) {
        await ref.read(patientNotifierProvider.notifier).updatePatient(patient);
        if (mounted) showSnack(context, 'تم تحديث بيانات المريض');
      } else {
        await ref.read(patientNotifierProvider.notifier).create(patient);
        if (mounted) showSnack(context, 'تم إضافة المريض بنجاح');
      }
      if (mounted) context.go('/patients');
    } catch (e) {
      if (mounted) showSnack(context, 'خطأ: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Watch the provider to load patient data in edit mode.
    // _populate() now defers its setState to post-frame so it never
    // fires during the current build pass.
    if (_isEdit) {
      ref.watch(patientNotifierProvider).whenData((patients) {
        final match = patients.where((p) => p.id == widget.patientId);
        if (match.isNotEmpty) _populate(match.first);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // FIX: Wrap everything in SingleChildScrollView so the form is
        // fully accessible on any screen height — especially when the
        // Windows taskbar is visible and reduces available space.
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ──────────────────────────────────────
                      Row(
                        children: [
                          IconActionButton(
                            icon: Icons.arrow_back,
                            tooltip: 'رجوع',
                            onPressed: () => context.go('/patients'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            _isEdit ? 'تعديل بيانات المريض' : 'إضافة مريض جديد',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Row 1: Name + Phone ──────────────────────────
                      // FIX: Use Wrap for responsiveness on narrow windows
                      _ResponsiveRow(
                        children: [
                          AppTextField(
                            label: 'الاسم الكامل',
                            required: true,
                            controller: _nameCtrl,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                          ),
                          AppTextField(
                            label: 'رقم الهاتف',
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Row 2: Email + Birth date ────────────────────
                      _ResponsiveRow(
                        children: [
                          AppTextField(
                            label: 'البريد الإلكتروني',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          AppDateField(
                            label: 'تاريخ الميلاد',
                            value: _birthDate,
                            onChanged: (v) => setState(() => _birthDate = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Gender ───────────────────────────────────────
                      AppDropdown<String>(
                        label: 'الجنس',
                        value: _gender,
                        items: const [
                          DropdownMenuItem(value: 'male',   child: Text('ذكر')),
                          DropdownMenuItem(value: 'female', child: Text('أنثى')),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Address ──────────────────────────────────────
                      AppTextField(label: 'العنوان', controller: _addressCtrl),
                      const SizedBox(height: AppSpacing.md),

                      // ── Notes ────────────────────────────────────────
                      AppTextField(
                          label: 'ملاحظات', controller: _notesCtrl, maxLines: 3),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Actions ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SecondaryButton(
                            label: 'إلغاء',
                            onPressed: () => context.go('/patients'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          PrimaryButton(
                            label: _isEdit ? 'حفظ التعديلات' : 'إضافة المريض',
                            icon: _isEdit ? Icons.save_outlined : Icons.add,
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.lg),
                _PatientFinancialSummaryCard(patientId: widget.patientId!),
              ],
            ],
          ),
        ),
      ),
    );
  },
  }
}

/// A helper widget that places two children side-by-side on wide screens
/// and stacks them vertically on narrow screens (< 500 px).
class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          // Stack vertically on small windows
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }
        // Side by side on wider screens
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

// ─── Financial Summary Card ──────────────────────────────────────────────────
class _PatientFinancialSummaryCard extends ConsumerWidget {
  final int patientId;
  const _PatientFinancialSummaryCard({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInvoices = ref.watch(patientInvoicesProvider(patientId));
    
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'السجل المالي للمريض'),
          const SizedBox(height: AppSpacing.md),
          asyncInvoices.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(message: 'خطأ: \$e'),
            data: (invoices) {
              if (invoices.isEmpty) {
                return const Text('لا توجد فواتير مالية مسجلة لهذا المريض.', style: TextStyle(color: AppColors.textHint));
              }

              final totalNet = invoices.fold(0.0, (s, i) => s + i.netAmount);
              final totalPaid = invoices.fold(0.0, (s, i) => s + i.paidAmount);
              final totalRemaining = invoices.fold(0.0, (s, i) => s + i.remainingAmount);

              return Column(
                children: [
                  Row(
                    children: [
                      _StatBox(title: 'الإجمالي المطلوب', value: totalNet, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.md),
                      _StatBox(title: 'إجمالي المُحصَّل', value: totalPaid, color: AppColors.success),
                      const SizedBox(width: AppSpacing.md),
                      _StatBox(title: 'إجمالي المتبقي', value: totalRemaining, color: totalRemaining > 0 ? AppColors.error : AppColors.textHint),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SecondaryButton(
                      label: 'الذهاب للفواتير التفصيلية',
                      icon: Icons.receipt_long,
                      compact: true,
                      onPressed: () => context.go('/invoices'), 
                    ),
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  const _StatBox({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('\$${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
