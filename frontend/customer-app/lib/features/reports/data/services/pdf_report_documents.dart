import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import '../../domain/report_documents.dart';
import '../../domain/report_summary.dart';

final reportDocumentsProvider =
    Provider<ReportDocuments>((_) => PdfReportDocuments());

class PdfReportDocuments implements ReportDocuments {
  @override
  Future<Uint8List> generate(ReportSummary summary) async {
    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NunitoVariable.ttf'));
    final document =
        pw.Document(title: 'Báo cáo lịch hẹn CareSitter', author: 'CareSitter');
    document.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
              pw.Header(level: 0, text: 'CareSitter — Báo cáo lịch hẹn'),
              pw.Paragraph(
                  text:
                      'Bản tổng hợp do khách hàng xuất từ thông tin lịch hẹn. '
                      'Trạng thái có thể thay đổi sau thời điểm xuất.'),
              pw.TableHelper.fromTextArray(data: <List<String>>[
                ['Nội dung', 'Thông tin'],
                ['Mã lịch hẹn', summary.bookingId],
                ['Dịch vụ', summary.serviceName],
                ['Bắt đầu (giờ Việt Nam)', _time(summary.start)],
                ['Kết thúc (giờ Việt Nam)', _time(summary.end)],
                ['Trạng thái', summary.status],
                ['Giá trị hiển thị', formatVnd(summary.amount)],
              ]),
              pw.SizedBox(height: 20),
              pw.Paragraph(
                  text:
                      'Tài liệu tổng hợp phi y tế, không thay thế hóa đơn hoặc xác nhận thanh toán. '
                      'Báo cáo riêng tư dành cho chủ tài khoản và Admin có quyền truy cập.'),
            ]));
    return document.save();
  }

  String _time(DateTime value) {
    final time = value.toUtc().add(const Duration(hours: 7));
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} ${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Future<void> preview(Uint8List bytes) async {
    await Printing.layoutPdf(
        onLayout: (_) async => bytes, name: 'caresitter-report.pdf');
  }
}
