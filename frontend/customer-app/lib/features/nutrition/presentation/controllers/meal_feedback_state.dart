import '../../data/models/nutrition_resource_model.dart';
import '../../data/models/meal_feedback_list_model.dart';

class MealFeedbackState {
  const MealFeedbackState(this.plan, this.feedback);
  final NutritionResourceModel plan;
  final MealFeedbackListModel feedback;
}
