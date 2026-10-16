import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_source_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_sources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    expect(find.text('Nguồn đã đối chiếu'), findsOneWidget);
    expect(find.text('Dinh dưỡng lâm sàng'), findsOneWidget);
    expect(find.text('Viện Dinh dưỡng · 2019'), findsOneWidget);
    expect(find.text('Đối chiếu ngày 16/10/2026'), findsOneWidget);
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
}
