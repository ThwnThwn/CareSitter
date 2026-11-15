import 'dart:convert';
import '../../domain/booking_step_rules.dart';
import 'booking_candidate_controller.dart';
export 'booking_candidate_controller.dart' show bookingCandidateRequestProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../beneficiary/presentation/controllers/beneficiary_controller.dart';
import '../../../catalog/presentation/controllers/service_controller.dart';
import '../../../catalog/presentation/controllers/address_controller.dart';
import '../../../catalog/data/models/service_model.dart';
import '../../../caregiver/data/models/caregiver_model.dart';
import 'self_recipient_controller.dart';
import 'booking_wizard_controller.dart';
import 'booking_wizard_state.dart';
import '../../domain/schedule_rules.dart';

final wizardServiceProvider =
    Provider.autoDispose.family<ServiceModel?, BookingWizardArgs>((ref, args) {
  final id = ref.watch(bookingWizardProvider(args).select((s) => s.serviceId));
  return ref
      .watch(serviceStoreProvider)
      .valueOrNull
      ?.where((s) => s.id == id)
      .firstOrNull;
});
final wizardRecipientProvider = Provider.autoDispose
    .family<BeneficiaryModel?, BookingWizardArgs>((ref, args) {
  final choice = ref.watch(
      bookingWizardProvider(args).select((s) => (s.forSelf, s.beneficiaryId)));
  if (choice.$1) return ref.watch(selfRecipientProvider).valueOrNull?.profile;
  return ref
      .watch(bookingRecipientsProvider)
      .valueOrNull
      ?.where((s) => s.id == choice.$2 && !s.isSelf)
      .firstOrNull;
});
final wizardCaregiverProvider = Provider.autoDispose
    .family<CaregiverModel?, BookingWizardArgs>((ref, args) {
  final id =
      ref.watch(bookingWizardProvider(args).select((s) => s.caregiverId));
  return ref
      .watch(wizardCandidatesProvider(args))
      .asData
      ?.value
      .where((s) => s.id == id)
      .firstOrNull;
});
final wizardCanContinueProvider =
    Provider.autoDispose.family<bool, BookingWizardArgs>((ref, args) {
  final s = ref.watch(bookingWizardProvider(args));
  final recipient = s.forSelf
      ? s.selfDateValid &&
          (ref.watch(selfRecipientProvider).valueOrNull?.isComplete ?? false)
      : ref.watch(wizardRecipientProvider(args)) != null;
  final schedule =
      ScheduleRules.isValid(s.date, s.startMinutes, DateTime.now());
  final address = ref
          .watch(addressStoreProvider)
          .valueOrNull
          ?.any((a) => a.id == s.addressId && a.isVerified) ??
      false;
  return BookingStepRules.canContinue(
      step: s.step,
      service: ref.watch(wizardServiceProvider(args)) != null,
      recipient: recipient,
      schedule: schedule,
      address: address,
      caregiver:
          s.systemMatched || ref.watch(wizardCaregiverProvider(args)) != null,
      consent: s.consent);
});

final wizardCandidatesProvider = Provider.autoDispose
    .family<AsyncValue<List<CaregiverModel>>, BookingWizardArgs>((ref, args) {
  final input = ref.watch(bookingWizardProvider(args).select(
      (s) => (s.serviceId, s.addressId, s.date, s.startMinutes, s.duration)));
  final forSelf =
      ref.watch(bookingWizardProvider(args).select((s) => s.forSelf));
  final self = forSelf ? ref.watch(selfRecipientProvider).valueOrNull : null;
  final recipientId = self?.kind == SelfRecipientKind.draft
      ? null
      : ref.watch(wizardRecipientProvider(args))?.id;
  if (input.$1 == null ||
      input.$2 == null ||
      input.$3 == null ||
      input.$4 == null ||
      (!forSelf && recipientId == null)) {
    return const AsyncData([]);
  }
  final start = ScheduleRules.at(input.$3!, input.$4!);
  return ref.watch(bookingCandidateRequestProvider((
    beneficiaryId: recipientId,
    addressId: input.$2!,
    serviceTypeId: input.$1!,
    start: start,
    end: start.add(Duration(hours: input.$5)),
    requiredSkillsJson: jsonEncode(({
      ...ref.watch(wizardServiceProvider(args))?.requiredCaregiverSkills ??
          <String>[],
      ...ref.watch(wizardRecipientProvider(args))?.requiredCaregiverSkills ??
          <String>[]
    }.toList()
      ..sort()))
  )));
});

final wizardScheduleValidProvider =
    Provider.autoDispose.family<bool, BookingWizardArgs>((ref, args) {
  final schedule = ref.watch(
      bookingWizardProvider(args).select((s) => (s.date, s.startMinutes)));
  return ScheduleRules.isValid(schedule.$1, schedule.$2, DateTime.now());
});
