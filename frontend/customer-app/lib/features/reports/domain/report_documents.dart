import 'dart:typed_data';
import 'report_summary.dart';

abstract interface class ReportDocuments {
  Future<Uint8List> generate(ReportSummary summary);
  Future<void> preview(Uint8List bytes);
}
