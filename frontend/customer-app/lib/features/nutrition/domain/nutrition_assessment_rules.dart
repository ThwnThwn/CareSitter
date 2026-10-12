class NutritionAssessmentRules {
  static bool pending(String status) =>
      status == 'queued' || status == 'processing';
  static Duration pollDelay(int attempt) =>
      Duration(seconds: attempt < 3 ? 2 : 5);
  static const maximumPollAttempt = 60;
}
