import '../../data/models/health_profile_model.dart';
import '../../data/models/nutrition_resource_model.dart';

class NutritionSnapshot {
  const NutritionSnapshot({this.health, this.resource});
  final HealthProfileModel? health;
  final NutritionResourceModel? resource;
}
