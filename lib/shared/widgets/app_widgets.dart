// lib/shared/widgets/app_widgets.dart
//
// All reusable UI components in one barrel file.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// BUTTONS
// ═══════════════════════════════════════════════════════════════

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool compact;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: child,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label)
            ],
          )
        : Text(label);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: content,
    );
  }
}

class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const DangerButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
              )
            : Text(label),
      );
}

class IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? bgColor;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor ?? AppColors.borderLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// CARDS
// ═══════════════════════════════════════════════════════════════

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding, this.onTap, this.color});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color ?? AppColors.surfaceCard,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: AppRadius.card,
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
      );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textHint)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// FORM FIELDS
// ═══════════════════════════════════════════════════════════════

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final bool required;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontSize: 13, color: AppColors.textSecondary)),
              if (required)
                const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: obscureText ? 1 : maxLines,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefix,
              suffixIcon: suffix,
            ),
          ),
        ],
      );
}

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool required;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontSize: 13, color: AppColors.textSecondary)),
              if (required)
                const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            decoration: const InputDecoration(),
            isExpanded: true,
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
// FIX: AppDateField is now a StatefulWidget.
// The old version created a new TextEditingController inside
// every build() call — a serious memory leak and state bug that
// caused the "black screen" after the date picker closed.
// ─────────────────────────────────────────────────────────────

class AppDateField extends StatefulWidget {
  final String label;
  final String? value;
  final void Function(String) onChanged;
  final bool required;

  const AppDateField({
    super.key,
    required this.label,
    this.value,
    required this.onChanged,
    this.required = false,
  });

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(AppDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep controller in sync when parent pushes a new value (edit mode)
    if (oldWidget.value != widget.value && _controller.text != (widget.value ?? '')) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: _controller,
      readOnly: true,
      required: widget.required,
      suffix: const Icon(Icons.calendar_today_outlined,
          size: 18, color: AppColors.textSecondary),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: widget.value != null
              ? DateTime.tryParse(widget.value!) ?? DateTime.now()
              : DateTime.now(),
          firstDate: DateTime(1920),
          lastDate: DateTime(2100),
          locale: const Locale('ar'),
        );
        if (picked != null && mounted) {
          final formatted =
              '${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}';
          _controller.text = formatted;
          widget.onChanged(formatted);
        }
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STATUS CHIPS
// ═══════════════════════════════════════════════════════════════

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class InvoiceStatusChip extends StatelessWidget {
  final String status;
  const InvoiceStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'paid' => ('مدفوعة', AppColors.paid),
      'partial' => ('جزئية', AppColors.partial),
      'unpaid' => ('غير مدفوعة', AppColors.unpaid),
      'cancelled' => ('ملغاة', AppColors.cancelled),
      _ => (status, AppColors.textHint),
    };
    return StatusChip(label: label, color: color);
  }
}

class AppointmentStatusChip extends StatelessWidget {
  final String status;
  const AppointmentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('قيد الانتظار', AppColors.warning),
      'confirmed' => ('مؤكد', AppColors.success),
      'cancelled' => ('ملغي', AppColors.error),
      'completed' => ('مكتمل', AppColors.primary),
      _ => (status, AppColors.textHint),
    };
    return StatusChip(label: label, color: color);
  }
}

// ═══════════════════════════════════════════════════════════════
// TABLES
// ═══════════════════════════════════════════════════════════════

class AppTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<double>? columnWidths;

  const AppTable({super.key, required this.headers, required this.rows, this.columnWidths});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.card,
          child: Column(
            children: [
              Container(
                color: AppColors.primarySurface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildRow(
                  headers
                      .map((h) => Text(h,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)))
                      .toList(),
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final isEven = entry.key.isEven;
                return Container(
                  color: isEven ? Colors.transparent : AppColors.borderLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _buildRow(entry.value),
                );
              }),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('لا توجد بيانات',
                        style: TextStyle(color: AppColors.textHint)),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildRow(List<Widget> cells) => Row(
        children: cells.asMap().entries.map((e) {
          final width =
              columnWidths != null && e.key < columnWidths!.length ? columnWidths![e.key] : null;
          return width != null ? SizedBox(width: width, child: e.value) : Expanded(child: e.value);
        }).toList(),
      );
}

// ═══════════════════════════════════════════════════════════════
// MISC
// ═══════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (action != null) action!,
        ],
      );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.textHint),
              const SizedBox(height: AppSpacing.md),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(label: 'إعادة المحاولة', onPressed: onRetry),
            ],
          ],
        ),
      );
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDanger;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'تأكيد',
    this.isDanger = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        isDanger: isDanger,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          isDanger
              ? DangerButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                )
              : PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
        ],
      );
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.error : AppColors.textPrimary,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ));
}
