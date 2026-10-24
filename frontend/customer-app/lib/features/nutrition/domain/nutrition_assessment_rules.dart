class NutritionAssessmentRules {
  static bool canStart({
    required bool loading,
    required bool restoringPlan,
    required String? resourceStatus,
    required bool retryable,
    required bool retryAllowed,
  }) =>
      !loading &&
      !restoringPlan &&
      (resourceStatus != 'failed' || (retryable && retryAllowed));

  static bool pending(String status) =>
      status == 'queued' || status == 'processing';
  static Duration pollDelay(int attempt) =>
      Duration(seconds: attempt < 3 ? 2 : 5);
  // 11 scheduled reads: 2s + 2s + 2s + 8 * 5s = 46s, excluding request time.
  static const maximumPollAttempt = 10;
}
