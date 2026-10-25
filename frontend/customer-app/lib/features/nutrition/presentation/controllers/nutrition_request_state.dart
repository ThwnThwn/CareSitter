/// State của luồng: chỉ ID/revision và trạng thái thao tác; DTO nằm trong cache.
class NutritionRequestState {
  const NutritionRequestState(
      {required this.beneficiaryId,
      this.healthRevision = 0,
      this.resourceId,
      this.loading = false,
      this.restoringPlan = false,
      this.error,
      this.recommendationsEnabled = false,
      this.selectedDate,
      this.dateLoading = false,
      this.dateError});
  final String beneficiaryId;
  final int healthRevision;
  final String? resourceId, error;
  final DateTime? selectedDate;
  final String? dateError;
  final bool dateLoading;
  final bool loading, restoringPlan, recommendationsEnabled;
}
