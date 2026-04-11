// lib/features/settings/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

// ─── Settings repository (lightweight key-value via SQLite) ───

class SettingsRepository {
  final DatabaseHelper _db;
  SettingsRepository(this._db);

  static const _table = 'app_settings';

  Future<void> _ensureTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<String?> get(String key) async {
    await _ensureTable();
    final rows = await _db.query(_table,
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    await _ensureTable();
    final db = await _db.database;
    await db.execute(
        'INSERT OR REPLACE INTO $_table (key, value) VALUES (?, ?)',
        [key, value]);
  }

  Future<Map<String, String>> getAll() async {
    await _ensureTable();
    final rows = await _db.query(_table);
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }
}

// ─── Providers ────────────────────────────────────────────────

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) =>
    SettingsRepository(ref.watch(databaseHelperProvider)));

final settingsProvider = FutureProvider<Map<String, String>>((ref) =>
    ref.watch(settingsRepositoryProvider).getAll());

// ─── Screen ───────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _clinicNameCtrl  = TextEditingController();
  final _clinicPhoneCtrl = TextEditingController();
  final _clinicAddrCtrl  = TextEditingController();
  final _doctorNameCtrl  = TextEditingController();
  bool _loading = false;
  bool _saved   = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _clinicNameCtrl.dispose();
    _clinicPhoneCtrl.dispose();
    _clinicAddrCtrl.dispose();
    _doctorNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(settingsRepositoryProvider);
    _clinicNameCtrl.text  = await repo.get('clinic_name')    ?? 'عيادتي';
    _clinicPhoneCtrl.text = await repo.get('clinic_phone')   ?? '';
    _clinicAddrCtrl.text  = await repo.get('clinic_address') ?? '';
    _doctorNameCtrl.text  = await repo.get('doctor_name')    ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() { _loading = true; _saved = false; });
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.set('clinic_name',    _clinicNameCtrl.text.trim());
      await repo.set('clinic_phone',   _clinicPhoneCtrl.text.trim());
      await repo.set('clinic_address', _clinicAddrCtrl.text.trim());
      await repo.set('doctor_name',    _doctorNameCtrl.text.trim());
      ref.invalidate(settingsProvider);
      setState(() => _saved = true);
      if (mounted) showSnack(context, 'تم حفظ الإعدادات');
    } catch (e) {
      if (mounted) showSnack(context, 'خطأ: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Clinic Info ──────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'بيانات العيادة'),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'اسم العيادة', required: true,
                        controller: _clinicNameCtrl,
                        prefix: const Icon(Icons.local_hospital_outlined,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(children: [
                        Expanded(child: AppTextField(
                          label: 'رقم الهاتف',
                          controller: _clinicPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          prefix: const Icon(Icons.phone_outlined,
                              size: 18, color: AppColors.textSecondary),
                        )),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: AppTextField(
                          label: 'اسم الطبيب الرئيسي',
                          controller: _doctorNameCtrl,
                          prefix: const Icon(Icons.person_outline,
                              size: 18, color: AppColors.textSecondary),
                        )),
                      ]),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'العنوان',
                        controller: _clinicAddrCtrl,
                        maxLines: 2,
                        prefix: const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── App Info ─────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'معلومات التطبيق'),
                      const SizedBox(height: AppSpacing.md),
                      const _InfoTile(icon: Icons.info_outline,
                          label: 'الإصدار',        value: '1.0.0'),
                      const _InfoTile(icon: Icons.storage_outlined,
                          label: 'قاعدة البيانات', value: 'SQLite (محلي)'),
                      const _InfoTile(icon: Icons.language,
                          label: 'اللغة',          value: 'العربية'),
                      const _InfoTile(icon: Icons.palette_outlined,
                          label: 'الثيم',          value: 'Material 3'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── DB Maintenance ───────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'صيانة قاعدة البيانات'),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'اضغط قاعدة البيانات لتقليل حجمها وتحسين الأداء.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryButton(
                        label: 'ضغط قاعدة البيانات (VACUUM)',
                        icon: Icons.compress_outlined,
                        onPressed: () => _vacuum(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Save ─────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (_saved)
                    const Row(children: [
                      Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                      SizedBox(width: 6),
                      Text('تم الحفظ',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 16),
                    ]),
                  PrimaryButton(
                    label: 'حفظ الإعدادات',
                    icon: Icons.save_outlined,
                    loading: _loading,
                    onPressed: _save,
                  ),
                ]),
              ],
            ),
          ),
        ),
      );

  Future<void> _vacuum(BuildContext ctx) async {
    final ok = await ConfirmDialog.show(ctx,
        title:   'ضغط قاعدة البيانات',
        message: 'سيتم تنظيف قاعدة البيانات وضغطها. قد يستغرق ذلك بضع ثوانٍ.');
    if (ok && ctx.mounted) {
      try {
        await ref.read(databaseHelperProvider).execute('VACUUM');
        if (ctx.mounted) showSnack(ctx, 'تمت العملية بنجاح');
      } catch (e) {
        if (ctx.mounted) showSnack(ctx, 'خطأ: $e', error: true);
      }
    }
  }
}

// ─── Info row widget ──────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ]),
      );
}
