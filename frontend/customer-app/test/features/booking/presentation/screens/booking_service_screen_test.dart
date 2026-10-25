import 'dart:io';
import 'dart:ui' as ui;

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_selectors.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_state.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_wizard_screen.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _services = [
  ServiceModel(
    id: 'essential',
    code: 'NONMED_ESSENTIAL',
    name: 'Hỗ trợ thiết yếu',
    description:
        'Hỗ trợ vệ sinh cá nhân, thay đồ, chuẩn bị bữa ăn và nhắc lịch sinh hoạt.',
    defaultDurationMinutes: 120,
    baseHourlyPrice: 90000,
  ),
  ServiceModel(
    id: 'companion',
    code: 'NONMED_COMPANION',
    name: 'Đồng hành linh hoạt',
    description: 'Trò chuyện, tản bộ, đi chợ hoặc đồng hành đến cuộc hẹn.',
    defaultDurationMinutes: 240,
    baseHourlyPrice: 80000,
  ),
  ServiceModel(
    id: 'day',
    code: 'NONMED_DAY',
    name: 'Chăm sóc ban ngày',
    description:
        'Hỗ trợ sinh hoạt trong ngày, bữa ăn, vận động nhẹ và giữ không gian an toàn.',
    defaultDurationMinutes: 480,
    baseHourlyPrice: 70000,
  ),
  ServiceModel(
    id: 'night',
    code: 'NONMED_NIGHT',
    name: 'Hỗ trợ ban đêm',
    description: 'Túc trực ban đêm, hỗ trợ đi vệ sinh và di chuyển an toàn.',
    defaultDurationMinutes: 480,
    baseHourlyPrice: 85000,
  ),
];

void main() {
  setUpAll(() async {
    final fontLoader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await fontLoader.load();
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('màn chọn dịch vụ khớp bố cục Stitch ở width=$width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingWizardProvider.overrideWith(_PreviewWizard.new),
            wizardCanContinueProvider.overrideWith(
              (ref, args) =>
                  ref.watch(bookingWizardProvider(args)).serviceId != null,
            ),
            serviceStoreProvider.overrideWith(_PreviewServices.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepaintBoundary(
              key: boundaryKey,
              child: const BookingWizardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đặt lịch hỗ trợ'), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);
      expect(find.text('Chọn dịch vụ cần đặt'), findsOneWidget);
      expect(find.text('Hỗ trợ thiết yếu'), findsOneWidget);
      expect(find.text('Hỗ trợ ban đêm'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Đồng hành linh hoạt'));
      await tester.pumpAndSettle();
      final nextButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Tiếp theo'),
      );
      expect(nextButton.onPressed, isNotNull);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (width == 390 &&
          Platform.environment['CARESITTER_CAPTURE_BOOKING_SERVICE_UI'] ==
              '1') {
        await tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/booking-service-stitch.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    });
  }
}

class _PreviewWizard extends BookingWizardController {
  @override
  BookingWizardState build(BookingWizardArgs arg) =>
      const BookingWizardState(initialResolved: true);
}

class _PreviewServices extends ServiceStore {
  @override
  Future<List<ServiceModel>> build() async => _services;
}
