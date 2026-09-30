import 'package:caresitter_customer/features/auth/presentation/screens/brand_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logo mark scales in and intro completes after its reveal',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntroScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final mark = tester.widget<Transform>(
      find.byKey(const ValueKey('caresitter-logo-mark-scale')),
    );
    expect(mark.transform.getMaxScaleOnAxis(), greaterThan(0.38));
    expect(find.byKey(const ValueKey('caresitter-logo-name')), findsOneWidget);
    expect(finished, isFalse);

    await tester.pump(const Duration(seconds: 2));
    expect(finished, isTrue);
  });

  testWidgets('reduced-motion setting completes without playing the animation',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: BrandIntroScreen(onFinished: () => finished = true),
        ),
      ),
    );
    await tester.pump();

    expect(finished, isTrue);
  });
}
