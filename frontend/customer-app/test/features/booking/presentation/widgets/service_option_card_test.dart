import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/service_option_card.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _service = ServiceModel(
  id: 'companion',
  code: 'NONMED_COMPANION',
  name: 'Đồng hành linh hoạt',
  description:
      'Trò chuyện, đọc sách, tản bộ, đi chợ hoặc đồng hành đến cuộc hẹn.',
  defaultDurationMinutes: 240,
  baseHourlyPrice: 80000,
);

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'thẻ dịch vụ khớp bố cục Stitch ở width=$width scale=$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var tapped = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ServiceOptionCard(
                      service: _service,
                      selected: true,
                      onTap: () => tapped = true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Đồng hành linh hoạt'), findsOneWidget);
          expect(find.text('80.000đ'), findsOneWidget);
          expect(find.text('/giờ'), findsOneWidget);
          expect(find.text('Thời lượng gợi ý: 4 giờ'), findsOneWidget);
          expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byType(ServiceOptionCard));
          expect(tapped, isTrue);
        },
      );
    }
  }

  testWidgets('thu nhỏ nhẹ khi nhấn và trở về khi thả', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ServiceOptionCard(
              service: _service,
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final card = find.byType(ServiceOptionCard);
    final scale = find.descendant(
      of: card,
      matching: find.byType(AnimatedScale),
    );

    expect(tester.widget<AnimatedScale>(scale).scale, 1);

    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 0.985);

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
  });

  testWidgets('tắt motion khi người dùng bật reduce motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ServiceOptionCard(
              service: _service,
              selected: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final card = find.byType(ServiceOptionCard);
    final scale = find.descendant(
      of: card,
      matching: find.byType(AnimatedScale),
    );
    final containers = tester.widgetList<AnimatedContainer>(
      find.descendant(of: card, matching: find.byType(AnimatedContainer)),
    );
    final switchers = tester.widgetList<AnimatedSwitcher>(
      find.descendant(of: card, matching: find.byType(AnimatedSwitcher)),
    );

    expect(tester.widget<AnimatedScale>(scale).duration, Duration.zero);
    expect(containers, isNotEmpty);
    expect(
        containers.every((widget) => widget.duration == Duration.zero), isTrue);
    expect(switchers, isNotEmpty);
    expect(
        switchers.every((widget) => widget.duration == Duration.zero), isTrue);
  });
}
