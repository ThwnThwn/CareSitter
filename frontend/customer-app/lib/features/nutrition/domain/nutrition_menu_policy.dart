/// Calendar and complete-menu rules independent of transport and presentation.
abstract final class NutritionMenuPolicy {
  static bool validDayCount(int days) => const {3, 5, 7}.contains(days);

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String dateKey(DateTime date) =>
      date.toIso8601String().split('T').first;

  static bool sameDate(DateTime? first, DateTime second) =>
      first != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static (String, String)? signatures(
      Iterable<({String mealType, String recipeVersionId, String name})> menu) {
    final meals = menu.toList()
      ..sort((a, b) => a.mealType.compareTo(b.mealType));
    if (meals.length != 3 ||
        !meals
            .map((meal) => meal.mealType)
            .toSet()
            .containsAll(const {'breakfast', 'lunch', 'dinner'}) ||
        meals.any((meal) =>
            meal.recipeVersionId.isEmpty || meal.name.trim().isEmpty)) {
      return null;
    }
    return (
      meals.map((meal) => '${meal.mealType}:${meal.recipeVersionId}').join('|'),
      meals
          .map((meal) => '${meal.mealType}:${meal.name.trim().toLowerCase()}')
          .join('|'),
    );
  }
}
