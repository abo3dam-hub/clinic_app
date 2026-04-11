// lib/core/providers/export_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';

final pdfExportServiceProvider = Provider<PdfExportService>((ref) =>
    PdfExportService(clinicName: 'عيادتي'));

final excelExportServiceProvider = Provider<ExcelExportService>((ref) =>
    ExcelExportService(clinicName: 'عيادتي'));
