class NutritionWeekGenerationResult {
  const NutritionWeekGenerationResult({
    required this.createdDays,
    required this.existingDays,
    this.error,
    this.needsProfile = false,
  });

  final int createdDays;
  final int existingDays;
  final String? error;
  final bool needsProfile;

  bool get completed => createdDays + existingDays == 7 && error == null;
}
