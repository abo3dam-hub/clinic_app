// lib/core/services/excel_export_service.dart
//
// Generates structured Excel (.xlsx) files using the `excel` Flutter package.

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/patients/domain/entities/patient.dart';
import '../../features/reports/domain/services/report_service.dart';
import '../../features/doctors/domain/services/doctor_revenue_service.dart';
import '../../features/accounting/data/repositories/ledger_repository.dart';

// ═══════════════════════════════════════════════════════════════
// Shared styling helpers
// ═══════════════════════════════════════════════════════════════

class _XL {
  _XL._();

  static final _numFmt = NumberFormat('#,##0.00', 'ar');

  // ── Cell styles ──────────────────────────────────────────────

  static CellStyle get headerStyle => CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1A6B8A'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        fontSize: 11,
      );

  static CellStyle get subHeaderStyle => CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E8F4F8'),
        horizontalAlign: HorizontalAlign.Center,
        fontSize: 10,
      );

  static CellStyle get evenRowStyle => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F7F9FC'),
      );

  static CellStyle get oddRowStyle => CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

  static CellStyle get boldStyle => CellStyle(bold: true, fontSize: 11);

  static CellStyle get moneyStyle => CellStyle(
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#2CB67D'),
        horizontalAlign: HorizontalAlign.Right,
      );

  static CellStyle get errorStyle => CellStyle(
        fontColorHex: ExcelColor.fromHexString('#E53935'),
        horizontalAlign: HorizontalAlign.Right,
      );

  static CellStyle get titleStyle => CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('#1A6B8A'),
      );

  // ── Helpers ──────────────────────────────────────────────────

  static String fmt(double v) => _numFmt.format(v);

  /// Write a header row and set column widths.
  static void writeHeaders(Sheet sheet, int row, List<String> headers,
      {List<double>? widths}) {
    for (int c = 0; c < headers.length; c++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
      if (widths != null && c < widths.length) {
        sheet.setColumnWidth(c, widths[c]);
      }
    }
  }

  /// Write a data row with alternating colors.
  static void writeRow(Sheet sheet, int row, List<CellValue> values,
      {bool even = false, List<CellStyle?>? styles}) {
    final base = even ? evenRowStyle : oddRowStyle;
    for (int c = 0; c < values.length; c++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = values[c];
      final custom = styles != null && c < styles.length ? styles[c] : null;
      cell.cellStyle = custom ?? base;
    }
  }

  static void setTitle(Sheet sheet, int row, String title, int mergeUpTo) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cell.value = TextCellValue(title);
    cell.cellStyle = titleStyle;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: mergeUpTo, rowIndex: row),
    );
    sheet.setRowHeight(row, 30);
  }

  static void setInfoRow(Sheet sheet, int row, String label, String value) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(label)
      ..cellStyle = subHeaderStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = TextCellValue(value);
  }

  static void setTotalRow(Sheet sheet, int row, String label, double value,
      {bool bold = false, bool isError = false}) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(label)
      ..cellStyle = bold ? boldStyle : subHeaderStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = TextCellValue('${fmt(value)} USD')
      ..cellStyle = isError ? errorStyle : moneyStyle;
  }
}

// ═══════════════════════════════════════════════════════════════
// Excel Export Service
// ═══════════════════════════════════════════════════════════════

class ExcelExportService {
  final String clinicName;

  ExcelExportService({this.clinicName = 'Liora'});

  // ─── Patients Excel ───────────────────────────────────────────

  Future<Uint8List> generatePatientsExcel(List<Patient> patients) async {
    final excel = Excel.createExcel();
    final sheet = excel['المرضى'];
    excel.setDefaultSheet('المرضى');

    _XL.setTitle(sheet, 0, '$clinicName — قائمة المرضى', 6);
    _XL.setInfoRow(sheet, 1, 'تاريخ التصدير', _today());
    _XL.setInfoRow(sheet, 2, 'عدد المرضى', '${patients.length}');

    _XL.writeHeaders(sheet, 4,
        ['#', 'الاسم', 'الهاتف', 'البريد', 'الجنس', 'تاريخ الميلاد', 'الحالة'],
        widths: [8, 30, 18, 28, 10, 18, 12]);

    for (int i = 0; i < patients.length; i++) {
      final p = patients[i];
      _XL.writeRow(
          sheet,
          5 + i,
          [
            IntCellValue(i + 1),
            TextCellValue(p.name),
            TextCellValue(p.phone ?? '-'),
            TextCellValue(p.email ?? '-'),
            TextCellValue(_genderLabel(p.gender)),
            TextCellValue(p.birthDate ?? '-'),
            TextCellValue(p.isActive ? 'نشط' : 'غير نشط'),
          ],
          even: i.isEven);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Invoices Excel ───────────────────────────────────────────

  Future<Uint8List> generateInvoicesExcel(
    List<Invoice> invoices, {
    Map<int, List<InvoiceItem>>? itemsMap,
    Map<int, List<Payment>>? paymentsMap,
  }) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Invoices list ────────────────────────────────
    final invSheet = excel['الفواتير'];
    excel.setDefaultSheet('الفواتير');

    _XL.setTitle(invSheet, 0, '$clinicName — قائمة الفواتير', 7);
    _XL.setInfoRow(invSheet, 1, 'تاريخ التصدير', _today());

    _XL.writeHeaders(invSheet, 3, [
      '#',
      'المريض',
      'التاريخ',
      'الإجمالي',
      'الخصم',
      'الصافي',
      'المدفوع',
      'المتبقي',
      'الحالة'
    ], widths: [
      8,
      28,
      14,
      16,
      12,
      16,
      16,
      16,
      14
    ]);

    double totNet = 0, totPaid = 0, totRemain = 0;

    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      totNet += inv.netAmount;
      totPaid += inv.paidAmount;
      totRemain += inv.remainingAmount;

      _XL.writeRow(
          invSheet,
          4 + i,
          [
            IntCellValue(inv.id!),
            TextCellValue(inv.patientName ?? '-'),
            TextCellValue(inv.invoiceDate),
            TextCellValue('${_XL.fmt(inv.totalAmount)} USD'),
            TextCellValue('${_XL.fmt(inv.discount)} USD'),
            TextCellValue('${_XL.fmt(inv.netAmount)} USD'),
            TextCellValue('${_XL.fmt(inv.paidAmount)} USD'),
            TextCellValue('${_XL.fmt(inv.remainingAmount)} USD'),
            TextCellValue(_statusLabel(inv.status.value)),
          ],
          even: i.isEven);
    }

    // Totals row
    final totRow = 4 + invoices.length + 1;
    _XL.setTotalRow(invSheet, totRow, 'إجمالي الصافي', totNet, bold: true);
    _XL.setTotalRow(invSheet, totRow + 1, 'إجمالي المدفوع', totPaid);
    _XL.setTotalRow(invSheet, totRow + 2, 'إجمالي المتبقي', totRemain,
        isError: totRemain > 0);

    // ── Sheet 2: Payments ─────────────────────────────────────
    if (paymentsMap != null && paymentsMap.isNotEmpty) {
      final paySheet = excel['المدفوعات'];
      _XL.setTitle(paySheet, 0, 'تفاصيل المدفوعات', 4);
      _XL.writeHeaders(paySheet, 2,
          ['رقم الفاتورة', 'المريض', 'التاريخ', 'المبلغ', 'الطريقة'],
          widths: [14, 28, 14, 16, 14]);

      int row = 3;
      for (final entry in paymentsMap.entries) {
        final invId = entry.key;
        final inv = invoices.firstWhere((i) => i.id == invId,
            orElse: () => invoices.first);
        for (final pay in entry.value) {
          _XL.writeRow(
              paySheet,
              row,
              [
                IntCellValue(invId),
                TextCellValue(inv.patientName ?? '-'),
                TextCellValue(pay.paymentDate),
                TextCellValue('${_XL.fmt(pay.amount)} USD'),
                TextCellValue(pay.method.label),
              ],
              even: row.isEven);
          row++;
        }
      }
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Daily Report Excel ───────────────────────────────────────

  Future<Uint8List> generateDailyReportExcel(DailyReport report) async {
    final excel = Excel.createExcel();
    final sheet = excel['التقرير اليومي'];
    excel.setDefaultSheet('التقرير اليومي');

    _XL.setTitle(sheet, 0, '$clinicName — التقرير اليومي', 4);
    _XL.setInfoRow(sheet, 1, 'التاريخ', report.date);

    // Summary
    int row = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('ملخص اليوم')
      ..cellStyle = _XL.boldStyle;
    row++;

    final summaryRows = [
      ('الزيارات', '${report.totalVisits}'),
      ('عدد المرضى', '${report.totalPatients}'),
      ('إجمالي الفواتير', '${_XL.fmt(report.totalInvoiced)} USD'),
      ('المحصّل', '${_XL.fmt(report.totalCollected)} USD'),
      ('المصروفات', '${_XL.fmt(report.totalExpenses)} USD'),
      ('صافي الصندوق', '${_XL.fmt(report.netCash)} USD'),
    ];

    for (final r in summaryRows) {
      _XL.setInfoRow(sheet, row, r.$1, r.$2);
      row++;
    }

    row += 2;
    // Doctor stats
    _XL.writeHeaders(
        sheet, row, ['الطبيب', 'الزيارات', 'الإيرادات', 'العمولة', 'الصافي'],
        widths: [28, 12, 18, 16, 18]);
    row++;

    for (int i = 0; i < report.doctorStats.length; i++) {
      final s = report.doctorStats[i];
      _XL.writeRow(
          sheet,
          row,
          [
            TextCellValue(s.doctorName),
            IntCellValue(s.visits),
            TextCellValue('${_XL.fmt(s.revenue)} USD'),
            TextCellValue('${_XL.fmt(s.commission)} USD'),
            TextCellValue('${_XL.fmt(s.revenue - s.commission)} USD'),
          ],
          even: i.isEven);
      row++;
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Period Report Excel ──────────────────────────────────────

  Future<Uint8List> generatePeriodReportExcel(PeriodReport report) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Summary ──────────────────────────────────────
    final sumSheet = excel['الملخص'];
    excel.setDefaultSheet('الملخص');
    _XL.setTitle(sumSheet, 0, '$clinicName — تقرير الفترة', 3);
    _XL.setInfoRow(sumSheet, 1, 'من', report.fromDate);
    _XL.setInfoRow(sumSheet, 2, 'إلى', report.toDate);

    int row = 4;
    for (final r in [
      ('إجمالي الزيارات', '${report.totalVisits}', false, false),
      ('إجمالي المرضى', '${report.totalPatients}', false, false),
      ('إجمالي الفواتير', '${_XL.fmt(report.totalInvoiced)} USD', false, false),
      ('إجمالي المحصّل', '${_XL.fmt(report.totalCollected)} USD', false, false),
      ('إجمالي المصروفات', '${_XL.fmt(report.totalExpenses)} USD', false, true),
      (
        'صافي الربح',
        '${_XL.fmt(report.netProfit)} USD',
        true,
        report.netProfit < 0
      ),
    ]) {
      _XL.setTotalRow(sumSheet, row, r.$1,
          double.tryParse(r.$2.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
          bold: r.$3, isError: r.$4);
      row++;
    }

    // ── Sheet 2: Monthly ──────────────────────────────────────
    if (report.monthlyBreakdown.isNotEmpty) {
      final mSheet = excel['الشهري'];
      _XL.setTitle(mSheet, 0, 'التفاصيل الشهرية', 4);
      _XL.writeHeaders(
          mSheet, 2, ['الشهر', 'الزيارات', 'المحصّل', 'المصروفات', 'الصافي'],
          widths: [14, 12, 18, 18, 18]);

      for (int i = 0; i < report.monthlyBreakdown.length; i++) {
        final m = report.monthlyBreakdown[i];
        _XL.writeRow(
            mSheet,
            3 + i,
            [
              TextCellValue(m.month),
              IntCellValue(m.visits),
              TextCellValue('${_XL.fmt(m.collected)} USD'),
              TextCellValue('${_XL.fmt(m.expenses)} USD'),
              TextCellValue('${_XL.fmt(m.collected - m.expenses)} USD'),
            ],
            even: i.isEven);
      }
    }

    // ── Sheet 3: Doctors ──────────────────────────────────────
    if (report.doctorPerformance.isNotEmpty) {
      final dSheet = excel['أداء الأطباء'];
      _XL.setTitle(dSheet, 0, 'أداء الأطباء', 5);
      _XL.writeHeaders(dSheet, 2, [
        'الطبيب',
        'الزيارات',
        'الإيرادات',
        'العمولة %',
        'مبلغ العمولة',
        'الصافي'
      ], widths: [
        28,
        12,
        18,
        14,
        18,
        18
      ]);

      for (int i = 0; i < report.doctorPerformance.length; i++) {
        final d = report.doctorPerformance[i];
        _XL.writeRow(
            dSheet,
            3 + i,
            [
              TextCellValue(d.doctorName),
              IntCellValue(d.totalVisits),
              TextCellValue('${_XL.fmt(d.totalRevenue)} USD'),
              TextCellValue('${d.commissionPct.toStringAsFixed(1)}%'),
              TextCellValue('${_XL.fmt(d.commissionAmount)} USD'),
              TextCellValue('${_XL.fmt(d.netRevenue)} USD'),
            ],
            even: i.isEven);
      }
    }

    // ── Sheet 4: Top Procedures ───────────────────────────────
    if (report.topProcedures.isNotEmpty) {
      final pSheet = excel['أكثر الإجراءات'];
      _XL.setTitle(pSheet, 0, 'أكثر الإجراءات استخداماً', 2);
      _XL.writeHeaders(pSheet, 2, ['الإجراء', 'العدد', 'الإيرادات'],
          widths: [32, 12, 18]);

      for (int i = 0; i < report.topProcedures.length; i++) {
        final pr = report.topProcedures[i];
        _XL.writeRow(
            pSheet,
            3 + i,
            [
              TextCellValue(pr.procedureName),
              IntCellValue(pr.totalCount),
              TextCellValue('${_XL.fmt(pr.totalRevenue)} USD'),
            ],
            even: i.isEven);
      }
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Doctor Revenue Excel ─────────────────────────────────────

  Future<Uint8List> generateDoctorRevenueExcel(
      List<DoctorRevenueResult> doctors) async {
    final excel = Excel.createExcel();
    final sheet = excel['إيرادات الأطباء'];
    excel.setDefaultSheet('إيرادات الأطباء');

    _XL.setTitle(sheet, 0, '$clinicName — إيرادات الأطباء', 5);
    _XL.setInfoRow(sheet, 1, 'تاريخ التصدير', _today());

    _XL.writeHeaders(sheet, 3, [
      'الطبيب',
      'التخصص',
      'الزيارات',
      'الإيرادات',
      'العمولة %',
      'مبلغ العمولة',
      'الصافي'
    ], widths: [
      28,
      20,
      12,
      18,
      14,
      18,
      18
    ]);

    for (int i = 0; i < doctors.length; i++) {
      final d = doctors[i];
      _XL.writeRow(
          sheet,
          4 + i,
          [
            TextCellValue(d.doctorName),
            TextCellValue(d.specialty.isEmpty ? '-' : d.specialty),
            IntCellValue(d.totalVisits),
            TextCellValue('${_XL.fmt(d.grossRevenue)} USD'),
            TextCellValue('${d.commissionPct.toStringAsFixed(1)}%'),
            TextCellValue('${_XL.fmt(d.commissionAmount)} USD'),
            TextCellValue('${_XL.fmt(d.netRevenue)} USD'),
          ],
          even: i.isEven);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Trial Balance Excel ──────────────────────────────────────

  Future<Uint8List> generateTrialBalanceExcel({
    required List<LedgerBalance> balances,
    required String fromDate,
    required String toDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['ميزان المراجعة'];
    excel.setDefaultSheet('ميزان المراجعة');

    _XL.setTitle(sheet, 0, '$clinicName — ميزان المراجعة', 4);
    _XL.setInfoRow(sheet, 1, 'الفترة من', fromDate);
    _XL.setInfoRow(sheet, 2, 'الفترة إلى', toDate);

    _XL.writeHeaders(sheet, 4, ['الكود', 'الحساب', 'مدين', 'دائن'],
        widths: [12, 30, 18, 18]);

    double totalDr = 0, totalCr = 0;
    for (int i = 0; i < balances.length; i++) {
      final b = balances[i];
      totalDr += b.totalDebit;
      totalCr += b.totalCredit;

      _XL.writeRow(
          sheet,
          5 + i,
          [
            TextCellValue(b.account.code),
            TextCellValue(b.account.name),
            TextCellValue('${_XL.fmt(b.totalDebit)} USD'),
            TextCellValue('${_XL.fmt(b.totalCredit)} USD'),
          ],
          even: i.isEven);
    }

    final totRow = 5 + balances.length + 1;
    _XL.setTotalRow(sheet, totRow, 'الإجمالي', totalDr, bold: true);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totRow + 1))
      ..value = TextCellValue('${_XL.fmt(totalCr)} USD')
      ..cellStyle = _XL.moneyStyle;

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Income Statement Excel ───────────────────────────────────

  Future<Uint8List> generateIncomeStatementExcel(IncomeStatement pl) async {
    final excel = Excel.createExcel();
    final sheet = excel['قائمة الدخل'];
    excel.setDefaultSheet('قائمة الدخل');

    _XL.setTitle(sheet, 0, '$clinicName — قائمة الدخل', 1);
    _XL.setInfoRow(sheet, 1, 'الفترة من', pl.fromDate);
    _XL.setInfoRow(sheet, 2, 'الفترة إلى', pl.toDate);

    int row = 4;
    _XL.writeHeaders(sheet, row, ['الإيرادات', 'المبلغ'], widths: [30, 20]);
    row++;
    for (final l in pl.revenueLines) {
      _XL.writeRow(sheet, row, [
        TextCellValue(l.accountName),
        TextCellValue('${_XL.fmt(l.amount)} USD')
      ]);
      row++;
    }
    _XL.setTotalRow(sheet, row, 'إجمالي الإيرادات', pl.totalRevenue,
        bold: true);
    row += 2;

    _XL.writeHeaders(sheet, row, ['المصروفات', 'المبلغ'], widths: [30, 20]);
    row++;
    for (final l in pl.expenseLines) {
      _XL.writeRow(sheet, row, [
        TextCellValue(l.accountName),
        TextCellValue('${_XL.fmt(l.amount)} USD')
      ]);
      row++;
    }
    _XL.setTotalRow(sheet, row, 'إجمالي المصروفات', pl.totalExpenses,
        bold: true, isError: true);
    row += 2;

    _XL.setTotalRow(sheet, row,
        pl.netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة', pl.netIncome.abs(),
        bold: true, isError: pl.netIncome < 0);

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Balance Sheet Excel ──────────────────────────────────────

  Future<Uint8List> generateBalanceSheetExcel(BalanceSheet bs) async {
    final excel = Excel.createExcel();
    final sheet = excel['الميزانية العمومية'];
    excel.setDefaultSheet('الميزانية العمومية');

    _XL.setTitle(sheet, 0, '$clinicName — الميزانية العمومية', 1);
    _XL.setInfoRow(sheet, 1, 'تاريخ التقرير', bs.asOfDate);

    int row = 3;
    _XL.writeHeaders(sheet, row, ['الأصول', 'المبلغ'], widths: [30, 20]);
    row++;
    for (final l in bs.assetLines) {
      _XL.writeRow(sheet, row, [
        TextCellValue(l.accountName),
        TextCellValue('${_XL.fmt(l.amount)} USD')
      ]);
      row++;
    }
    _XL.setTotalRow(sheet, row, 'إجمالي الأصول', bs.totalAssets, bold: true);
    row += 2;

    _XL.writeHeaders(sheet, row, ['الالتزامات وحقوق الملكية', 'المبلغ'],
        widths: [30, 20]);
    row++;
    for (final l in bs.liabilityLines) {
      _XL.writeRow(sheet, row, [
        TextCellValue(l.accountName),
        TextCellValue('${_XL.fmt(l.amount)} USD')
      ]);
      row++;
    }
    for (final l in bs.equityLines) {
      _XL.writeRow(sheet, row, [
        TextCellValue(l.accountName),
        TextCellValue('${_XL.fmt(l.amount)} USD')
      ]);
      row++;
    }
    _XL.setTotalRow(sheet, row, 'صافي دخل الفترة', bs.netIncome);
    row++;
    _XL.setTotalRow(sheet, row, 'إجمالي الالتزامات وحقوق الملكية',
        bs.totalLiabilities + bs.totalEquity,
        bold: true);

    return Uint8List.fromList(excel.encode()!);
  }

  // ─── Save to file ─────────────────────────────────────────────

  Future<String> saveToFile(
      Uint8List bytes, String fileName, String dir) async {
    final path = p.join(dir, fileName);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  // ─── Helpers ─────────────────────────────────────────────────

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String _genderLabel(String? g) => switch (g) {
        'male' => 'ذكر',
        'female' => 'أنثى',
        _ => '-',
      };

  String _statusLabel(String s) => switch (s) {
        'paid' => 'مدفوعة',
        'partial' => 'جزئية',
        'unpaid' => 'غير مدفوعة',
        'cancelled' => 'ملغاة',
        _ => s,
      };
}
