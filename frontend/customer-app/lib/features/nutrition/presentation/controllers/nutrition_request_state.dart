/// State của luồng: chỉ ID/revision và trạng thái thao tác; DTO nằm trong cache.
class NutritionRequestState {
  const NutritionRequestState(
      {required this.beneficiaryId,
      this.healthRevision = 0,
      this.resourceId,
      this.loading = false,
      this.error,
      this.recommendationsEnabled = false});
  final String beneficiaryId;
  final int healthRevision;
  final String? resourceId, error;
  final bool loading, recommendationsEnabled;
}
