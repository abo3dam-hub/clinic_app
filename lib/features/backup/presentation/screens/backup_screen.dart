// lib/features/backup/presentation/screens/backup_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _backingUp = false;
  bool _restoring = false;
  String? _lastBackupPath;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Backup card ────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'نسخ احتياطي'),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'قم بحفظ نسخة احتياطية من قاعدة البيانات في مكان آمن على جهازك.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_lastBackupPath != null)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.successSurface,
                            borderRadius: AppRadius.card,
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تم الحفظ: $_lastBackupPath',
                                style: const TextStyle(
                                    color: AppColors.success, fontSize: 13),
                              ),
                            ),
                          ]),
                        ),
                      if (_lastBackupPath != null)
                        const SizedBox(height: AppSpacing.md),
                      Row(children: [
                        PrimaryButton(
                          label: 'حفظ نسخة احتياطية',
                          icon: Icons.backup_outlined,
                          loading: _backingUp,
                          onPressed: _doBackup,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        SecondaryButton(
                          label: 'نسخ تلقائي',
                          icon: Icons.schedule_outlined,
                          onPressed: _doAutoBackup,
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Restore card ───────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'استعادة نسخة احتياطية'),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: AppRadius.card,
                        ),
                        child: const Row(children: [
                          Icon(Icons.warning_amber_outlined,
                              color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تحذير: ستحل هذه النسخة محل جميع البيانات الحالية. '
                              'تأكد من حفظ نسخة من البيانات الحالية أولاً.',
                              style: TextStyle(
                                  color: AppColors.warning, fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DangerButton(
                        label: 'استعادة من ملف',
                        icon: Icons.restore_outlined,
                        onPressed: _restoring ? null : _doRestore,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Auto backups list ──────────────────────────
                _AutoBackupsList(),
              ],
            ),
          ),
        ),
      );

  Future<void> _doBackup() async {
    final dir =
        await FilePicker.getDirectoryPath(dialogTitle: 'اختر مجلد الحفظ');
    if (dir == null || !mounted) return;

    setState(() => _backingUp = true);
    try {
      final svc = ref.read(backupServiceProvider);
      final path = await svc.backupTo(dir);
      setState(() => _lastBackupPath = path);
      if (mounted) showSnack(context, 'تم الحفظ بنجاح');
    } catch (e) {
      if (mounted) showSnack(context, 'فشل الحفظ: $e', error: true);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _doAutoBackup() async {
    setState(() => _backingUp = true);
    try {
      final path = await ref.read(backupServiceProvider).autoBackup();
      if (path != null) {
        setState(() => _lastBackupPath = path);
        if (mounted) showSnack(context, 'تم النسخ التلقائي بنجاح');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'خطأ: $e', error: true);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _doRestore() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'استعادة نسخة احتياطية',
      message: 'سيتم استبدال جميع البيانات الحالية. هل أنت متأكد؟',
      confirmLabel: 'استعادة',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;

    final result = await FilePicker.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final path = result.files.first.path!;

    // Verify file
    final valid = await ref.read(backupServiceProvider).verifyBackup(path);
    if (!valid) {
      if (mounted) showSnack(context, 'الملف المحدد غير صالح', error: true);
      return;
    }

    setState(() => _restoring = true);
    try {
      await ref.read(backupServiceProvider).restoreFrom(path);
      if (mounted) {
        showSnack(context, 'تمت الاستعادة. أعد تشغيل التطبيق.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'فشلت الاستعادة: $e', error: true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────

class _AutoBackupsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(backupServiceProvider);
    return FutureBuilder(
      future: svc.listAutoBackups(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final backups = snap.data!;
        if (backups.isEmpty) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'النسخ التلقائية المحفوظة'),
              const SizedBox(height: AppSpacing.md),
              ...backups.map((b) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: AppColors.divider))),
                    child: Row(children: [
                      const Icon(Icons.storage_outlined,
                          color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.fileName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                              '${b.formattedSize} · '
                              '${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year}',
                              style: const TextStyle(
                                  color: AppColors.textHint, fontSize: 12)),
                        ],
                      )),
                    ]),
                  )),
            ],
          ),
        );
      },
    );
  }
}
