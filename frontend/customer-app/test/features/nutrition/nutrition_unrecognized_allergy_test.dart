import 'package:caresitter_customer/features/nutrition/data/models/nutrition_decision_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_result_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the allergy the backend could not recognize',
      (tester) async {
    final decision = NutritionDecisionModel.fromJson({
      'missingFields': ['allergies/1'],
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NutritionFacts(
      decision: decision,
      data: NutritionResultModel.fromJson({}),
      state: 'needs_information',
      health: const {
        'allergies': ['Tôm', 'Bò']
      },
    ))));
    expect(
        find.textContaining('Chưa nhận diện được dị ứng “Bò”'), findsOneWidget);
    expect(find.textContaining('chưa thể gợi ý thực đơn'), findsOneWidget);
  });
}
