class HomeShiftRules {
  static bool isToday(String status, DateTime? start, DateTime now) {
    if (!const {'confirmed', 'assigned', 'in_progress', 'caregiver_en_route'}
        .contains(status)) {
      return false;
    }
    return start == null ||
        (start.year == now.year &&
            start.month == now.month &&
            start.day == now.day);
  }

  static bool isOpenOffer(
          String status, String? offerId, DateTime? expiresAt, DateTime now) =>
      offerId != null &&
      expiresAt != null &&
      expiresAt.isAfter(now) &&
      const {'pending', 'open'}.contains(status);

  static bool isScheduledOrActive(String status) =>
      const {'confirmed', 'caregiver_en_route', 'in_progress'}.contains(status);

  static bool isTightTurnaround(DateTime? offerStart, DateTime? offerEnd,
      DateTime? start, DateTime? end) {
    if (offerStart == null ||
        offerEnd == null ||
        start == null ||
        end == null) {
      return false;
    }
    final before = offerStart.difference(end);
    final after = start.difference(offerEnd);
    final gap = before >= Duration.zero ? before : after;
    return gap >= Duration.zero && gap <= const Duration(minutes: 30);
  }
}
