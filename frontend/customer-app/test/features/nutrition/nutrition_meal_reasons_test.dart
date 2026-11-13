import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_reason_copy.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_card.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_reasons.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_recommendation_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final trace = NutritionRecommendationTraceModel.fromJson({
  'verifiedReasons': [
    {
      'recipeVersionId': 'fish',
      'code': 'declared_allergy_filter',
      'detail': 'Thịt bò',
      'sourceField': 'allergies'
    },
    {
      'recipeVersionId': 'fish',
      'code': 'declared_allergy_filter',
      'detail': 'Gà',
      'sourceField': 'allergies'
    },
    {
      'recipeVersionId': 'rice',
      'code': 'declared_allergy_filter',
      'detail': 'Sữa',
      'sourceField': 'allergies'
    },
    {
      'recipeVersionId': NutritionReasonCopy.menuId,
      'code': 'goal_ranking_signal',
      'detail': 'maintain',
      'sourceField': 'healthHistory/nutrition/nutritionGoal'
    },
  ],
});
NutritionMealModel meal(String id, String name) => NutritionMealModel.fromJson(
    {'recipeVersionId': id, 'name': name, 'mealType': 'breakfast'});

void main() {
  test('AI reason rejects unknown sources, duplicate dishes and inactive AI',
      () {
    NutritionRecommendationTraceModel build(
        {bool usedAi = true,
        List<String> sources = const ['source'],
        bool duplicate = false}) {
      final explanation = {
        'recipeVersionId': 'beef',
        'summary': 'Giải thích thử',
        'evidenceIds': sources
      };
      return NutritionRecommendationTraceModel.fromJson({
        'usedAi': usedAi,
        'evidence': [
          {'id': 'source', 'title': 'Nguồn thử'}
        ],
        'explanations': [explanation, if (duplicate) explanation],
      });
    }

    final beef = meal('beef', 'Cháo bò');
    expect(NutritionReasonCopy.aiForMeal(build(), beef), isNotNull);
    expect(NutritionReasonCopy.aiForMeal(build(usedAi: false), beef), isNull);
    expect(NutritionReasonCopy.aiForMeal(build(sources: []), beef), isNull);
    expect(NutritionReasonCopy.aiForMeal(build(sources: ['missing']), beef),
        isNull);
    expect(NutritionReasonCopy.aiForMeal(build(duplicate: true), beef), isNull);
    expect(NutritionReasonCopy.aiForMeal(build(), meal('fish', 'Cháo bò')),
        isNull);
  });

  testWidgets('AI dish explanation is visible with its own referenced source',
      (tester) async {
    final aiTrace = NutritionRecommendationTraceModel.fromJson({
      'usedAi': true,
      'evidence': [
        {
          'id': 's1',
          'title': 'Vai trò của protein',
          'reference': 'Tài liệu thử',
          'printedPages': '29'
        },
      ],
      'explanations': [
        {
          'recipeVersionId': 'beef',
          'summary': 'Món cháo bổ sung đạm từ thịt bò.',
          'evidenceIds': ['s1']
        },
        {
          'recipeVersionId': 'fish',
          'summary': 'Giải thích cho món cá.',
          'evidenceIds': ['s1']
        },
      ],
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: NutritionMealReasons(
              meal: meal('beef', 'Cháo bò cà chua'), trace: aiTrace)),
    )));
    await tester.tap(find.text('Vì sao chọn món này?'));
    await tester.pumpAndSettle();
    expect(find.text('Món cháo bổ sung đạm từ thịt bò.'), findsOneWidget);
    expect(find.textContaining('Vai trò của protein'), findsOneWidget);
    expect(find.textContaining('Trang in 29'), findsOneWidget);
    expect(find.text('Giải thích cho món cá.'), findsNothing);
    expect(find.text('Chưa có lý do riêng đã xác minh cho món này.'),
        findsNothing);
  });

  test(
      'dish reasons match recipe ID, never a shared name or menu-wide criterion',
      () {
    final fish =
        NutritionReasonCopy.forMeal(trace, meal('fish', 'Tên món giống nhau'));
    final rice =
        NutritionReasonCopy.forMeal(trace, meal('rice', 'Tên món giống nhau'));
    expect(fish.length, 2);
    expect(fish.map((entry) => entry.detail).join(' '), contains('Thịt bò'));
    expect(fish.map((entry) => entry.detail).join(' '), isNot(contains('Sữa')));
    expect(rice.single.detail, contains('Sữa'));
    expect(fish.map((entry) => entry.detail).join(' '),
        isNot(contains('Mục tiêu')));
    expect(NutritionReasonCopy.forMeal(trace, meal('', 'Cháo cá')), isEmpty);
    expect(NutritionReasonCopy.forMeal(trace, meal('missing', 'Cháo cá')),
        isEmpty);
  });

  testWidgets(
      'why each dish was chosen appears inside its card with only its own checks',
      (tester) async {
    final fish = meal('fish', 'Cháo cá rô phi');
    final rice = meal('rice', 'Cơm rau');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
      NutritionRecommendationContext(trace: trace, meals: [fish, rice]),
      NutritionMealCard(
          key: const ValueKey('fish-card'),
          meal: fish,
          trace: trace,
          loading: false,
          canReplace: false,
          onReplace: () {}),
      NutritionMealCard(
          key: const ValueKey('rice-card'),
          meal: rice,
          trace: trace,
          loading: false,
          canReplace: false,
          onReplace: () {}),
    ])))));
    expect(find.text('Vì sao chọn thực đơn này?'), findsNothing);
    expect(find.text('Vì sao chọn món này?'), findsNWidgets(2));
    final fishWhy = find.descendant(
        of: find.byKey(const ValueKey('fish-card')),
        matching: find.text('Vì sao chọn món này?'));
    await tester.ensureVisible(fishWhy);
    await tester.tap(fishWhy);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('fish-card')),
            matching: find.textContaining('Thịt bò')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('fish-card')),
            matching: find.textContaining('Sữa')),
        findsNothing);
    final riceWhy = find.descendant(
        of: find.byKey(const ValueKey('rice-card')),
        matching: find.text('Vì sao chọn món này?'));
    await tester.ensureVisible(riceWhy);
    await tester.tap(riceWhy);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('rice-card')),
            matching: find.textContaining('Sữa')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('rice-card')),
            matching: find.textContaining('Thịt bò')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'missing reasons are stated without inventing claims and fit narrow large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: NutritionMealReasons(
                        meal: meal('missing', 'Cháo cá'), trace: trace))))));
    await tester.tap(find.text('Vì sao chọn món này?'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lý do riêng đã xác minh cho món này.'),
        findsOneWidget);
    expect(find.textContaining('Sữa'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
