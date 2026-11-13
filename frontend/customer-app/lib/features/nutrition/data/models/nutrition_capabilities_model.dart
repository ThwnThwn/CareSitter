class NutritionCapabilitiesModel {
  const NutritionCapabilitiesModel(
      {required this.enabled,
      required this.assessmentsEnabled,
      required this.recommendationsEnabled,
      this.disclaimer,
      this.disclaimerVersion});
  final bool enabled, assessmentsEnabled, recommendationsEnabled;
  final String? disclaimer, disclaimerVersion;
  factory NutritionCapabilitiesModel.fromJson(Map<String, dynamic> json) =>
      NutritionCapabilitiesModel(
          enabled: json['enabled'] == true,
          assessmentsEnabled: json['assessmentsEnabled'] == true,
          recommendationsEnabled: json['recommendationsEnabled'] == true,
          disclaimer: _optional(json['disclaimer']),
          disclaimerVersion: _optional(json['disclaimerVersion']));

  // Proto3 strings default to "" when an older Nutrition service omits them;
  // treat blank as absent so the UI falls back instead of showing no warning.
  static String? _optional(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
