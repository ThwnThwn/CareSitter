import 'meal_feedback_model.dart';

class MealFeedbackListModel {
  const MealFeedbackListModel(this.items, this.healthRevision);
  final List<MealFeedbackModel> items;
  final int healthRevision;
  factory MealFeedbackListModel.fromJson(Map<String, dynamic> json) =>
      MealFeedbackListModel(
          (json['items'] as List)
              .map((item) => MealFeedbackModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList(),
          (json['healthRevision'] as num).toInt());
}
