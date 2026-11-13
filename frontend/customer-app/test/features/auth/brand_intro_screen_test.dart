import 'package:caresitter_customer/features/auth/presentation/screens/brand_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand asset animates in and intro completes after its reveal',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntroScreen(onFinished: () => finished = true),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<Image>(
            find.byKey(const ValueKey('caresitter-logo-image')),
          )
          .image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/images/logo.png',
      ),
    );
    expect(find.byKey(const ValueKey('caresitter-logo-name')), findsOneWidget);
    expect(finished, isFalse);

    await tester.pumpAndSettle();
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
