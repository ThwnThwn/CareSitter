import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/domain/payment_outcome.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/payment_result_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/payment_result_state.dart';

void main() {
  test('provider success alone keeps the result syncing until booking confirms',
      () async {
    final states = <PaymentResultState>[];
    var confirmed = 0;
    final controller = PaymentResultController(
      args: (bookingId: 'booking', intentId: 'intent'),
      readBookingStatus: (_) async => 'pending_payment',
      readIntentStatus: (_) async => 'SUCCEEDED',
      onConfirmed: () async {
        confirmed++;
      },
      pollInterval: const Duration(days: 1),
    );
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(states.last.outcome, PaymentOutcome.syncing);
    expect(confirmed, 0);
  });

  test('network failure does not report payment failure', () async {
    final states = <PaymentResultState>[];
    final controller = PaymentResultController(
      args: (bookingId: 'booking', intentId: 'intent'),
      readBookingStatus: (_) async => throw StateError('offline'),
      readIntentStatus: (_) async => throw StateError('offline'),
      onConfirmed: () async {},
      pollInterval: const Duration(days: 1),
    );
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(states.last.outcome, PaymentOutcome.syncing);
    expect(states.last.refreshing, isFalse);
  });

  test('simultaneous refreshes read once and confirm from backend booking',
      () async {
    final booking = Completer<String>();
    var reads = 0, confirmations = 0;
    final states = <PaymentResultState>[];
    final controller = PaymentResultController(
      args: (bookingId: 'booking', intentId: null),
      readBookingStatus: (_) {
        reads++;
        return booking.future;
      },
      readIntentStatus: (_) async => 'PENDING',
      onConfirmed: () async {
        confirmations++;
      },
    );
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    await controller.refresh();
    expect(reads, 1);
    booking.complete('confirmed');
    await pending;
    expect(states.last.outcome, PaymentOutcome.success);
    expect(confirmations, 1);
  });

  test('suspend discards the response from a previous request', () async {
    final booking = Completer<String>();
    final states = <PaymentResultState>[];
    var confirmations = 0;
    final controller = PaymentResultController(
      args: (bookingId: 'booking', intentId: null),
      readBookingStatus: (_) => booking.future,
      readIntentStatus: (_) async => 'PENDING',
      onConfirmed: () async {
        confirmations++;
      },
    );
    controller.addListener(states.add);
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    controller.suspend();
    final count = states.length;
    booking.complete('confirmed');
    await pending;
    expect(states.length, count);
    expect(confirmations, 0);
  });

  test('manual review stays review even when the payment intent succeeded', () {
    expect(paymentOutcome(bookingStatus: 'disputed', intentStatus: 'SUCCEEDED'),
        PaymentOutcome.review);
    expect(
        paymentOutcome(bookingStatus: 'cancelled', intentStatus: 'SUCCEEDED'),
        PaymentOutcome.failure);
  });
}
