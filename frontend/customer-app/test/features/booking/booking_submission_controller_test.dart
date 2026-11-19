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
  test(
      'service and profile needs survive booking creation and changing needs changes its retry key',
      () async {
    final actions = _Actions()..unknown = true;
    final controller = BookingSubmissionController(actions);
    final recipientWithNeeds = BeneficiaryModel.fromBackend({
      'id': 'recipient',
      'fullName': 'Người nhận',
      'requiredCaregiverSkills': ['ho tro di chuyen']
    });
    Future<void> submit(List<String> serviceNeeds) async {
      await controller.submit(
          BookingWizardState(
              step: 5,
              addressId: 'address',
              date: DateTime(2026, 11, 16),
              startMinutes: 420),
          recipient: recipientWithNeeds,
          serviceId: 'service',
          serviceRequiredSkills: serviceNeeds,
          caregiverId: null,
          current: () => true,
          progress: (_) {});
    }

    await submit(['chuan bi bua an']);
    final first = actions.draft!;
    expect(first.requiredSkills, ['chuan bi bua an', 'ho tro di chuyen']);
    await submit(['chuan bi bua an']);
    expect(actions.draft!.idempotencyKey, first.idempotencyKey);
    await submit(['ho tro ve sinh ca nhan']);
    expect(actions.draft!.idempotencyKey, isNot(first.idempotencyKey));
  });
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
        promotionCode: 'CARE20',
        expectedPayableAmount: 240000,
        current: () => true,
        progress: (_) {});
    expect(outcome.result, isA<BookingSubmitIgnored>());
    expect(outcome.uncertainDraft, same(actions.draft));
    expect(outcome.uncertainDraft!.idempotencyKey, isNotEmpty);
    expect(outcome.uncertainDraft!.promotionCode, 'CARE20');
    expect(outcome.uncertainDraft!.expectedPayableAmount, 240000);
    expect(actions.creates, 1);
  });
  test('applying or removing a code gives the changed payload a new key',
      () async {
    final actions = _Actions();
    final controller = BookingSubmissionController(actions);
    Future<BookingDraft> submit(String? code,
        {int? expectedPayableAmount}) async {
      await controller.submit(snapshot(),
          recipient: recipient,
          serviceId: 'service',
          caregiverId: null,
          promotionCode: code,
          expectedPayableAmount: expectedPayableAmount,
          current: () => true,
          progress: (_) {});
      return actions.draft!;
    }

    final first = await submit('CARE20', expectedPayableAmount: 240000);
    expect(first.promotionCode, 'CARE20');
    expect(
        (await submit('CARE20', expectedPayableAmount: 240000)).idempotencyKey,
        first.idempotencyKey);
    expect(
        (await submit('CARE20', expectedPayableAmount: 250000)).idempotencyKey,
        isNot(first.idempotencyKey));
    expect(
        (await submit('CARE50')).idempotencyKey, isNot(first.idempotencyKey));
    final withoutPromotion = await submit(null);
    expect(withoutPromotion.promotionCode, isNull);
    expect(withoutPromotion.idempotencyKey, isNot(first.idempotencyKey));
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
