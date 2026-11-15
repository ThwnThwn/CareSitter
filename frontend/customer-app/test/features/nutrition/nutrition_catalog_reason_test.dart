import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_reasons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NutritionMealModel savedCongee({Map<String, Object?>? nutrients}) =>
    NutritionMealModel.fromJson({
      'versionId': 'saved-chicken-congee',
      'name': 'Cháo gà nấm hương',
      'mealType': 'breakfast',
      'servings': 1,
      'nutrients': nutrients ??
          {
            'energy_kcal': 304.0,
            'protein_g': 17.3,
            'carbohydrate_g': 39.6,
            'fat_g': 8.5,
          },
    });

Future<void> openReasons(WidgetTester tester,
    {NutritionRecommendationTraceModel? trace,
    NutritionMealModel? meal}) async {
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: NutritionMealReasons(
                      meal: meal ?? savedCongee(), trace: trace))))));
  await tester.tap(find.text('Vì sao chọn món này?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'saved baseline menu explains the dish when personal reasons are empty',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openReasons(tester,
        trace: NutritionRecommendationTraceModel.fromJson({
          'strategy': 'rule_baseline',
          'usedAi': false,
          'releaseStatus': 'ungrounded',
          'verifiedReasons': [],
          'explanations': [],
        }));
    expect(find.textContaining('Được gợi ý cho bữa sáng'), findsOneWidget);
    expect(find.textContaining('304 kcal'), findsOneWidget);
    expect(find.textContaining('17.3 g chất đạm'), findsOneWidget);
    expect(find.textContaining('39.6 g chất bột đường'), findsOneWidget);
    expect(find.textContaining('8.5 g chất béo'), findsOneWidget);
    expect(find.text('Chưa có lý do riêng đã xác minh cho món này.'),
        findsNothing);
    expect(find.text('Giải thích từ AI'), findsNothing);
    expect(find.textContaining('Đối chiếu hồ sơ:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing trace does not invent a selection reason',
      (tester) async {
    await openReasons(tester);
    expect(find.text('Chưa có lý do riêng đã xác minh cho món này.'),
        findsOneWidget);
    expect(find.textContaining('Được gợi ý'), findsNothing);
  });

  testWidgets(
      'manual replacement identifies family choice instead of automated selection',
      (tester) async {
    await openReasons(tester,
        trace: NutritionRecommendationTraceModel.fromJson({
          'strategy': 'rule_manual_replacement',
          'usedAi': false,
          'releaseStatus': 'ungrounded',
        }));
    expect(find.textContaining('Gia đình đã đổi sang món này'), findsOneWidget);
    expect(find.textContaining('sau bước lọc'), findsNothing);
  });

  testWidgets(
      'invalid and missing nutrient values are omitted without becoming zero',
      (tester) async {
    await openReasons(tester,
        meal: savedCongee(nutrients: {
          'energy_kcal': double.nan,
          'protein_g': -17.3,
          'fat_g': double.infinity,
        }),
        trace: NutritionRecommendationTraceModel.fromJson({
          'strategy': 'rule_baseline',
          'usedAi': false,
          'releaseStatus': 'ungrounded',
        }));
    expect(find.textContaining('Được gợi ý cho bữa sáng'), findsOneWidget);
    expect(find.textContaining('Mỗi phần cung cấp'), findsNothing);
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Infinity'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
