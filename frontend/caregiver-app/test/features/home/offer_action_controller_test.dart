import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/home/presentation/controllers/offer_action_controller.dart';

void main() {
  test('pending action blocks repeated taps and releases the lock on failure',
      () async {
    final controller = OfferActionController();
    addTearDown(controller.dispose);
    final pending = Completer<void>();
    var calls = 0;
    final first = controller.run('booking', () {
      calls++;
      return pending.future;
    });
    expect(
        await controller.run('booking', () async {
          calls++;
        }),
        OfferActionResult.ignored);
    expect(calls, 1);
    pending.completeError(StateError('failed'));
    expect(await first, OfferActionResult.failed);
    expect(await controller.run('booking', () async {}),
        OfferActionResult.success);
  });
  test('disposing the flow ignores a late successful response', () async {
    final controller = OfferActionController();
    final pending = Completer<void>();
    final action = controller.run('booking', () => pending.future);
    controller.dispose();
    pending.complete();
    expect(await action, OfferActionResult.ignored);
  });
}
