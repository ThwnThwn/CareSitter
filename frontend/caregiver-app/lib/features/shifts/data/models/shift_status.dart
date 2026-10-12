enum ShiftStatus {
  open('open'),
  pending('pending'),
  assigned('assigned'),
  confirmed('confirmed'),
  caregiverEnRoute('caregiver_en_route'),
  inProgress('in_progress'),
  checkoutPendingReview('checkout_pending_review'),
  completed('completed'),
  crisis('crisis'),
  cancelled('cancelled'),
  unknown('unknown');

  final String apiValue;

  const ShiftStatus(this.apiValue);

  factory ShiftStatus.fromApi(Object? raw) {
    final normalized = raw
        ?.toString()
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase();
    return ShiftStatus.values.firstWhere(
      (status) => status.apiValue == normalized,
      orElse: () => ShiftStatus.unknown,
    );
  }
}
