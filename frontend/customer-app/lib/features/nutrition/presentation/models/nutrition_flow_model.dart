import '../../data/models/health_profile_model.dart';
import '../../data/models/nutrition_resource_model.dart';
import '../../domain/nutrition_personalization_rules.dart';

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

  NutritionPersonalizationReadiness get readiness {
    final profile = _nutritionProfile(health?['healthHistory']);
    return NutritionPersonalizationRules.evaluate(
      allergyStatus: health?.allergyStatus ?? 'unknown',
      allergies: health?['allergies'],
      conditionStatus: profile['conditionsStatus']?.toString() ?? 'unknown',
      chronicConditions: health?['chronicConditions'],
      medicationsStatus: profile['medicationsStatus']?.toString() ?? 'unknown',
      medications: health?['medications'],
      feedingRoute: profile['feedingRoute']?.toString() ?? 'unknown',
      swallowingStatus: profile['swallowingStatus']?.toString() ?? 'unknown',
      fluidRestriction: profile['fluidRestriction']?.toString() ?? 'unknown',
      electrolyteRestriction:
          profile['electrolyteRestriction']?.toString() ?? 'unknown',
    );
  }

  static Map<dynamic, dynamic> _nutritionProfile(Object? healthHistory) {
    if (healthHistory is Map && healthHistory['nutrition'] is Map) {
      return healthHistory['nutrition'] as Map;
    }
    return const {};
  }
}
