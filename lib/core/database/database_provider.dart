// lib/core/database/database_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

/// Provides the [DatabaseHelper] singleton throughout the app.
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Provides the opened [Database] instance asynchronously.
final databaseProvider = FutureProvider<Database>((ref) async {
  final helper = ref.watch(databaseHelperProvider);
  return helper.database;
});
