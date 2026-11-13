import 'dart:io';

import 'package:caresitter_customer/features/nutrition/domain/nutrition_disclaimer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disclaimers and versions exactly match the backend constants', () {
    final source = File('../../backend/services/nutrition/src/'
            'CareSitter.Nutrition/Application/NutritionDisclaimer.cs')
        .readAsStringSync();
    for (final entry in {
      'ReferenceVersion': NutritionDisclaimer.referenceVersion,
      'Reference': NutritionDisclaimer.reference,
      'ReviewedVersion': NutritionDisclaimer.reviewedVersion,
      'Reviewed': NutritionDisclaimer.reviewed,
    }.entries) {
      expect(source,
          contains('public const string ${entry.key} = "${entry.value}";'));
    }
  });
}
