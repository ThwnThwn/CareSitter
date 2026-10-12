import '../../fixtures/shift_active_fakes.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/models/shift_action_result.dart';
import 'package:caregiver_app/features/shifts/domain/shift_active_rules.dart';

void main() {
  test(
      'restored checkout freezes elapsed time and future timestamps stay non-negative',
      () {
    final actions = FakeShiftActiveActions();
    final controller = ShiftActiveController(actions,
        enableTimer: false, now: () => DateTime(2026, 10, 12, 12));
    addTearDown(controller.dispose);
    controller.reconcile(booking().copyWith(
        status: 'checkout_pending_review',
        checkoutRequestedAt: DateTime(2026, 10, 12, 10)));
    expect(controller.state.checkedIn, isTrue);
    expect(controller.state.step, 3);
    expect(controller.state.elapsed, const Duration(hours: 2));
    expect(
        ShiftActiveRules.elapsed(
            DateTime(2026, 10, 13), DateTime(2026, 10, 12)),
        Duration.zero);
  });
  test('pending tasks prevent checkout before any write', () async {
    final actions = FakeShiftActiveActions()
      ..snapshot =
          booking(tasks: [const CareTaskModel(id: 'task', title: 'Việc')]);
    final controller = ShiftActiveController(actions, enableTimer: false);
    addTearDown(controller.dispose);
    expect(await controller.checkout(), isA<ShiftActionFailure>());
    expect(actions.notes, 0);
    expect(actions.checkouts, 0);
  });
  test('failed note does not send checkout and releases the submit lock',
      () async {
    final actions = FakeShiftActiveActions()..failNote = true;
    final controller = ShiftActiveController(actions, enableTimer: false);
    addTearDown(controller.dispose);
    expect(await controller.checkout(), isA<ShiftActionFailure>());
    expect(actions.checkouts, 0);
    expect(controller.state.busy, isEmpty);
    actions.failNote = false;
    expect(await controller.checkout(), isA<ShiftActionSuccess>());
    expect(actions.checkouts, 1);
  });
  test(
      'concurrent task actions share a lock and photo-required completion is rejected',
      () async {
    final actions = FakeShiftActiveActions()
      ..snapshot = booking(tasks: [const CareTaskModel(id: 't', title: 'Việc')])
      ..pendingTask = Completer<void>();
    final controller = ShiftActiveController(actions, enableTimer: false);
    addTearDown(controller.dispose);
    final first = controller.completeTask('t');
    expect(await controller.completeTask('t'), isA<ShiftActionIgnored>());
    expect(actions.completed, 1);
    actions.pendingTask!.complete();
    expect(await first, isA<ShiftActionSuccess>());
    actions.snapshot = booking(tasks: [
      const CareTaskModel(id: 'photo', title: 'Việc', requiresPhoto: true)
    ]);
    expect(await controller.completeTask('photo'), isA<ShiftActionFailure>());
    expect(actions.completed, 1);
  });
  test('late selfie after disposal never advances another session', () async {
    final actions = FakeShiftActiveActions()
      ..pendingSelfie = Completer<String>();
    final controller = ShiftActiveController(actions, enableTimer: false);
    final uploading = controller.uploadSelfie(XFile('test-image'));
    controller.dispose();
    actions.pendingSelfie!.complete('old-photo');
    expect(await uploading, isA<ShiftActionIgnored>());
  });
}
