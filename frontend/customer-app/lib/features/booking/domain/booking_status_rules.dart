/// Các bất biến trạng thái chỉ dùng input thuần Dart, không phụ thuộc DTO/UI.
class BookingStatusRules {
  static bool isActive(String status) => const {
        'draft',
        'pending_payment',
        'payment_reconciliation_pending',
        'needs_manual_review',
        'confirmed',
        'caregiver_accepted',
        'caregiver_en_route',
        'in_progress',
        'checkout_pending_review',
        'crisis',
      }.contains(status);
  static bool isCancelled(String status) => const {
        'cancelled',
        'matching_failed',
        'disputed',
        'refunded',
      }.contains(status);
  static String presentationStatusAt(
      {required String status,
      required DateTime now,
      DateTime? cancelledAt,
      DateTime? actualStart,
      required bool caregiverAssigned}) {
    final normalized = status.toLowerCase();
    if (cancelledAt != null &&
        !const {'cancelled', 'refunded', 'disputed'}.contains(normalized)) {
      return 'cancelled';
    }
    final checkedIn = actualStart != null && !actualStart.isAfter(now);
    if (const {'in_progress', 'checkout_pending_review'}.contains(normalized) &&
        !checkedIn) {
      return caregiverAssigned ? 'caregiver_accepted' : 'confirmed';
    }
    return normalized;
  }

  static bool isLiveStatus(String status) => const {
        'caregiver_en_route',
        'in_progress',
        'checkout_pending_review',
      }.contains(status);
}
