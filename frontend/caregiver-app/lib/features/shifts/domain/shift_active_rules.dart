class ShiftActiveRules {
  const ShiftActiveRules._();
  static bool isCheckedIn(String status) => const {
        'in_progress',
        'checkout_pending_review',
        'completed'
      }.contains(status);
  static bool canCheckout(String status, Iterable<String> taskStatuses) =>
      status == 'in_progress' &&
      taskStatuses.every((s) => s.toUpperCase() != 'PENDING');
  static Duration elapsed(DateTime start, DateTime end) {
    final value = end.difference(start);
    return value.isNegative ? Duration.zero : value;
  }
}
