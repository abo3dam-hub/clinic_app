// lib/core/services/backup_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';

enum BackupResult { success, failed, restored }

class BackupInfo {
  final String path;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupInfo({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get fileName => p.basename(path);

  String get formattedSize {
    if (sizeBytes < 1024)          return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)   return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupService {
  final DatabaseHelper _db;

  BackupService(this._db);

  // ─── Manual Backup ────────────────────────────────────────────

  /// Back up the database to [destinationDir].
  /// Returns the full path of the created backup file.
  Future<String> backupTo(String destinationDir) async {
    try {
      final dir = Directory(destinationDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final timestamp = _timestamp();
      final fileName  = 'clinic_backup_$timestamp.db';
      final destPath  = p.join(destinationDir, fileName);

      await _db.backupTo(destPath);
      debugPrint('[Backup] Success → $destPath');
      return destPath;
    } catch (e) {
      debugPrint('[Backup] Failed: $e');
      rethrow;
    }
  }

  // ─── Restore ──────────────────────────────────────────────────

  /// Restore the database from [backupFilePath].
  /// ⚠️  This will replace the current database. The app should restart after.
  Future<void> restoreFrom(String backupFilePath) async {
    final src = File(backupFilePath);
    if (!src.existsSync()) {
      throw FileSystemException('ملف النسخة الاحتياطية غير موجود', backupFilePath);
    }
    await _db.restoreFrom(backupFilePath);
    debugPrint('[Backup] Restored from $backupFilePath');
  }

  // ─── Auto-backup ──────────────────────────────────────────────

  /// Creates an automatic backup in the default auto-backup folder
  /// next to the executable. Keeps only the last [keepCount] backups.
  Future<String?> autoBackup({int keepCount = 7}) async {
    try {
      final autoDir = _autoBackupDir();
      final path    = await backupTo(autoDir);
      await _pruneOldBackups(autoDir, keepCount: keepCount);
      return path;
    } catch (e) {
      debugPrint('[Backup] Auto-backup failed: $e');
      return null;
    }
  }

  // ─── List backups ─────────────────────────────────────────────

  Future<List<BackupInfo>> listBackups(String directory) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return files.map((f) => BackupInfo(
          path:       f.path,
          createdAt:  f.lastModifiedSync(),
          sizeBytes:  f.lengthSync(),
        )).toList();
  }

  Future<List<BackupInfo>> listAutoBackups() =>
      listBackups(_autoBackupDir());

  // ─── Verify backup integrity ──────────────────────────────────

  Future<bool> verifyBackup(String backupPath) async {
    try {
      // Try opening the SQLite file and running a simple query
      final file = File(backupPath);
      if (!file.existsSync()) return false;

      // Check SQLite magic header (first 16 bytes = "SQLite format 3\000")
      final bytes = await file.openRead(0, 16).first;
      const magic = [83,81,76,105,116,101,32,102,111,114,109,97,116,32,51,0];
      for (int i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Private helpers ──────────────────────────────────────────

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4,'0')}'
        '${now.month.toString().padLeft(2,'0')}'
        '${now.day.toString().padLeft(2,'0')}_'
        '${now.hour.toString().padLeft(2,'0')}'
        '${now.minute.toString().padLeft(2,'0')}';
  }

  String _autoBackupDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return p.join(exeDir, 'backups', 'auto');
  }

  Future<void> _pruneOldBackups(String dir, {required int keepCount}) async {
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    for (int i = keepCount; i < files.length; i++) {
      files[i].deleteSync();
      debugPrint('[Backup] Pruned old backup: ${files[i].path}');
    }
  }
}
