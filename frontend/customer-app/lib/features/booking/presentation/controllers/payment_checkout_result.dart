import '../../data/models/payment_intent_model.dart';

sealed class PaymentCheckoutResult {
  const PaymentCheckoutResult();
}

class PaymentCheckoutReady extends PaymentCheckoutResult {
  const PaymentCheckoutReady(this.intent, this.uri);
  final PaymentIntentModel intent;
  final Uri? uri;
}

class PaymentCheckoutIgnored extends PaymentCheckoutResult {
  const PaymentCheckoutIgnored();
}
