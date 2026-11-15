import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/domain/payment_outcome.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/payment_result_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/payment_result_state.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_presentation.dart';

void main() {
  test(
      'payment status distinguishes a confirmed charge from acceptance of the care shift',
      () {
    final waiting = PaymentResultPresentation.details(PaymentOutcome.success,
        bookingStatus: 'confirmed');
    final accepted = PaymentResultPresentation.details(PaymentOutcome.success,
        bookingStatus: 'caregiver_accepted');
    expect(waiting.message, contains('Đang chờ'));
    expect(accepted.message, contains('đã nhận ca'));
    expect(waiting.label, 'ĐÃ THANH TOÁN');
    expect(accepted.label, 'ĐÃ THANH TOÁN');
  });
  test('late provider callback is polled without inviting a second payment',
      () {
    fakeAsync((time) {
      var paid = false;
      final controller = PaymentResultController(
          args: (bookingId: 'booking', intentId: 'intent'),
          readBookingStatus: (_) async =>
              paid ? 'confirmed' : 'pending_payment',
          readIntentStatus: (_) async => paid ? 'SUCCEEDED' : 'PENDING',
          onConfirmed: () async {});
      unawaited(controller.refresh());
      time.flushMicrotasks();
      for (var i = 0; i < 9; i++) {
        time.elapse(const Duration(seconds: 2));
        time.flushMicrotasks();
      }
      expect(controller.state.outcome, PaymentOutcome.syncing);
      paid = true;
      time.elapse(const Duration(seconds: 2));
      time.flushMicrotasks();
      expect(controller.state.outcome, PaymentOutcome.success);
      controller.dispose();
    });
  });
  test(
      'automatic polling is bounded and manual retry starts a new verification',
      () {
    fakeAsync((time) {
      var reads = 0;
      final controller = PaymentResultController(
          args: (bookingId: 'booking', intentId: null),
          maxPollAttempts: 3,
          readBookingStatus: (_) async {
            reads++;
            return 'pending_payment';
          },
          readIntentStatus: (_) async => 'PENDING',
          onConfirmed: () async {});
      unawaited(controller.refresh());
      time.flushMicrotasks();
      for (var i = 0; i < 5; i++) {
        time.elapse(const Duration(seconds: 2));
        time.flushMicrotasks();
      }
      expect(reads, 3);
      expect(controller.state.outcome, PaymentOutcome.syncing);
      unawaited(controller.retry());
      time.flushMicrotasks();
      expect(reads, 4);
      controller.dispose();
    });
  });
  test(
      'successful payment with failed matching never asks customer to pay again',
      () async {
    final controller = PaymentResultController(
      args: (bookingId: 'booking', intentId: 'intent'),
      readBookingStatus: (_) async => 'matching_failed',
      readIntentStatus: (_) async => 'SUCCEEDED',
      onConfirmed: () async {},
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final details = PaymentResultPresentation.details(controller.state.outcome);
    expect(details.title, 'Đã thanh toán, chưa tìm được người chăm sóc');
    expect(details.label, 'ĐÃ THANH TOÁN');
    expect(details.message, contains('Không thanh toán lại'));
  });

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
        PaymentOutcome.review);
  });
}
