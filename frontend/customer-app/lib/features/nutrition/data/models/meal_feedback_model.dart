class MealFeedbackModel {
  const MealFeedbackModel(
      {required this.id,
      required this.recipeVersionId,
      required this.mealName,
      required this.feedback,
      required this.status,
      required this.submittedByRole});
  final String id, recipeVersionId, mealName, feedback, status, submittedByRole;
  factory MealFeedbackModel.fromJson(Map<String, dynamic> json) =>
      MealFeedbackModel(
          id: json['id'] as String,
          recipeVersionId: json['recipeVersionId'] as String,
          mealName: json['mealName'] as String,
          feedback: json['feedback'] as String,
          status: json['status'] as String,
          submittedByRole: json['submittedByRole'] as String);
}
