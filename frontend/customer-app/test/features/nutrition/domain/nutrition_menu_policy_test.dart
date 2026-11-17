import 'package:caresitter_customer/features/nutrition/domain/nutrition_menu_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const menu = [
    (mealType: 'breakfast', recipeVersionId: 'r1', name: ' Cháo Yến Mạch '),
    (mealType: 'lunch', recipeVersionId: 'r2', name: 'Cơm rau'),
    (mealType: 'dinner', recipeVersionId: 'r3', name: 'Canh bí'),
  ];

  test('complete-menu signatures ignore order, case and surrounding whitespace',
      () {
    final signature = NutritionMenuPolicy.signatures(menu)!;
    final reordered = menu.reversed
        .map((meal) => (
              mealType: meal.mealType,
              recipeVersionId: meal.recipeVersionId,
              name: meal.name.trim().toLowerCase(),
            ));
    expect(NutritionMenuPolicy.signatures(reordered), signature);
  });

  test('duplicate names remain detectable when recipe versions change', () {
    final first = NutritionMenuPolicy.signatures(menu)!;
    final changed = NutritionMenuPolicy.signatures(menu.map((meal) => (
          mealType: meal.mealType,
          recipeVersionId: '${meal.recipeVersionId}-new',
          name: meal.name,
        )))!;
    expect(changed.$1, isNot(first.$1));
    expect(changed.$2, first.$2);
  });

  test('incomplete, duplicate or unnamed meals cannot form a daily menu', () {
    for (final invalid in [
      menu.take(2),
      [menu.first, menu.first, menu.last],
      [...menu.take(2), (mealType: 'dinner', recipeVersionId: '', name: 'Canh')],
      [...menu.take(2), (mealType: 'dinner', recipeVersionId: 'r3', name: ' ')],
    ]) {
      expect(NutritionMenuPolicy.signatures(invalid), isNull);
    }
  });

  test('plan duration accepts three, five or seven days', () {
    for (final days in [3, 5, 7]) {
      expect(NutritionMenuPolicy.validDayCount(days), isTrue);
    }
    for (final days in [-1, 0, 1, 4, 8]) {
      expect(NutritionMenuPolicy.validDayCount(days), isFalse);
    }
  });

  test('calendar comparisons ignore time and retain month boundaries', () {
    final date = DateTime(2026, 12, 31, 23, 59);
    expect(NutritionMenuPolicy.dateOnly(date), DateTime(2026, 12, 31));
    expect(NutritionMenuPolicy.dateKey(date), '2026-12-31');
    expect(NutritionMenuPolicy.sameDate(date, DateTime(2026, 12, 31)), isTrue);
    expect(NutritionMenuPolicy.sameDate(date, DateTime(2027, 1, 1)), isFalse);
    expect(NutritionMenuPolicy.sameDate(null, date), isFalse);
  });
}
