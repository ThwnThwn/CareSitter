import 'package:caresitter_customer/core/widgets/custom_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('greeting hand waves once and settles', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: WavingHand())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final wavingTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('home-greeting-wave')),
    );
    expect(wavingTransform.transform.entry(0, 1), isNot(0));

    await tester.pump(const Duration(seconds: 1));
    final settledTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('home-greeting-wave')),
    );
    expect(settledTransform.transform.entry(0, 1), closeTo(0, 0.0001));

    await tester.tap(find.byType(WavingHand));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final tappedTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('home-greeting-wave')),
    );
    expect(tappedTransform.transform.entry(0, 1), isNot(0));
  });

  testWidgets('reduced-motion preference keeps greeting hand still',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: WavingHand())),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Vẫy tay chào'));
    await tester.pump(const Duration(seconds: 2));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('home-greeting-wave')),
    );
    expect(transform.transform.entry(0, 1), closeTo(0, 0.0001));
  });
}
