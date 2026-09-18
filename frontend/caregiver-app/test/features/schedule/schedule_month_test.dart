import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/schedule/presentation/screens/schedule_screen.dart';

void main() {
  testWidgets('Month view renders without overflow', (tester) async {
    // iPhone SE-ish small screen — nơi overflow dễ lộ nhất
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Bật chế độ xem tháng: chạm icon calendar_month
    final monthToggle = find.byIcon(Icons.calendar_month_rounded);
    expect(monthToggle, findsWidgets);
    await tester.tap(monthToggle.first);
    await tester.pump(const Duration(milliseconds: 400));

    // Nếu có RenderFlex overflow, tester.takeException sẽ trả về lỗi
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'Month view bị overflow: $exception');
  });
}
