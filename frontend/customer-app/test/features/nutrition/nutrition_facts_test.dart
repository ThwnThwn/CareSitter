import 'package:caresitter_customer/features/nutrition/data/models/nutrition_decision_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_result_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/widgets/nutrition_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('questions and fact evidence remain readable at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final decision = NutritionDecisionModel.fromJson({
      'state': 'needs_information',
      'missingFields': ['foodAllergyStatus'],
      'conflicts': [],
      'questions': [
        {
          'id': 'food-allergy-status.v1',
          'sourceField': 'foodAllergyStatus',
          'inputType': 'single_choice',
          'options': ['reported_none', 'reported_present', 'unknown'],
          'required': true,
          'purpose': 'confirm_food_allergy_status'
        }
      ]
    });
    final data = NutritionResultModel.fromJson({
      'facts': [
        {
          'label': 'Tăng huyết áp',
          'sourceKey': 'generalNote',
          'quote': 'đang bị tăng huyết áp',
          'subject': 'beneficiary',
          'assertion': 'present',
          'temporality': 'current'
        }
      ]
    });

    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: NutritionFacts(
                    decision: decision,
                    data: data,
                    state: 'needs_information')))));

    expect(find.text('Điểm cần làm rõ'), findsOneWidget);
    expect(find.text('Người được hỗ trợ có dị ứng thực phẩm không?'),
        findsOneWidget);
    expect(find.textContaining('đang bị tăng huyết áp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
