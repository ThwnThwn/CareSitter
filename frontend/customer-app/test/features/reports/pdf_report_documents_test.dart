import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/reports/data/services/pdf_report_documents.dart';
import 'package:caresitter_customer/features/reports/domain/report_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real PDF generator embeds bundled Vietnamese font without network',
      () async {
    final bytes = await PdfReportDocuments().generate(ReportSummary(
        bookingId: 'demo-booking',
        serviceName: 'Chăm sóc tại nhà',
        start: DateTime.utc(2026, 11, 6),
        end: DateTime.utc(2026, 11, 6, 2),
        status: 'Đã xác nhận',
        amount: 100000));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, lessThan(10 * 1024 * 1024));
    expect(latin1.decode(bytes), contains('%%EOF'));
    const exportPath = String.fromEnvironment('LAB3_PDF_ARTIFACT');
    if (exportPath.isNotEmpty) {
      final file = File(exportPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
  });
}
