import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/otp_controller.dart';

void main() {
  test('typing the final digit and tapping verify submits only once', () async {
    var writes = 0;
    final response = Completer<void>();
    final controller = OtpController(
        send: () async {},
        verify: (_) {
          writes++;
          return response.future;
        });
    addTearDown(controller.dispose);
    final first = controller.submit('123456');
    expect(await controller.submit('123456'), isFalse);
    expect(writes, 1);
    response.complete();
    expect(await first, isTrue);
  });
  test('failed resend does not start a new cooldown', () {
    fakeAsync((async) {
      var sends = 0;
      final controller = OtpController(
          send: () async {
            sends++;
            throw StateError('offline');
          },
          verify: (_) async {});
      final states = <OtpState>[];
      controller.addListener(states.add);
      controller.resend();
      async.flushMicrotasks();
      expect(sends, 0);
      async.elapse(const Duration(seconds: 60));
      controller.resend();
      async.flushMicrotasks();
      expect(sends, 1);
      expect(states.last.countdown, 0);
      expect(states.last.error, isNotNull);
      controller.dispose();
      expect(async.periodicTimerCount, 0);
    });
  });
}
