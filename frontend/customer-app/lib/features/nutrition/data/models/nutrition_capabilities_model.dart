class NutritionCapabilitiesModel {
  const NutritionCapabilitiesModel(
      {required this.enabled,
      required this.assessmentsEnabled,
      required this.recommendationsEnabled});
  final bool enabled, assessmentsEnabled, recommendationsEnabled;
  factory NutritionCapabilitiesModel.fromJson(Map<String, dynamic> json) =>
      NutritionCapabilitiesModel(
          enabled: json['enabled'] == true,
          assessmentsEnabled: json['assessmentsEnabled'] == true,
          recommendationsEnabled: json['recommendationsEnabled'] == true);
}
