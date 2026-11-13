import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/domain/payment_outcome.dart';

void main() {
  for (final intent in [null, 'SUCCEEDED', 'PENDING', 'EXPIRED', 'FAILED']) {
    test('failed matching stays separate from charge failure with $intent', () {
      expect(
        paymentOutcome(bookingStatus: 'matching_failed', intentStatus: intent),
        PaymentOutcome.unmatched,
      );
    });
    test('confirmed refund never asks for another payment with $intent', () {
      expect(
        paymentOutcome(bookingStatus: 'refunded', intentStatus: intent),
        PaymentOutcome.refunded,
      );
    });
    test(
        'cancelled booking needs review rather than another charge with $intent',
        () {
      expect(
        paymentOutcome(bookingStatus: 'cancelled', intentStatus: intent),
        PaymentOutcome.review,
      );
    });
  }

  for (final intent in ['FAILED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED']) {
    test('unsuccessful payment $intent remains failure for unpaid booking', () {
      expect(
        paymentOutcome(bookingStatus: 'pending_payment', intentStatus: intent),
        PaymentOutcome.failure,
      );
    });
  }

  test('successful charge still waits for booking confirmation', () {
    expect(
      paymentOutcome(
          bookingStatus: 'pending_payment', intentStatus: 'SUCCEEDED'),
      PaymentOutcome.syncing,
    );
  });

  test('missing or unknown server states do not prove success or failure', () {
    expect(paymentOutcome(), PaymentOutcome.syncing);
    expect(
      paymentOutcome(bookingStatus: 'unknown', intentStatus: 'unknown'),
      PaymentOutcome.syncing,
    );
  });
}
