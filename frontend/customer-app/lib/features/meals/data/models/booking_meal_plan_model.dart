import 'booking_meal_model.dart';

class BookingMealPlanModel {
  const BookingMealPlanModel(
      {required this.planId,
      required this.plannedDate,
      required this.meals,
      required this.sharedAt,
      this.revokedAt,
      this.isStale = false,
      this.status = "shared"});
  final String planId, plannedDate, status;
  final bool isStale;
  bool get canUse => !isStale && revokedAt == null && status == "shared";
  final List<BookingMealModel> meals;
  final DateTime sharedAt;
  final DateTime? revokedAt;
  factory BookingMealPlanModel.fromJson(Map<String, dynamic> json) =>
      BookingMealPlanModel(
          isStale: json['isStale'] == true,
          status: json['status'] as String? ?? 'shared',
          planId: json['planId'] as String,
          plannedDate: json['plannedDate'] as String,
          meals: (json['meals'] as List<dynamic>)
              .map((item) =>
                  BookingMealModel.fromJson(item as Map<String, dynamic>))
              .toList(growable: false),
          sharedAt: DateTime.parse(json['sharedAt'] as String),
          revokedAt: DateTime.tryParse(json['revokedAt'] as String? ?? ''));
}
