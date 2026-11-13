import 'dart:async';

import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:caresitter_customer/features/nutrition/data/sources/nutrition_disclaimer_ack_store.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_disclaimer.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_disclaimer_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('acknowledgment is stored per user and disclaimer version',
      (tester) async {
    Widget banner(String user, String version) => ProviderScope(
            child: MaterialApp(
          home: Scaffold(
            body: NutritionDisclaimerBanner(
              userId: user,
              trace: NutritionRecommendationTraceModel.fromJson({
                'disclaimer': 'Chỉ mang tính tham khảo.',
                'disclaimerVersion': version,
              }),
            ),
          ),
        ));

    final dialogButton = find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Tôi hiểu'));

    await tester.pumpWidget(banner('user-a', 'v1'));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin tham khảo'), findsOneWidget);
    expect(dialogButton, findsOneWidget);
    expect(_tile(tester).initiallyExpanded, isTrue);
    await tester.tap(dialogButton);
    await tester.pumpAndSettle();
    expect(find.text('Thông tin tham khảo'), findsNothing);
    expect(find.text('Gợi ý chỉ mang tính tham khảo'), findsOneWidget);
    expect(_tile(tester).initiallyExpanded, isFalse);
    expect(find.text('Tôi hiểu'), findsNothing);

    await tester.pumpWidget(banner('user-a', 'v2'));
    await tester.pumpAndSettle();
    expect(dialogButton, findsOneWidget);
    await tester.tap(dialogButton);
    await tester.pumpAndSettle();
    await tester.pumpWidget(banner('user-b', 'v1'));
    await tester.pumpAndSettle();
    expect(dialogButton, findsOneWidget);
    await tester.tap(dialogButton);
    await tester.pumpAndSettle();
    await tester.pumpWidget(banner('user-a', 'v1'));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin tham khảo'), findsNothing);
    await tester.tap(find.text('Gợi ý chỉ mang tính tham khảo'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉ mang tính tham khảo.'), findsOneWidget);
  });

  testWidgets('warning remains readable at 320 px and 200% text scale',
      (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: NutritionDisclaimerBanner(userId: 'user-a'),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Gợi ý chỉ mang tính tham khảo'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('không phải tư vấn y tế')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Tôi hiểu')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Gợi ý chỉ mang tính tham khảo')),
        findsWidgets);
    await tester.tap(find.text('Gợi ý chỉ mang tính tham khảo'));
    await tester.pumpAndSettle();
    expect(find.text(NutritionDisclaimer.reference), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final user in <String?>[null, '', '  ']) {
    testWidgets('unavailable user $user has an open persistent disabled banner',
        (tester) async {
      await tester.pumpWidget(_app(user: user));
      await tester.pumpAndSettle();
      expect(_tile(tester).initiallyExpanded, isTrue);
      expect(find.text(NutritionDisclaimer.reference), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
      await tester.tap(find.text('Gợi ý chỉ mang tính tham khảo'));
      await tester.pumpAndSettle();
      expect(find.byType(NutritionDisclaimerBanner), findsOneWidget);
      expect(find.text('Gợi ý chỉ mang tính tham khảo'), findsOneWidget);
    });
  }

  testWidgets('loading stays open and storage read failure still prompts once',
      (tester) async {
    final store = _Store()..read = Completer<bool>();
    await tester.pumpWidget(_app(store: store));
    await tester.pump();
    expect(_tile(tester).initiallyExpanded, isTrue);
    expect(find.text(NutritionDisclaimer.reference), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    store.read!.completeError(StateError('read unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final modal = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(modal.dismissible, isFalse);
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, isFalse);
    await tester.tap(_dialogButton);
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.writes, [('user-a', NutritionDisclaimer.referenceVersion)]);
  });

  testWidgets(
      'write failure closes dialog and explains memory-only confirmation',
      (tester) async {
    final store = _Store()..writeError = true;
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();
    await tester.tap(_dialogButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Chưa lưu được xác nhận; lần sau sẽ hỏi lại.'),
        findsOneWidget);
    expect(_tile(tester).initiallyExpanded, isFalse);
  });

  for (final changeUser in [false, true]) {
    testWidgets(
        'changing ${changeUser ? 'user' : 'version'} with dialog open avoids old write',
        (tester) async {
      final store = _Store();
      await tester.pumpWidget(_app(store: store, version: 'v1'));
      await tester.pumpAndSettle();
      final nextUser = changeUser ? 'user-b' : 'user-a';
      final nextVersion = changeUser ? 'v1' : 'v2';
      await tester
          .pumpWidget(_app(store: store, user: nextUser, version: nextVersion));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(_dialogButton);
      await tester.pumpAndSettle();
      expect(store.writes, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(_dialogButton);
      await tester.pumpAndSettle();
      expect(store.writes, [(nextUser, nextVersion)]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(_tile(tester).initiallyExpanded, isFalse);
    });
  }

  testWidgets('trace overrides defaults and defaults override domain fallback',
      (tester) async {
    await tester.pumpWidget(_app(
        user: null,
        version: 'default-v',
        text: 'Default disclaimer',
        trace: NutritionRecommendationTraceModel.fromJson({
          'disclaimerVersion': 'trace-v',
          'disclaimer': 'Trace disclaimer',
        })));
    await tester.pumpAndSettle();
    expect(find.text('Trace disclaimer'), findsOneWidget);
    await tester.pumpWidget(
        _app(user: null, version: 'default-v', text: 'Default disclaimer'));
    await tester.pumpAndSettle();
    expect(find.text('Default disclaimer'), findsOneWidget);
  });
}

Finder get _dialogButton => find.descendant(
    of: find.byType(AlertDialog), matching: find.text('Tôi hiểu'));

ExpansionTile _tile(WidgetTester tester) =>
    tester.widget(find.byType(ExpansionTile));

Widget _app(
        {String? user = 'user-a',
        String? version,
        String? text,
        NutritionRecommendationTraceModel? trace,
        _Store? store}) =>
    ProviderScope(
      overrides: [
        if (store != null)
          nutritionDisclaimerAckStoreProvider.overrideWithValue(store)
      ],
      child: MaterialApp(
          home: Scaffold(
              body: NutritionDisclaimerBanner(
        userId: user,
        defaultVersion: version,
        defaultDisclaimer: text,
        trace: trace,
      ))),
    );

class _Store extends NutritionDisclaimerAckStore {
  Completer<bool>? read;
  bool writeError = false;
  final writes = <(String, String)>[];

  @override
  Future<bool> isAcknowledged(String userId, String version) async =>
      read == null ? false : await read!.future;

  @override
  Future<void> acknowledge(String userId, String version) async {
    writes.add((userId, version));
    if (writeError) throw StateError('write unavailable');
  }
}
