typedef BookingMealIngredient = ({String name, num amount, String unit});

class BookingMealModel {
  const BookingMealModel(
      {required this.versionId,
      required this.name,
      required this.mealType,
      required this.servings,
      required this.ingredients,
      required this.preparationSteps,
      required this.allergens});
  final String versionId, name, mealType;
  final num servings;
  final List<BookingMealIngredient> ingredients;
  final List<String> preparationSteps, allergens;
  factory BookingMealModel.fromJson(Map<String, dynamic> json) =>
      BookingMealModel(
          versionId: json['versionId'] as String,
          name: json['name'] as String,
          mealType: json['mealType'] as String,
          servings: json['servings'] as num,
          ingredients: (json['ingredients'] as List<dynamic>)
              .map((item) => (
                    name: item['name'] as String,
                    amount: item['amount'] as num,
                    unit: item['unit'] as String
                  ))
              .toList(growable: false),
          preparationSteps:
              (json['preparationSteps'] as List<dynamic>).cast<String>(),
          allergens: (json['allergens'] as List<dynamic>).cast<String>());
}
