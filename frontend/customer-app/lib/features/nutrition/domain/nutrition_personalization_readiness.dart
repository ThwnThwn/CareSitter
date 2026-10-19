class NutritionPersonalizationReadiness {
  const NutritionPersonalizationReadiness(
    this.missingFields, {
    required this.totalIssueCount,
  });

  final List<String> missingFields;
  final int totalIssueCount;

  bool get isReady => totalIssueCount == 0;
}
