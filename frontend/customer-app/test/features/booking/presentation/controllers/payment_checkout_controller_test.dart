import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/data/models/payment_intent_model.dart';
import 'package:caresitter_customer/features/booking/domain/payment_url_rules.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/payment_checkout_controller.dart';

void main() {
  test('pending checkout remains locked until the launcher finishes', () async {
    final response = Completer<PaymentIntentModel>();
    var creates = 0;
    final controller = PaymentCheckoutController((_) {
      creates++;
      return response.future;
    });
    addTearDown(controller.dispose);
    controller.select('PAYOS', enabled: true);
    final first = controller.prepare();
    expect(await controller.prepare(), isA<PaymentCheckoutIgnored>());
    response.complete(const PaymentIntentModel(
        id: 'intent', status: 'PENDING', paymentUrl: 'https://pay.payos.vn/a'));
    expect(await first, isA<PaymentCheckoutReady>());
    expect(await controller.prepare(), isA<PaymentCheckoutIgnored>());
    expect(creates, 1);
    controller.launchFailed();
    final states = <PaymentCheckoutState>[];
    controller.addListener(states.add);
    expect(states.last.busy, isFalse);
    expect(states.last.selected, 'PAYOS');
  });
  test('disabled provider never submits a payment request', () async {
    var creates = 0;
    final controller = PaymentCheckoutController((_) async {
      creates++;
      throw StateError('unexpected');
    });
    addTearDown(controller.dispose);
    controller.select('PAYOS', enabled: false);
    expect(await controller.prepare(), isA<PaymentCheckoutIgnored>());
    expect(creates, 0);
  });
  test('payment URL rejects unsafe schemes, credentials and foreign payOS host',
      () {
    expect(validPaymentUrl('http://pay.payos.vn/a', 'PAYOS'), isNull);
    expect(validPaymentUrl('https://user:password@pay.payos.vn/a', 'PAYOS'),
        isNull);
    expect(
        validPaymentUrl('https://pay.payos.vn.example.com/a', 'PAYOS'), isNull);
    expect(validPaymentUrl('https://pay.payos.vn/a', 'PAYOS')?.host,
        'pay.payos.vn');
  });
}
