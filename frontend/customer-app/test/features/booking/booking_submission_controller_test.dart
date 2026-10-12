import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_draft.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_submission_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_submission_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_state.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_outcome_unknown.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_submit_result.dart';

void main() {
  final recipient = BeneficiaryModel.fromBackend(
      {'id': 'recipient', 'fullName': 'Người nhận', 'isSelf': true});
  BookingWizardState snapshot({bool forSelf = false}) => BookingWizardState(
      step: 5,
      forSelf: forSelf,
      addressId: 'address',
      date: DateTime(2026, 10, 15),
      startMinutes: 420);
  test(
      'session change during self resolution prevents publish and booking POST',
      () async {
    var active = true;
    final actions = _Actions()
      ..resolved = Completer<({BeneficiaryModel profile, bool needsReview})>();
    final pending = BookingSubmissionController(actions).submit(
        snapshot(forSelf: true),
        recipient: recipient,
        serviceId: 'service',
        caregiverId: null,
        current: () => active,
        progress: (_) {});
    active = false;
    actions.resolved!.complete((profile: recipient, needsReview: false));
    expect((await pending).result, isA<BookingSubmitIgnored>());
    expect(actions.published, 0);
    expect(actions.creates, 0);
  });
  test('an unknown POST result retains the exact draft for GET reconciliation',
      () async {
    final actions = _Actions()..unknown = true;
    final outcome = await BookingSubmissionController(actions).submit(
        snapshot(),
        recipient: recipient,
        serviceId: 'service',
        caregiverId: null,
        current: () => true,
        progress: (_) {});
    expect(outcome.result, isA<BookingSubmitIgnored>());
    expect(outcome.uncertainDraft, same(actions.draft));
    expect(outcome.uncertainDraft!.idempotencyKey, isNotEmpty);
    expect(actions.creates, 1);
  });
  test('a changed self profile returns to review before any booking POST',
      () async {
    final actions = _Actions()
      ..resolved = Completer<({BeneficiaryModel profile, bool needsReview})>();
    actions.resolved!.complete((profile: recipient, needsReview: true));
    final outcome = await BookingSubmissionController(actions).submit(
        snapshot(forSelf: true),
        recipient: recipient,
        serviceId: 'service',
        caregiverId: null,
        current: () => true,
        progress: (_) {});
    expect(outcome.reviewRecipient, isTrue);
    expect(outcome.result, isA<BookingSubmitMessage>());
    expect(actions.creates, 0);
  });
}

class _Actions implements BookingSubmissionActions {
  Completer<({BeneficiaryModel profile, bool needsReview})>? resolved;
  var creates = 0, published = 0;
  bool unknown = false;
  BookingDraft? draft;
  @override
  bool get selfComplete => true;
  @override
  Future<({BeneficiaryModel profile, bool needsReview})> resolveSelf(
          String addressId) =>
      resolved!.future;
  @override
  void publishSelf(BeneficiaryModel profile) {
    published++;
  }

  @override
  Future<BookingModel> createBooking(BookingDraft draft) async {
    creates++;
    this.draft = draft;
    if (unknown) throw const BookingOutcomeUnknown();
    return BookingModel.fromJson({'id': 'booking'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
