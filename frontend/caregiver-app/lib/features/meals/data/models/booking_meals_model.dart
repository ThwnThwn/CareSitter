import 'booking_meal_plan_model.dart';
import 'booking_meal_record_model.dart';

class BookingMealsModel {
  const BookingMealsModel({required this.plans, required this.records});
  final List<BookingMealPlanModel> plans;
  final List<BookingMealRecordModel> records;
  factory BookingMealsModel.fromJson(Map<String, dynamic> json) =>
      BookingMealsModel(
          plans: (json['plans'] as List<dynamic>)
              .map((item) =>
                  BookingMealPlanModel.fromJson(item as Map<String, dynamic>))
              .toList(growable: false),
          records: (json['records'] as List<dynamic>)
              .map((item) =>
                  BookingMealRecordModel.fromJson(item as Map<String, dynamic>))
              .toList(growable: false));
}
