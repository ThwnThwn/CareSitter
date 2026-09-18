import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/core/widgets/loading_list.dart';

void main() {
  testWidgets('Skeleton fits small screens and respects reduced motion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          disableAnimations: true, textScaler: TextScaler.linear(2)),
      child: Scaffold(body: LoadingList()),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('Items reached by scrolling are visible on their first frame',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
      body: FadeSlideStaggered(index: 8, child: Text('Booking ready')),
    )));
    final fades =
        tester.widgetList<FadeTransition>(find.byType(FadeTransition));
    expect(fades.every((fade) => fade.opacity.value == 1), isTrue);
    await tester.pumpAndSettle();
  });
}
