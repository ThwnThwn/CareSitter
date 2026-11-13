class NutritionWeekGenerationResult {
  const NutritionWeekGenerationResult({
    required this.createdDays,
    required this.existingDays,
    this.targetDays = 7,
    this.error,
    this.needsProfile = false,
  });

  final int createdDays;
  final int existingDays;
  final int targetDays;
  final String? error;
  final bool needsProfile;

  bool get completed =>
      createdDays + existingDays == targetDays && error == null;
}
