import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hover resets on exit and pointer and keyboard activate once',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: HomeHoverButton(
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48, child: Text('Book')),
          ),
        ),
      ),
    ));
    final button = find.byType(HomeHoverButton);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pumpAndSettle();
    expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.015);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 3);
    await mouse.removePointer();
  });

  testWidgets('reduced motion preserves hover feedback without scaling',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: HomeHoverButton(
            onTap: () {},
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      ),
    ));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(300, 300));
    await mouse.moveTo(tester.getCenter(find.byType(HomeHoverButton)));
    await tester.pumpAndSettle();
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    final container =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((container.foregroundDecoration! as BoxDecoration).color!.a,
        greaterThan(0));
    await mouse.removePointer();
  });
}
