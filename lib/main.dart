// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Warm up the database (creates tables if needed)
  await DatabaseHelper.instance.database;

  runApp(
    const ProviderScope(
      child: ClinicApp(),
    ),
  );
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'نظام إدارة العيادة',
      debugShowCheckedModeBanner: false,

      // Arabic RTL
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: AppTheme.light,
      routerConfig: appRouter,

      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
