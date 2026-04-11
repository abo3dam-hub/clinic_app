// lib/features/appointments/presentation/screens/appointments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod/src/providers/legacy/state_controller.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../domain/entities/appointment.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  String _selectedDate = ClinicDateUtils.todayString();
  String? _statusFilter;

  void _changeDate(int offsetDays) {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final newDate = current.add(Duration(days: offsetDays));
    setState(() => _selectedDate = ClinicDateUtils.toDbDate(newDate));

    // نستدعي دالة التحديث اللي كتبناها
    ref.read(appointmentFilterProvider.notifier).updateFilter(
          AppointmentFilter(date: _selectedDate, status: _statusFilter),
        );
  }

  void _applyFilter() {
    ref.read(appointmentFilterProvider.notifier).state =
        AppointmentFilter(date: _selectedDate, status: _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsProvider);
    final dateLabel = _formatDate(_selectedDate);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar ───────────────────────────────────────────
          Row(
            children: [
              // Date navigation
              _DateNavigator(
                label: dateLabel,
                onPrev: () => _changeDate(-1),
                onNext: () => _changeDate(1),
                onPick: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(_selectedDate) ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    locale: const Locale('ar'),
                  );
                  if (picked != null) {
                    setState(
                        () => _selectedDate = ClinicDateUtils.toDbDate(picked));
                    _applyFilter();
                  }
                },
              ),
              const SizedBox(width: AppSpacing.md),

              // Status filter chips
              _buildStatusChips(),
              const Spacer(),

              PrimaryButton(
                label: 'موعد جديد',
                icon: Icons.add,
                onPressed: () => _showAppointmentDialog(context, ref, null),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Counts row ────────────────────────────────────────
          _CountsRow(date: _selectedDate),
          const SizedBox(height: AppSpacing.lg),

          // ── Appointments list ─────────────────────────────────
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(appointmentsProvider)),
              data: (appointments) {
                final filtered = _statusFilter == null
                    ? appointments
                    : appointments
                        .where((a) => a.status.value == _statusFilter)
                        .toList();

                return filtered.isEmpty
                    ? EmptyState(
                        title: 'لا توجد مواعيد',
                        subtitle: 'لا توجد مواعيد في هذا اليوم',
                        icon: Icons.calendar_today_outlined,
                        action: PrimaryButton(
                          label: 'إضافة موعد',
                          icon: Icons.add,
                          onPressed: () =>
                              _showAppointmentDialog(context, ref, null),
                        ),
                      )
                    : _AppointmentsGrid(
                        appointments: filtered,
                        onEdit: (a) => _showAppointmentDialog(context, ref, a),
                        onStatusChange: (a, s) =>
                            _changeStatus(context, ref, a, s),
                        onDelete: (a) => _confirmDelete(context, ref, a),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() => Row(
        children: [
          _FilterChip(
            label: 'الكل',
            selected: _statusFilter == null,
            onTap: () => setState(() {
              _statusFilter = null;
              _applyFilter();
            }),
          ),
          const SizedBox(width: 6),
          for (final s in AppointmentStatus.values)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _FilterChip(
                label: s.label,
                color: _statusColor(s),
                selected: _statusFilter == s.value,
                onTap: () => setState(() {
                  _statusFilter = _statusFilter == s.value ? null : s.value;
                  _applyFilter();
                }),
              ),
            ),
        ],
      );

  Future<void> _showAppointmentDialog(
      BuildContext ctx, WidgetRef ref, Appointment? existing) async {
    final patients = await ref.read(patientRepositoryProvider).getAll();
    final doctors = await ref.read(doctorRepositoryProvider).getAll();
    if (!ctx.mounted) return;

    int? patientId = existing?.patientId;
    int? doctorId = existing?.doctorId;
    String dateTime = existing?.scheduledAt ?? '$_selectedDate 09:00';
    String status = existing?.status.value ?? 'pending';
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setSt) => AlertDialog(
          title: Text(existing == null ? 'موعد جديد' : 'تعديل الموعد'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Patient
                AppDropdown<int>(
                  label: 'المريض',
                  required: true,
                  value: patientId,
                  items: patients
                      .map((p) =>
                          DropdownMenuItem(value: p.id!, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setSt(() => patientId = v),
                  validator: (v) => v == null ? 'اختر المريض' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                // Doctor
                AppDropdown<int>(
                  label: 'الطبيب',
                  required: true,
                  value: doctorId,
                  items: doctors
                      .map((d) =>
                          DropdownMenuItem(value: d.id!, child: Text(d.name)))
                      .toList(),
                  onChanged: (v) => setSt(() => doctorId = v),
                  validator: (v) => v == null ? 'اختر الطبيب' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                // Date + Time
                Row(children: [
                  Expanded(
                      child: AppDateField(
                    label: 'التاريخ',
                    required: true,
                    value: dateTime.length >= 10
                        ? dateTime.substring(0, 10)
                        : dateTime,
                    onChanged: (d) => setSt(() {
                      final time = dateTime.length >= 16
                          ? dateTime.substring(11, 16)
                          : '09:00';
                      dateTime = '$d $time';
                    }),
                  )),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                      child: AppTextField(
                    label: 'الوقت (HH:MM)',
                    hint: '09:00',
                    controller: TextEditingController(
                        text: dateTime.length >= 16
                            ? dateTime.substring(11, 16)
                            : ''),
                    onChanged: (t) {
                      final date = dateTime.length >= 10
                          ? dateTime.substring(0, 10)
                          : _selectedDate;
                      dateTime = '$date $t';
                    },
                  )),
                ]),
                const SizedBox(height: AppSpacing.md),
                if (existing != null)
                  AppDropdown<String>(
                    label: 'الحالة',
                    value: status,
                    items: AppointmentStatus.values
                        .map((s) => DropdownMenuItem(
                            value: s.value, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setSt(() => status = v ?? 'pending'),
                  ),
                if (existing != null) const SizedBox(height: AppSpacing.md),
                AppTextField(
                    label: 'ملاحظات', controller: notesCtrl, maxLines: 2),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء')),
            PrimaryButton(
              label: existing == null ? 'إضافة' : 'حفظ',
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogCtx);
                final now = DateTime.now();
                final apt = Appointment(
                  id: existing?.id,
                  patientId: patientId!,
                  doctorId: doctorId!,
                  scheduledAt: dateTime,
                  status: AppointmentStatusX.fromString(status),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                );
                try {
                  final repo = ref.read(appointmentRepositoryProvider);
                  if (existing == null) {
                    await repo.create(apt);
                    if (ctx.mounted) showSnack(ctx, 'تم إضافة الموعد');
                  } else {
                    await repo.update(apt);
                    if (ctx.mounted) showSnack(ctx, 'تم تحديث الموعد');
                  }
                  ref.invalidate(appointmentsProvider);
                  ref.invalidate(todayAppointmentCountsProvider);
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

  Future<void> _changeStatus(BuildContext ctx, WidgetRef ref, Appointment apt,
      AppointmentStatus newStatus) async {
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .updateStatus(apt.id!, newStatus);
      ref.invalidate(appointmentsProvider);
      ref.invalidate(todayAppointmentCountsProvider);
      if (ctx.mounted) showSnack(ctx, 'تم تحديث الحالة إلى ${newStatus.label}');
    } catch (e) {
      if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
    }
  }

  Future<void> _confirmDelete(
      BuildContext ctx, WidgetRef ref, Appointment apt) async {
    final ok = await ConfirmDialog.show(ctx,
        title: 'حذف موعد',
        message: 'هل تريد حذف موعد ${apt.patientName}؟',
        confirmLabel: 'حذف',
        isDanger: true);
    if (ok && ctx.mounted) {
      try {
        await ref.read(appointmentRepositoryProvider).delete(apt.id!);
        ref.invalidate(appointmentsProvider);
        if (ctx.mounted) showSnack(ctx, 'تم الحذف');
      } catch (e) {
        if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final fmt = DateFormat('EEEE، d MMMM yyyy', 'ar');
      return fmt.format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(AppointmentStatus s) => switch (s) {
        AppointmentStatus.pending => AppColors.warning,
        AppointmentStatus.confirmed => AppColors.primary,
        AppointmentStatus.completed => AppColors.success,
        AppointmentStatus.cancelled => AppColors.textHint,
      };
}

extension on StateController<AppointmentFilter> {
  void updateFilter(AppointmentFilter appointmentFilter) {}
}

// ─── Date Navigator ───────────────────────────────────────────

class _DateNavigator extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_right, size: 20)),
          GestureDetector(
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 14)),
              ]),
            ),
          ),
          IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_left, size: 20)),
        ]),
      );
}

// ─── Filter Chip ──────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.12) : AppColors.borderLight,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? c : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? c : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12)),
      ),
    );
  }
}

// ─── Counts Row ───────────────────────────────────────────────

class _CountsRow extends ConsumerWidget {
  final String date;
  const _CountsRow({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(todayAppointmentCountsProvider);
    return countsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (counts) => Row(children: [
        _CountBadge(
            'الكل', counts.values.fold(0, (a, b) => a + b), AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        _CountBadge('انتظار', counts['pending'] ?? 0, AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        _CountBadge('مؤكد', counts['confirmed'] ?? 0, AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        _CountBadge('مكتمل', counts['completed'] ?? 0, AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        _CountBadge('ملغي', counts['cancelled'] ?? 0, AppColors.textHint),
      ]),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$count',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

// ─── Appointments Grid ────────────────────────────────────────

class _AppointmentsGrid extends StatelessWidget {
  final List<Appointment> appointments;
  final void Function(Appointment) onEdit;
  final void Function(Appointment, AppointmentStatus) onStatusChange;
  final void Function(Appointment) onDelete;

  const _AppointmentsGrid({
    required this.appointments,
    required this.onEdit,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.9,
        ),
        itemCount: appointments.length,
        itemBuilder: (_, i) => _AppointmentCard(
          appointment: appointments[i],
          onEdit: () => onEdit(appointments[i]),
          onStatusChange: (s) => onStatusChange(appointments[i], s),
          onDelete: () => onDelete(appointments[i]),
        ),
      );
}

// ─── Appointment Card ─────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onEdit;
  final void Function(AppointmentStatus) onStatusChange;
  final VoidCallback onDelete;

  const _AppointmentCard({
    required this.appointment,
    required this.onEdit,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = appointment.status;
    final borderColor = _statusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        // Color bar at top
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: borderColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time + Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.access_time_outlined,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(appointment.timeOnly,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                    StatusChip(label: status.label, color: borderColor),
                  ],
                ),
                const SizedBox(height: 6),
                // Patient name
                Text(
                  appointment.patientName ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Doctor name
                Text(
                  appointment.doctorName ?? '-',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                if (appointment.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    appointment.notes!,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                // Action buttons
                Row(children: [
                  // Quick status buttons
                  if (status == AppointmentStatus.pending) ...[
                    _QuickBtn(
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        tooltip: 'تأكيد',
                        onTap: () =>
                            onStatusChange(AppointmentStatus.confirmed)),
                    const SizedBox(width: 4),
                    _QuickBtn(
                        icon: Icons.cancel_outlined,
                        color: AppColors.error,
                        tooltip: 'إلغاء',
                        onTap: () =>
                            onStatusChange(AppointmentStatus.cancelled)),
                    const SizedBox(width: 4),
                  ],
                  if (status == AppointmentStatus.confirmed)
                    _QuickBtn(
                        icon: Icons.done_all,
                        color: AppColors.secondary,
                        tooltip: 'إتمام',
                        onTap: () =>
                            onStatusChange(AppointmentStatus.completed)),
                  const Spacer(),
                  IconActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'تعديل',
                      onPressed: onEdit,
                      color: AppColors.primary,
                      bgColor: AppColors.primarySurface),
                  const SizedBox(width: 4),
                  IconActionButton(
                      icon: Icons.delete_outline,
                      tooltip: 'حذف',
                      onPressed: onDelete,
                      color: AppColors.error,
                      bgColor: AppColors.errorSurface),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Color _statusColor(AppointmentStatus s) => switch (s) {
        AppointmentStatus.pending => AppColors.warning,
        AppointmentStatus.confirmed => AppColors.primary,
        AppointmentStatus.completed => AppColors.success,
        AppointmentStatus.cancelled => AppColors.textHint,
      };
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _QuickBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}
