import '../../domain/payment_outcome.dart';

class PaymentResultState {
  const PaymentResultState({
    this.refreshing = true,
    this.bookingStatus,
    this.intentStatus,
  });
  final bool refreshing;
  final String? bookingStatus;
  final String? intentStatus;
  PaymentOutcome get outcome =>
      paymentOutcome(bookingStatus: bookingStatus, intentStatus: intentStatus);
}
