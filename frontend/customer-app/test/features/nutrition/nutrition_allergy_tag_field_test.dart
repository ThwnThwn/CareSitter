import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_allergy_tag_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('comma and semicolon create separate removable allergy tags',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var value = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NutritionAllergyTagField(
            controller: controller,
            enabled: true,
            maxLength: 1000,
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('nutrition-allergies-input')),
      'Tôm, Bò;',
    );
    await tester.pump();

    expect(find.text('Tôm'), findsOneWidget);
    expect(find.text('Bò'), findsOneWidget);
    expect(value, 'Tôm; Bò');
    expect(controller.text, 'Tôm; Bò');

    await tester.tap(find.byTooltip('Xoá Tôm'));
    await tester.pump();

    expect(find.text('Tôm'), findsNothing);
    expect(find.text('Bò'), findsOneWidget);
    expect(value, 'Bò');
  });
}
