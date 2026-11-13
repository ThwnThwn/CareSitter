enum PaymentOutcome { success, syncing, failure, review, unmatched, refunded }

PaymentOutcome paymentOutcome({String? bookingStatus, String? intentStatus}) {
  const paid = {
    'confirmed',
    'caregiver_accepted',
    'caregiver_en_route',
    'in_progress',
    'checkout_pending_review',
    'completed',
    'crisis',
  };
  if (paid.contains(bookingStatus)) return PaymentOutcome.success;
  // These booking states follow confirmed payment; service availability and
  // refunds must not be presented as a failed charge or a reason to pay again.
  if (bookingStatus == 'matching_failed') return PaymentOutcome.unmatched;
  if (bookingStatus == 'refunded') return PaymentOutcome.refunded;
  if (const {'needs_manual_review', 'disputed', 'cancelled'}
      .contains(bookingStatus)) {
    return PaymentOutcome.review;
  }
  if (const {'FAILED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED'}
      .contains(intentStatus)) {
    return PaymentOutcome.failure;
  }
  return PaymentOutcome.syncing;
}
