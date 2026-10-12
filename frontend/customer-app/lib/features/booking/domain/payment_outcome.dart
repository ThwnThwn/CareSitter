enum PaymentOutcome { success, syncing, failure, review }

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
  if (const {'needs_manual_review', 'disputed'}.contains(bookingStatus)) {
    return PaymentOutcome.review;
  }
  if (const {'FAILED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED'}
          .contains(intentStatus) ||
      const {'cancelled', 'refunded', 'matching_failed'}
          .contains(bookingStatus)) {
    return PaymentOutcome.failure;
  }
  return PaymentOutcome.syncing;
}
