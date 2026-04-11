// lib/shared/widgets/export_button.dart
//
// Drop-in export button used in invoices, reports, and patients screens.
// Shows a popup menu with PDF / Excel options.

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/export_providers.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/app_theme.dart';
import 'app_widgets.dart';

enum ExportFormat { pdf, excel }

class ExportButton extends ConsumerStatefulWidget {
  /// Called to get the PDF bytes when PDF is selected.
  final Future<Uint8List> Function(PdfExportService svc)? onExportPdf;

  /// Called to get the Excel bytes when Excel is selected.
  final Future<Uint8List> Function()? onExportExcel;

  /// Suggested file name (without extension).
  final String fileName;

  const ExportButton({
    super.key,
    this.onExportPdf,
    this.onExportExcel,
    this.fileName = 'export',
  });

  @override
  ConsumerState<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<ExportButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) => _loading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary),
        )
      : PopupMenuButton<ExportFormat>(
          tooltip: 'تصدير',
          offset: const Offset(0, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: _onSelected,
          itemBuilder: (_) => [
            if (widget.onExportPdf != null)
              const PopupMenuItem(
                value: ExportFormat.pdf,
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_outlined,
                      color: AppColors.error, size: 20),
                  SizedBox(width: 10),
                  Text('تصدير PDF'),
                ]),
              ),
            if (widget.onExportExcel != null)
              const PopupMenuItem(
                value: ExportFormat.excel,
                child: Row(children: [
                  Icon(Icons.table_chart_outlined,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: 10),
                  Text('تصدير Excel'),
                ]),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_outlined,
                    size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('تصدير',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        );

  Future<void> _onSelected(ExportFormat fmt) async {
    setState(() => _loading = true);
    try {
      Uint8List? bytes;
      String ext;

      if (fmt == ExportFormat.pdf) {
        final svc = ref.read(pdfExportServiceProvider);
        bytes = await widget.onExportPdf!(svc);
        ext = 'pdf';
      } else {
        bytes = await widget.onExportExcel!();
        ext = 'xlsx';
      }

      if (!mounted) return;

      // Ask user where to save
      final dir =
          await FilePicker.getDirectoryPath(dialogTitle: 'اختر مجلد الحفظ');

      if (dir == null || !mounted) return;

      final fileName = '${widget.fileName}_${_stamp()}.$ext';

      if (fmt == ExportFormat.pdf) {
        final svc = ref.read(pdfExportServiceProvider);
        final path = await svc.saveToFile(bytes, fileName, dir);
        if (mounted) showSnack(context, 'تم الحفظ: $path');
      } else {
        final svc = ref.read(excelExportServiceProvider);
        final path = await svc.saveToFile(bytes, fileName, dir);
        if (mounted) showSnack(context, 'تم الحفظ: $path');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'خطأ في التصدير: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _stamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
