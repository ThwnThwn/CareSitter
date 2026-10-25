import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/booking_step_indicator.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/booking_wizard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpIndicator(
    WidgetTester tester, {
    required double width,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: BookingWizardHeader(step: 4, onClose: () {}),
          body: const BookingStepIndicator(step: 4),
        ),
      ),
    );
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('căn badge bước theo mép phải ở màn hình rộng $width',
        (tester) async {
      await pumpIndicator(tester, width: width);

      final badgeTextRect = tester.getRect(find.text('5/6'));
      const expectedTrailingSpace = AppSpacing.md + AppSpacing.sm;

      expect(
        badgeTextRect.right,
        moreOrLessEquals(width - expectedTrailingSpace, epsilon: 1),
      );
      expect(find.text('Chăm sóc'), findsOneWidget);
      expect(find.text('Đồng ý'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stepper tắt transition khi bật reduce motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: BookingStepIndicator(step: 2)),
        ),
      ),
    );

    final indicator = find.byType(BookingStepIndicator);
    final scales = tester.widgetList<AnimatedScale>(
      find.descendant(of: indicator, matching: find.byType(AnimatedScale)),
    );
    final containers = tester.widgetList<AnimatedContainer>(
      find.descendant(of: indicator, matching: find.byType(AnimatedContainer)),
    );
    final switchers = tester.widgetList<AnimatedSwitcher>(
      find.descendant(of: indicator, matching: find.byType(AnimatedSwitcher)),
    );

    expect(scales.length, BookingStepIndicator.titles.length);
    expect(scales.every((widget) => widget.duration == Duration.zero), isTrue);
    expect(containers, isNotEmpty);
    expect(
        containers.every((widget) => widget.duration == Duration.zero), isTrue);
    expect(switchers, isNotEmpty);
    expect(
        switchers.every((widget) => widget.duration == Duration.zero), isTrue);
  });
}
