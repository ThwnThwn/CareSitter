import '../../data/models/health_profile_model.dart';
import '../../data/models/nutrition_resource_model.dart';

/// View tổng hợp từ cache + state của beneficiary/session; không lưu input nghiệp vụ.
class NutritionFlow {
  final HealthProfileModel? health;
  final NutritionResourceModel? resource;
  final bool loading, recommendationsEnabled;
  final String? error;
  const NutritionFlow(
      {this.health,
      this.resource,
      this.loading = false,
      this.error,
      this.recommendationsEnabled = false});
}
