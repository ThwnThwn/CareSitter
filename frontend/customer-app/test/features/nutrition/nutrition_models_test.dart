import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/recipe_option_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_response_rules.dart';

void main() {
  test(
      'typed meal and decision retain unknown server fields in their snapshots',
      () {
    final resource = NutritionResourceModel.fromJson({
      'id': 'plan',
      'status': 'saved',
      'futureField': 'kept',
      'data': {
        'decision': {
          'state': 'suggested',
          'missingFields': ['foodAllergyStatus'],
          'extraDecision': 7
        },
        'meals': [
          {
            'mealType': 'lunch',
            'name': 'Món đã duyệt',
            'servings': 1,
            'ingredients': [
              {
                'name': 'Nguyên liệu',
                'amount': 20,
                'unit': 'g',
                'basis': 'cooked'
              }
            ],
            'extraMeal': true
          }
        ],
        'unknownResult': {'keep': true},
      },
    });
    expect(resource.result.decision.state, 'suggested');
    expect(resource.result.decision.missingFields, ['foodAllergyStatus']);
    expect(resource.result.meals.single.ingredients.single.amount, 20);
    expect(resource.result.meals.single.toJson()['extraMeal'], isTrue);
    expect(resource.result.toJson()['unknownResult'], {'keep': true});
    expect(resource.toJson()['futureField'], 'kept');
  });
  test(
      'options and saved plans expose their IDs without flattening nested data',
      () {
    final option = RecipeOptionModel.fromJson(
        {'versionId': 'recipe-v2', 'servings': 2, 'future': true});
    final plan = MealPlanSummaryModel.fromJson({
      'id': 'plan',
      'status': 'stale',
      'data': {'plannedDate': '2026-10-15', 'other': 3}
    });
    expect(option.versionId, 'recipe-v2');
    expect(option.toJson()['future'], isTrue);
    expect(plan.plannedDate, '2026-10-15');
    expect(plan.toJson()['data'], {'plannedDate': '2026-10-15', 'other': 3});
  });
  test('profile conflicts are stale while lost ownership clears content', () {
    expect(
        NutritionResponseRules.stale(409, 'nutrition.profile_changed'), isTrue);
    expect(NutritionResponseRules.stale(503, 'nutrition.profile_changed'),
        isFalse);
    expect(NutritionResponseRules.denied(404), isTrue);
    expect(NutritionResponseRules.denied(503), isFalse);
  });
}
