import 'booking_meal_plan_model.dart';
import 'booking_meal_record_model.dart';

typedef BookingMealShareWindow = ({
  String beneficiaryId,
  DateTime firstDate,
  DateTime lastDate,
});

class BookingMealsModel {
  const BookingMealsModel({
    required this.plans,
    required this.records,
    this.shareWindow,
  });
  final List<BookingMealPlanModel> plans;
  final List<BookingMealRecordModel> records;
  final BookingMealShareWindow? shareWindow;

  factory BookingMealsModel.fromJson(Map<String, dynamic> json) =>
      BookingMealsModel(
          shareWindow: _shareWindow(json['shareWindow']),
          plans: (json['plans'] as List<dynamic>)
              .map((item) =>
                  BookingMealPlanModel.fromJson(item as Map<String, dynamic>))
              .toList(growable: false),
          records: (json['records'] as List<dynamic>)
              .map((item) =>
                  BookingMealRecordModel.fromJson(item as Map<String, dynamic>))
              .toList(growable: false));

  static BookingMealShareWindow? _shareWindow(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['beneficiaryId'];
    final first = DateTime.tryParse('${value['firstDate']}T00:00:00Z');
    final last = DateTime.tryParse('${value['lastDate']}T00:00:00Z');
    if (id is! String ||
        id.isEmpty ||
        first == null ||
        last == null ||
        last.isBefore(first)) {
      return null;
    }
    return (beneficiaryId: id, firstDate: first, lastDate: last);
  }
}
