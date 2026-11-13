class NutritionNutrientTotal {
  /// Sum the recorded nutrients of the dishes in a plan. A missing or invalid
  /// contribution makes the total unknown; it must never become a partial sum.
  static num? sum(Iterable<num?> values) {
    var count = 0;
    num total = 0;
    for (final value in values) {
      if (value == null || !value.isFinite || value < 0) return null;
      total += value;
      count++;
    }
    return count == 0 || !total.isFinite ? null : total;
  }
}
