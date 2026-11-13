import 'package:caresitter_customer/features/nutrition/data/models/recipe_option_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_replacement_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows missing data and lets the user inspect before choosing',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? chosen;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          chosen = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => NutritionReplacementSheet(options: [
              RecipeOptionModel.fromJson(
                  {'versionId': 'recipe-1', 'name': 'Cháo bí đỏ'}),
            ]),
          );
        },
        child: const Text('Mở'),
      ),
    ))));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Khẩu phần: Chưa có dữ liệu'), findsOneWidget);
    expect(find.text('Chọn món này'), findsNothing);
    await tester.tap(find.text('Cháo bí đỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Xem chi tiết món ăn'), findsOneWidget);
    await tester.tap(find.text('Xem chi tiết món ăn'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dữ liệu'), findsWidgets);
    await tester.ensureVisible(find.text('Chọn món này'));
    await tester.tap(find.text('Chọn món này'));
    await tester.pumpAndSettle();
    expect(chosen, 'recipe-1');
    expect(tester.takeException(), isNull);
  });
}
