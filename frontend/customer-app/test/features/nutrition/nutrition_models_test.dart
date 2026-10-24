import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_decision_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/recipe_option_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_response_rules.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_error_codes.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_error_copy.dart';

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
          'allowedActions': ['replace', 'save'],
          'questions': [
            {
              'id': 'food-allergy-status.v1',
              'sourceField': 'foodAllergyStatus',
              'inputType': 'single_choice',
              'options': ['reported_none', 'reported_present', 'unknown'],
              'required': true,
              'purpose': 'confirm_food_allergy_status'
            }
          ],
          'extraDecision': 7
        },
        'meals': [
          {
            'mealType': 'lunch',
            'name': 'Món đã duyệt',
            'imageUrl':
                'https://res.cloudinary.com/demo/image/upload/lunch.jpg',
            'imageAlt': 'Ảnh món ăn cho bữa trưa',
            'servings': 1,
            'nutrients': {'energy_kcal': 412.5},
            'ingredients': [
              {
                'name': 'Nguyên liệu',
                'amount': 20,
                'unit': 'g',
                'basis': 'cooked'
              }
            ],
            'sources': ['NIN_CLINICAL_NUTRITION_2019'],
            'sourceDetails': [
              {
                'id': 'NIN_CLINICAL_NUTRITION_2019',
                'title': 'Dinh dưỡng lâm sàng',
                'organization': 'Viện Dinh dưỡng',
                'year': 2019,
                'locator': 'Nguyên tắc tính khẩu phần',
                'reference': 'book/dinh-duong-lam-sang.pdf',
                'verifiedOn': '2026-10-16',
                'futureSourceField': true
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
    expect(resource.result.decision.allows('save'), isTrue);
    expect(resource.result.decision.allows('retry'), isFalse);
    expect(
        resource.result.decision.questions.single.id, 'food-allergy-status.v1');
    expect(resource.result.decision.questions.single.options,
        ['reported_none', 'reported_present', 'unknown']);
    expect(resource.result.meals.single.ingredients.single.amount, 20);
    expect(resource.result.meals.single.imageUrl,
        'https://res.cloudinary.com/demo/image/upload/lunch.jpg');
    expect(resource.result.meals.single.imageAlt, 'Ảnh món ăn cho bữa trưa');
    expect(resource.result.meals.single.energyKcal, 412.5);
    expect(resource.result.meals.single.sourceDetails.single.title,
        'Dinh dưỡng lâm sàng');
    expect(resource.result.meals.single.sourceDetails.single.year, 2019);
    expect(resource.result.meals.single.sourceDetails.single.verifiedOn,
        DateTime(2026, 10, 16));
    expect(
        resource.result.meals.single.sourceDetails.single
            .toJson()['futureSourceField'],
        isTrue);
    expect(resource.result.meals.single.toJson()['extraMeal'], isTrue);
    expect(resource.result.toJson()['unknownResult'], {'keep': true});
    expect(resource.toJson()['futureField'], 'kept');
  });

  test('legacy decisions without allowed actions retain state-based controls',
      () {
    final legacy = NutritionDecisionModel.fromJson({'state': 'eligible'});
    final explicitlyBlocked = NutritionDecisionModel.fromJson(
        {'state': 'eligible', 'allowedActions': <String>[]});

    expect(legacy.allows('recommend'), isTrue);
    expect(legacy.allows('save'), isFalse);
    expect(
        NutritionDecisionModel.fromJson({'state': 'future_state'})
            .allows('recommend'),
        isFalse);
    expect(explicitlyBlocked.allows('recommend'), isFalse);
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
  test(
      'AI failures explain configuration, credential and availability separately',
      () {
    expect(
        NutritionErrorCopy.failedAssessment(
            NutritionErrorCodes.aiNotConfigured),
        contains('chưa được bật hoặc thiếu API key'));
    expect(
        NutritionErrorCopy.failedAssessment(
            NutritionErrorCodes.aiAuthenticationFailed),
        contains('API key của dịch vụ AI không hợp lệ'));
    expect(
        NutritionErrorCopy.failedAssessment(
            NutritionErrorCodes.aiConfigurationInvalid),
        contains('model hoặc endpoint AI không hợp lệ'));
    expect(
        NutritionErrorCopy.failedAssessment(NutritionErrorCodes.aiUnavailable),
        contains('Không kết nối được dịch vụ AI'));
  });
}
