import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_cooking_references.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'cooking reference opens the original page and discloses its scope',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    MethodCall? launch;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      launch = call;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: const Scaffold(
          body: SingleChildScrollView(
        child: NutritionCookingReferences(),
      )),
    ));
    expect(find.text('Tham khảo cách nấu'), findsOneWidget);
    expect(find.textContaining('chưa được đối chiếu với hồ sơ sức khỏe'),
        findsOneWidget);
    await tester.ensureVisible(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect((launch?.arguments as Map)['url'],
        NutritionCookingReferences.recipeUrl);
    expect((launch?.arguments as Map)['useWebView'], false);
    expect(tester.takeException(), isNull);
  });
}
