// lib/core/utils/date_utils.dart

import 'package:intl/intl.dart';

class ClinicDateUtils {
  ClinicDateUtils._();

  static const List<String> _levantineMonthNames = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  static String toDbDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static String toDbDateTime(DateTime dt) => dt.toIso8601String();

  static DateTime fromDbDate(String s) => DateTime.parse(s);

  static String todayString() => toDbDate(DateTime.now());

  static String formatArabicMonth(DateTime dt, String pattern) {
    final formatted = DateFormat(pattern, 'ar').format(dt);
    final originalMonth = DateFormat('MMMM', 'ar').format(dt);
    return formatted.replaceFirst(
        originalMonth, _levantineMonthNames[dt.month - 1]);
  }

  static String currentMonthStart() {
    final now = DateTime.now();
    return toDbDate(DateTime(now.year, now.month, 1));
  }

  static String currentMonthEnd() {
    final now = DateTime.now();
    return toDbDate(DateTime(now.year, now.month + 1, 0));
  }

  static String yearStart(int year) => '$year-01-01';
  static String yearEnd(int year) => '$year-12-31';
}
