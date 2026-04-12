// lib/core/services/pdf_export_service.dart
//
// Generates Arabic RTL PDFs using the `pdf` + `printing` Flutter packages.
// Fonts: uses embedded Arabic-capable font (Cairo TTF from assets).

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/reports/domain/services/report_service.dart';
import '../../features/doctors/domain/services/doctor_revenue_service.dart';

// ═══════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════

class _Pdf {
  _Pdf._();

  static final _numFmt = NumberFormat('#,##0.00', 'ar');

  // ── Color palette ────────────────────────────────────────────
  static const primary = PdfColor.fromInt(0xFF1A6B8A);
  static const secondary = PdfColor.fromInt(0xFF2CB67D);
  static const errorClr = PdfColor.fromInt(0xFFE53935);
  static const surface = PdfColor.fromInt(0xFFF7F9FC);
  static const border = PdfColor.fromInt(0xFFE2E8F0);
  static const textDark = PdfColor.fromInt(0xFF1A202C);
  static const textGrey = PdfColor.fromInt(0xFF4A5568);
  static const white = PdfColors.white;

  static pw.Font? _cairo;
  static pw.Font? _cairoBold;

  /// Load Arabic Cairo fonts from assets (call once).
  static Future<void> loadFonts() async {
    if (_cairo != null) return;
    final regular = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _cairo = pw.Font.ttf(regular);
    _cairoBold = pw.Font.ttf(bold);
  }

  static pw.TextStyle style({
    double size = 10,
    bool bold = false,
    PdfColor? color,
  }) =>
      pw.TextStyle(
        font: bold ? _cairoBold : _cairo,
        fontSize: size,
        color: color ?? textDark,
      );

  static pw.Widget header(String clinicName, String docTitle, String date) =>
      pw.Container(
        decoration: const pw.BoxDecoration(color: primary),
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(clinicName,
                    style: style(size: 16, bold: true, color: white)),
                pw.SizedBox(height: 4),
                pw.Text(date, style: style(size: 9, color: PdfColors.white)),
              ],
            ),
            pw.Text(docTitle, style: style(size: 14, bold: true, color: white)),
          ],
        ),
      );

  static pw.Widget footer(int pageNum, int totalPages) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: border, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('صفحة $pageNum من $totalPages',
                style: style(size: 8, color: textGrey)),
            pw.Text('نظام إدارة العيادة',
                style: style(size: 8, color: textGrey)),
          ],
        ),
      );

  static pw.Widget sectionTitle(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8, top: 16),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pw.BoxDecoration(
          color: surface,
          border:
              const pw.Border(right: pw.BorderSide(color: primary, width: 3)),
        ),
        child: pw.Text(title, style: style(size: 11, bold: true)),
      );

  static pw.Widget summaryCard(List<_SumRow> rows) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: border, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          children: rows
              .map((r) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(r.label,
                            style: style(
                                size: 9,
                                bold: r.bold,
                                color: r.bold ? textDark : textGrey)),
                        pw.Text(r.value,
                            style: style(
                                size: 9,
                                bold: r.bold,
                                color: r.color ?? textDark)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );

  static pw.TableRow tableHeaderRow(List<String> cols) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: primary),
        children: cols
            .map((c) => pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(c,
                      style: style(size: 9, bold: true, color: white),
                      textAlign: pw.TextAlign.center),
                ))
            .toList(),
      );

  static pw.TableRow tableDataRow(
    List<String> cells, {
    bool even = false,
    List<PdfColor?> cellColors = const [],
  }) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: even ? PdfColors.grey100 : white),
        children: cells.asMap().entries.map((e) {
          final cellColor =
              e.key < cellColors.length ? cellColors[e.key] : null;
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Text(e.value,
                style: style(size: 9, color: cellColor),
                textAlign: pw.TextAlign.center),
          );
        }).toList(),
      );

  static String fmt(double v) => '${_numFmt.format(v)} USD';
}

class _SumRow {
  final String label;
  final String value;
  final bool bold;
  final PdfColor? color;
  const _SumRow(this.label, this.value, {this.bold = false, this.color});
}

// ═══════════════════════════════════════════════════════════════
// PDF Export Service
// ═══════════════════════════════════════════════════════════════

class PdfExportService {
  final String clinicName;

  PdfExportService({this.clinicName = 'عيادتي'});

  // ─── Invoice PDF ──────────────────────────────────────────────

  Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required List<Payment> payments,
  }) async {
    await _Pdf.loadFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _Pdf._cairo!,
        bold: _Pdf._cairoBold!,
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _Pdf.header(
          clinicName,
          'فاتورة #${invoice.id}',
          invoice.invoiceDate,
        ),
        footer: (ctx) => _Pdf.footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 16),

                // ── Patient info ──────────────────────────────
                pw.Row(children: [
                  _infoChip('المريض', invoice.patientName ?? '-'),
                  pw.SizedBox(width: 16),
                  _infoChip('التاريخ', invoice.invoiceDate),
                  pw.SizedBox(width: 16),
                  _infoChip('الحالة', _statusLabel(invoice.status.value),
                      color: _statusColor(invoice.status.value)),
                ]),
                pw.SizedBox(height: 16),

                // ── Items table ───────────────────────────────
                _Pdf.sectionTitle('بنود الفاتورة'),
                pw.Table(
                  border: pw.TableBorder.all(color: _Pdf.border, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    _Pdf.tableHeaderRow(
                        ['الوصف', 'الكمية', 'السعر', 'الخصم', 'الإجمالي']),
                    ...items.asMap().entries.map((e) => _Pdf.tableDataRow(
                        [
                          e.value.description,
                          '${e.value.quantity}',
                          _Pdf.fmt(e.value.unitPrice),
                          _Pdf.fmt(e.value.discount),
                          _Pdf.fmt(e.value.total),
                        ],
                        even: e.key.isEven,
                        cellColors: [null, null, null, null, _Pdf.secondary])),
                  ],
                ),
                pw.SizedBox(height: 16),

                // ── Summary + Payments side-by-side ───────────
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Payments
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _Pdf.sectionTitle('المدفوعات'),
                          if (payments.isEmpty)
                            pw.Text('لا توجد دفعات',
                                style: _Pdf.style(color: _Pdf.textGrey))
                          else
                            pw.Table(
                              border: pw.TableBorder.all(
                                  color: _Pdf.border, width: 0.5),
                              children: [
                                _Pdf.tableHeaderRow(
                                    ['التاريخ', 'المبلغ', 'الطريقة']),
                                ...payments
                                    .asMap()
                                    .entries
                                    .map((e) => _Pdf.tableDataRow([
                                          e.value.paymentDate,
                                          _Pdf.fmt(e.value.amount),
                                          e.value.method.label,
                                        ], even: e.key.isEven)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Totals
                    pw.SizedBox(
                      width: 200,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _Pdf.sectionTitle('الإجماليات'),
                          _Pdf.summaryCard([
                            _SumRow('إجمالي الفاتورة',
                                _Pdf.fmt(invoice.totalAmount)),
                            _SumRow('الخصم', _Pdf.fmt(invoice.discount),
                                color: _Pdf.errorClr),
                            _SumRow('الصافي', _Pdf.fmt(invoice.netAmount),
                                bold: true),
                            _SumRow('المدفوع', _Pdf.fmt(invoice.paidAmount),
                                color: _Pdf.secondary),
                            _SumRow(
                                'المتبقي', _Pdf.fmt(invoice.remainingAmount),
                                bold: true,
                                color: invoice.remainingAmount > 0
                                    ? _Pdf.errorClr
                                    : _Pdf.secondary),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),

                if (invoice.notes != null) ...[
                  pw.SizedBox(height: 16),
                  _Pdf.sectionTitle('ملاحظات'),
                  pw.Text(invoice.notes!,
                      style: _Pdf.style(color: _Pdf.textGrey)),
                ],

                pw.SizedBox(height: 32),
                // Signature line
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _signatureLine('توقيع المريض'),
                      _signatureLine('توقيع المحاسب'),
                      _signatureLine('ختم العيادة'),
                    ]),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ─── Daily Report PDF ─────────────────────────────────────────

  Future<Uint8List> generateDailyReportPdf(DailyReport report) async {
    await _Pdf.loadFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _Pdf._cairo!, bold: _Pdf._cairoBold!),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _Pdf.header(clinicName, 'التقرير اليومي', report.date),
        footer: (ctx) => _Pdf.footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 16),

                // Summary cards row
                pw.Row(children: [
                  _statBox('الزيارات', '${report.totalVisits}', _Pdf.primary),
                  pw.SizedBox(width: 8),
                  _statBox('المرضى', '${report.totalPatients}', _Pdf.secondary),
                  pw.SizedBox(width: 8),
                  _statBox(
                      'الفواتير', _Pdf.fmt(report.totalInvoiced), _Pdf.primary),
                  pw.SizedBox(width: 8),
                  _statBox('المحصّل', _Pdf.fmt(report.totalCollected),
                      _Pdf.secondary),
                ]),
                pw.SizedBox(height: 8),
                pw.Row(children: [
                  _statBox('المصروفات', _Pdf.fmt(report.totalExpenses),
                      _Pdf.errorClr),
                  pw.SizedBox(width: 8),
                  _statBox('صافي الخزينة', _Pdf.fmt(report.netCash),
                      report.netCash >= 0 ? _Pdf.secondary : _Pdf.errorClr),
                ]),

                // Doctor stats
                _Pdf.sectionTitle('أداء الأطباء'),
                report.doctorStats.isEmpty
                    ? pw.Text('لا توجد زيارات',
                        style: _Pdf.style(color: _Pdf.textGrey))
                    : pw.Table(
                        border:
                            pw.TableBorder.all(color: _Pdf.border, width: 0.5),
                        children: [
                          _Pdf.tableHeaderRow([
                            'الطبيب',
                            'الزيارات',
                            'الإيرادات',
                            'العمولة',
                            'الصافي'
                          ]),
                          ...report.doctorStats.asMap().entries.map((e) {
                            final s = e.value;
                            return _Pdf.tableDataRow(
                                [
                                  s.doctorName,
                                  '${s.visits}',
                                  _Pdf.fmt(s.revenue),
                                  _Pdf.fmt(s.commission),
                                  _Pdf.fmt(s.revenue - s.commission),
                                ],
                                even: e.key.isEven,
                                cellColors: [
                                  null,
                                  null,
                                  _Pdf.secondary,
                                  _Pdf.errorClr,
                                  _Pdf.primary
                                ]);
                          }),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ─── Period Report PDF ────────────────────────────────────────

  Future<Uint8List> generatePeriodReportPdf(PeriodReport report) async {
    await _Pdf.loadFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _Pdf._cairo!, bold: _Pdf._cairoBold!),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _Pdf.header(
          clinicName,
          'تقرير الفترة',
          '${report.fromDate} — ${report.toDate}',
        ),
        footer: (ctx) => _Pdf.footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 16),

                // Summary
                _Pdf.sectionTitle('ملخص الفترة'),
                _Pdf.summaryCard([
                  _SumRow('إجمالي الزيارات', '${report.totalVisits}'),
                  _SumRow('إجمالي المرضى', '${report.totalPatients}'),
                  _SumRow('إجمالي الفواتير', _Pdf.fmt(report.totalInvoiced)),
                  _SumRow('إجمالي المحصّل', _Pdf.fmt(report.totalCollected)),
                  _SumRow('إجمالي المصروفات', _Pdf.fmt(report.totalExpenses),
                      color: _Pdf.errorClr),
                  _SumRow('صافي الربح', _Pdf.fmt(report.netProfit),
                      bold: true,
                      color: report.netProfit >= 0
                          ? _Pdf.secondary
                          : _Pdf.errorClr),
                ]),

                // Monthly breakdown
                if (report.monthlyBreakdown.isNotEmpty) ...[
                  _Pdf.sectionTitle('التفاصيل الشهرية'),
                  pw.Table(
                    border: pw.TableBorder.all(color: _Pdf.border, width: 0.5),
                    children: [
                      _Pdf.tableHeaderRow([
                        'الشهر',
                        'الزيارات',
                        'المحصّل',
                        'المصروفات',
                        'الصافي'
                      ]),
                      ...report.monthlyBreakdown.asMap().entries.map((e) {
                        final m = e.value;
                        return _Pdf.tableDataRow([
                          m.month,
                          '${m.visits}',
                          _Pdf.fmt(m.collected),
                          _Pdf.fmt(m.expenses),
                          _Pdf.fmt(m.collected - m.expenses),
                        ], even: e.key.isEven);
                      }),
                    ],
                  ),
                ],

                // Doctor performance
                if (report.doctorPerformance.isNotEmpty) ...[
                  _Pdf.sectionTitle('أداء الأطباء'),
                  pw.Table(
                    border: pw.TableBorder.all(color: _Pdf.border, width: 0.5),
                    children: [
                      _Pdf.tableHeaderRow([
                        'الطبيب',
                        'الزيارات',
                        'الإيرادات',
                        'العمولة %',
                        'العمولة',
                        'الصافي'
                      ]),
                      ...report.doctorPerformance.asMap().entries.map((e) {
                        final d = e.value;
                        return _Pdf.tableDataRow([
                          d.doctorName,
                          '${d.totalVisits}',
                          _Pdf.fmt(d.totalRevenue),
                          '${d.commissionPct.toStringAsFixed(1)}%',
                          _Pdf.fmt(d.commissionAmount),
                          _Pdf.fmt(d.netRevenue),
                        ], even: e.key.isEven);
                      }),
                    ],
                  ),
                ],

                // Top procedures
                if (report.topProcedures.isNotEmpty) ...[
                  _Pdf.sectionTitle('أكثر الإجراءات استخداماً'),
                  pw.Table(
                    border: pw.TableBorder.all(color: _Pdf.border, width: 0.5),
                    children: [
                      _Pdf.tableHeaderRow(['الإجراء', 'العدد', 'الإيرادات']),
                      ...report.topProcedures
                          .asMap()
                          .entries
                          .map((e) => _Pdf.tableDataRow([
                                e.value.procedureName,
                                '${e.value.totalCount}',
                                _Pdf.fmt(e.value.totalRevenue),
                              ], even: e.key.isEven)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ─── Doctor Revenue PDF ───────────────────────────────────────

  Future<Uint8List> generateDoctorRevenuePdf(DoctorRevenueResult result) async {
    return generateDoctorPerformanceListPdf([result], 'إيرادات الطبيب التفصيلية');
  }

  Future<Uint8List> generateDoctorPerformanceListPdf(
      List<DoctorRevenueResult> results, String title) async {
    await _Pdf.loadFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _Pdf._cairo!, bold: _Pdf._cairoBold!),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _Pdf.header(clinicName, title,
            DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())),
        footer: (ctx) => _Pdf.footer(ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(color: _Pdf.border, width: 0.5),
                  children: [
                    _Pdf.tableHeaderRow([
                      'الطبيب',
                      'الزيارات',
                      'الإيرادات',
                      'العمولة %',
                      'العمولة',
                      'الصافي'
                    ]),
                    ...results.asMap().entries.map((e) {
                      final r = e.value;
                      return _Pdf.tableDataRow([
                        r.doctorName,
                        '${r.totalVisits}',
                        _Pdf.fmt(r.grossRevenue),
                        '${r.commissionPct.toStringAsFixed(1)}%',
                        _Pdf.fmt(r.commissionAmount),
                        _Pdf.fmt(r.netRevenue),
                      ],
                          even: e.key.isEven,
                          cellColors: [
                            null,
                            null,
                            _Pdf.secondary,
                            null,
                            _Pdf.errorClr,
                            _Pdf.primary
                          ]);
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ─── Save to file ─────────────────────────────────────────────

  Future<String> saveToFile(
      Uint8List bytes, String fileName, String dir) async {
    final path = p.join(dir, fileName);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Open system print/share dialog (also allows Save as PDF).
  Future<void> printOrShare(Uint8List bytes, {String name = 'document'}) async {
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }

  // ─── Private helpers ──────────────────────────────────────────

  pw.Widget _infoChip(String label, String value, {PdfColor? color}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: pw.BoxDecoration(
          color: _Pdf.surface,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: _Pdf.border, width: 0.5),
        ),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$label: ',
                style: _Pdf.style(size: 9, color: _Pdf.textGrey)),
            pw.TextSpan(
                text: value,
                style: _Pdf.style(
                    size: 9, bold: true, color: color ?? _Pdf.textDark)),
          ]),
        ),
      );

  pw.Widget _statBox(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor(color.red, color.green, color.blue, 0.1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(
                color: PdfColor(color.red, color.green, color.blue, 0.3),
                width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: _Pdf.style(size: 8, color: _Pdf.textGrey)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: _Pdf.style(size: 11, bold: true, color: color)),
            ],
          ),
        ),
      );

  pw.Widget _signatureLine(String label) => pw.Column(
        children: [
          pw.Container(width: 120, height: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Text(label, style: _Pdf.style(size: 9, color: _Pdf.textGrey)),
        ],
      );

  String _statusLabel(String s) => switch (s) {
        'paid' => 'مدفوعة',
        'partial' => 'جزئية',
        'unpaid' => 'غير مدفوعة',
        'cancelled' => 'ملغاة',
        _ => s,
      };

  PdfColor _statusColor(String s) => switch (s) {
        'paid' => _Pdf.secondary,
        'partial' => PdfColor.fromInt(0xFFFB8C00),
        'unpaid' => _Pdf.errorClr,
        'cancelled' => _Pdf.textGrey,
        _ => _Pdf.textGrey,
      };
}
