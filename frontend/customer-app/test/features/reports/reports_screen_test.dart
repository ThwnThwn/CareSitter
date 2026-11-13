import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/reports/data/models/report_receipt.dart';
import 'package:caresitter_customer/features/reports/presentation/controllers/reports_controller.dart';
import 'package:caresitter_customer/features/reports/presentation/screens/reports_screen.dart';

class Controller extends ReportsController {
  Controller(this.initial);
  final ReportState initial;
  @override
  ReportState build(String arg) => initial;
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('reports fit narrow screen and large text at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            reportsControllerProvider.overrideWith(() => Controller(
                const ReportState(phase: ReportPhase.idle, hasDocument: true))),
            reportHistoryProvider('booking')
                .overrideWith((_) async => <ReportReceipt>[]),
          ],
          child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (_, child) => MediaQuery(
                  data: MediaQueryData(
                      size: Size(width, 720),
                      textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const ReportsScreen(bookingId: 'booking'))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Trang sau'), 150);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'transport completion displays server processing without a success claim',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          reportsControllerProvider.overrideWith(() => Controller(
              const ReportState(
                  phase: ReportPhase.processing,
                  hasDocument: true,
                  progress: 1))),
          reportHistoryProvider('booking')
              .overrideWith((_) async => <ReportReceipt>[]),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ReportsScreen(bookingId: 'booking'))));
    await tester.pump();
    expect(find.text('Đã gửi tệp. Máy chủ đang lưu báo cáo…'), findsOneWidget);
    expect(find.text('Đã lưu báo cáo thành công.'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('upload-report')))
            .onPressed,
        isNull);
  });
}
