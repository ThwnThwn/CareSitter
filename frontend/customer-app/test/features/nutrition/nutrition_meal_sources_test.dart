import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_source_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_sources.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_reference_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'adapted recipes disclose origin without internal script metadata',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = NutritionSourceModel.fromJson({
      'id': 'CARESITTER_VARIETY_ADAPTATION_V2',
      'title': 'Công thức phối hợp CareSitter v2',
      'chapter': 'Bữa ăn người lớn - catalog local',
      'locator': 'backend/scripts/build-nutrition-variety-catalog.ps1',
      'verifiedOn': '2026-10-27',
    });
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(
          body: SingleChildScrollView(
              child:
                  NutritionMealSources(sourceIds: const [], sources: [source])),
        )));
    expect(find.textContaining('backend/scripts/'), findsNothing);
    expect(find.textContaining('catalog local'), findsNothing);
    expect(find.text('Công thức thử nghiệm do CareSitter xây dựng'),
        findsOneWidget);
    expect(find.textContaining('chưa gồm gia vị bổ sung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source metadata remains readable on a narrow large-text screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = NutritionSourceModel.fromJson({
      'id': 'NIN_CLINICAL_NUTRITION_2019',
      'title': 'Dinh dưỡng lâm sàng',
      'organization': 'Viện Dinh dưỡng',
      'year': 2019,
      'edition': 'Lần thứ hai',
      'chapter': 'Thực đơn ví dụ',
      'printedPages': '120-123',
      'pdfPages': '132-135',
      'locator': 'Nguyên tắc tính khẩu phần và thực đơn ví dụ.',
      'reference': 'book/Dinh_duong_lam_sang_Vien_Dinh_duong_2019.pdf',
      'verifiedOn': '2026-10-16'
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: NutritionMealSources(
            sourceIds: const ['NIN_CLINICAL_NUTRITION_2019'],
            sources: [source],
          ),
        ),
      ),
    ));

    expect(find.text('Nguồn tham khảo'), findsOneWidget);
    expect(find.text('Dinh dưỡng lâm sàng'), findsOneWidget);
    expect(find.text('Viện Dinh dưỡng · 2019'), findsOneWidget);
    expect(find.text('Ngày ghi nhận nguồn: 16/10/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy payloads still show their source identifiers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: NutritionMealSources(
          sourceIds: ['LEGACY_SOURCE'],
          sources: [],
        ),
      ),
    ));

    expect(find.text('Mã nguồn: LEGACY_SOURCE'), findsOneWidget);
  });

  testWidgets('composition data is not presented as authorship of the recipe',
      (tester) async {
    final source = NutritionSourceModel.fromJson({
      'id': 'VIETNAM_FOOD_COMPOSITION_2017',
      'title': 'Bảng thành phần thực phẩm Việt Nam 2017',
      'reference': 'https://example.org/food-composition',
      'locator': 'book/internal.pdf',
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NutritionMealSources(sourceIds: const [], sources: [source]),
    )));
    expect(find.text('Nguồn số liệu thành phần thực phẩm'), findsOneWidget);
    expect(find.textContaining('không xác nhận công thức này'), findsOneWidget);
    expect(find.text('book/internal.pdf'), findsNothing);
    expect(find.text('https://example.org/food-composition'), findsOneWidget);
  });

  testWidgets('missing source is disclosed', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NutritionMealSources(sourceIds: [], sources: [])),
    ));
    expect(find.text('Chưa có thông tin nguồn'), findsOneWidget);
  });

  testWidgets('web reference is a tappable link', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    const googleUrl = 'https://www.google.com/search?q=CareSitter';
    MethodCall? launchCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      launchCall = call;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final source = NutritionSourceModel.fromJson({
      'id': 'PUBLIC_SOURCE',
      'title': 'Nguồn công khai',
      'reference': googleUrl,
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: NutritionMealSources(sourceIds: const [], sources: [source])),
    ));

    expect(find.text(googleUrl), findsOneWidget);
    expect(
        find.ancestor(
          of: find.text(googleUrl),
          matching: find.byType(TextButton),
        ),
        findsOneWidget);
    await tester.tap(find.text(googleUrl));
    await tester.pump();
    expect(launchCall?.method, 'launch');
    expect((launchCall?.arguments as Map)['url'], googleUrl);
    expect((launchCall?.arguments as Map)['useSafariVC'], false);
    expect((launchCall?.arguments as Map)['useWebView'], false);
  });

  test('local paths and unsafe schemes stay plain text', () {
    expect(NutritionReferenceText.webUri('book/internal.pdf'), isNull);
    expect(NutritionReferenceText.webUri('file:///book/internal.pdf'), isNull);
    expect(NutritionReferenceText.webUri('javascript:alert(1)'), isNull);
    expect(NutritionReferenceText.webUri('https://user@example.org'), isNull);
    expect(NutritionReferenceText.webUri('https:///reference'), isNull);
    expect(NutritionReferenceText.webUri('https://'), isNull);
    expect(NutritionReferenceText.webUri('http://example.org/reference'),
        isNotNull);
    expect(NutritionReferenceText.webUri('https://example.org/reference'),
        isNotNull);
  });

  testWidgets('non-URL reference is ordinary text without a link',
      (tester) async {
    const reference = 'book/internal.pdf';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NutritionReferenceText(reference)),
    ));
    expect(find.text(reference), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  for (final throws in [false, true]) {
    testWidgets('launch ${throws ? 'exception' : 'false'} shows source error',
        (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (throws) throw PlatformException(code: 'unavailable');
        return false;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: NutritionReferenceText('https://example.org/reference')),
      ));
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.text('Không mở được liên kết nguồn.'), findsOneWidget);
    });
  }
}
