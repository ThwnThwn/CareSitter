class NutritionAssessmentRules {
  static bool pending(String status) =>
      status == 'queued' || status == 'processing';
  static Duration pollDelay(int attempt) =>
      Duration(seconds: attempt < 3 ? 2 : 5);
  // 11 scheduled reads: 2s + 2s + 2s + 8 * 5s = 46s, excluding request time.
  static const maximumPollAttempt = 10;
}
