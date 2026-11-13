import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_daily_macros.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_nutrient_total.dart';

void main() {
  test('daily totals reject absent and invalid contributions', () {
    expect(NutritionNutrientTotal.sum([12.5, 10, 0]), 22.5);
    expect(NutritionNutrientTotal.sum([]), isNull);
    expect(NutritionNutrientTotal.sum([12.5, null]), isNull);
    expect(NutritionNutrientTotal.sum([12.5, -1]), isNull);
    expect(NutritionNutrientTotal.sum([double.nan]), isNull);
    expect(NutritionNutrientTotal.sum([double.infinity]), isNull);
  });

  testWidgets(
      'calculation discloses actual dish contributions and recalculates',
      (tester) async {
    Future<void> show(num rice) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
          body: SingleChildScrollView(
              child: NutritionDailyMacros(meals: [
            NutritionMealModel.fromJson({
              'name': 'Cháo',
              'nutrients': {'protein_g': 12.5}
            }),
            NutritionMealModel.fromJson({
              'name': 'Cơm',
              'nutrients': {'protein_g': rice}
            }),
          ])),
        )));
    await show(10);
    await tester.tap(find.text('Cách tính'));
    await tester.pumpAndSettle();
    expect(find.text('Cháo: 12.5 g'), findsOneWidget);
    expect(find.text('Cơm: 10 g'), findsOneWidget);
    expect(find.text('12.5 + 10 = 22.5 g'), findsOneWidget);
    await show(20);
    await tester.pumpAndSettle();
    expect(find.text('12.5 + 20 = 32.5 g'), findsOneWidget);
    expect(find.text('12.5 + 10 = 22.5 g'), findsNothing);
  });

  NutritionMealModel meal(Map<String, dynamic> nutrients) =>
      NutritionMealModel.fromJson({'nutrients': nutrients});

  testWidgets('daily macros sum actual values and retain a true zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NutritionDailyMacros(
      meals: [
        meal({'protein_g': 12.5, 'carbohydrate_g': 20, 'fat_g': 0}),
        meal({'protein_g': 10, 'carbohydrate_g': 30, 'fat_g': 0})
      ],
    ))));
    expect(find.text('22.5 g'), findsOneWidget);
    expect(find.text('50 g'), findsOneWidget);
    expect(find.text('0 g'), findsOneWidget);
  });

  testWidgets('missing values do not become zero or a partial daily total',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NutritionDailyMacros(
      meals: [
        meal({'protein_g': 12.5}),
        meal({})
      ],
    ))));
    expect(find.text('Chưa đủ dữ liệu'), findsNWidgets(3));
    expect(find.text('12.5 g'), findsNothing);
    expect(find.text('0 g'), findsNothing);
  });

  testWidgets('daily macros fit narrow screens with large accessibility text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: SingleChildScrollView(
              child: NutritionDailyMacros(
        meals: [
          meal({'protein_g': 20})
        ],
      ))),
    )));
    expect(tester.takeException(), isNull);
  });
}
