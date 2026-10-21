import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('meal card surfaces an illustration and defers dense details',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NutritionMealCard(
            meal: NutritionMealModel.fromJson(const {
              'mealType': 'breakfast',
              'name': '[DEMO] Cháo gạo tẻ đậu phụ và cà chua',
              'servings': 1,
              'ingredients': [
                {
                  'name': 'Gạo tẻ',
                  'amount': 50,
                  'unit': 'g',
                  'basis': 'raw',
                },
              ],
              'preparationSteps': ['Nấu chín hoàn toàn'],
              'nutrients': {
                'energy_kcal': 270.6,
                'protein_g': 13.24,
                'fiber_g': 5.04,
              },
              'sources': [],
              'sourceDetails': [],
            }),
            loading: false,
            canReplace: true,
            onReplace: _ignore,
          ),
        ),
      ),
    ));

    expect(find.byType(Image), findsOneWidget);
    final imageRect = tester.getRect(find.byType(Image));
    final titleRect =
        tester.getRect(find.text('[DEMO] Cháo gạo tẻ đậu phụ và cà chua'));
    expect(imageRect.right, lessThan(titleRect.left));
    expect(imageRect.width, 56);
    expect(find.text('Thành phần'), findsNothing);
    expect(find.text('Chọn món thay thế'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Xem chi tiết món ăn'));
    await tester.pumpAndSettle();

    expect(find.text('Thành phần'), findsOneWidget);
    expect(find.textContaining('Gạo tẻ: 50 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal card falls back safely for large accessibility text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: NutritionMealCard(
            meal: NutritionMealModel.fromJson(const {
              'mealType': 'lunch',
              'name': 'Cơm đậu xanh, cải thìa và hành tây',
              'servings': 1,
              'ingredients': [],
              'preparationSteps': [],
              'nutrients': {'energy_kcal': 375.9, 'protein_g': 15},
              'sources': [],
              'sourceDetails': [],
            }),
            loading: false,
            canReplace: false,
            onReplace: _ignore,
          ),
        ),
      ),
    ));

    final imageRect = tester.getRect(find.byType(Image));
    final titleRect =
        tester.getRect(find.text('Cơm đậu xanh, cải thìa và hành tây'));
    expect(imageRect.right, lessThan(titleRect.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal card prefers the HTTPS image supplied by the backend',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NutritionMealCard(
          meal: NutritionMealModel.fromJson(const {
            'mealType': 'dinner',
            'name': 'Món có ảnh backend',
            'imageUrl':
                'https://res.cloudinary.com/demo/image/upload/dinner.jpg',
            'imageAlt': 'Ảnh minh hoạ món ăn cho bữa tối',
            'servings': 1,
            'ingredients': [],
            'preparationSteps': [],
            'sources': [],
            'sourceDetails': [],
          }),
          loading: false,
          canReplace: false,
          onReplace: _ignore,
        ),
      ),
    ));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(image.semanticLabel, 'Ảnh minh hoạ món ăn cho bữa tối');
  });
}

void _ignore() {}
