import '../../domain/booking_step_rules.dart';
import '../../domain/caregiver_match_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../beneficiary/presentation/controllers/beneficiary_controller.dart';
import '../../../catalog/presentation/controllers/service_controller.dart';
import '../../../catalog/presentation/controllers/address_controller.dart';
import '../../../caregiver/presentation/controllers/caregiver_controller.dart';
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
      .watch(caregiverStoreProvider)
      .valueOrNull
      ?.where((s) => s.id == id)
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
    .family<AsyncValue<List<CaregiverModel>>, BookingWizardArgs>((ref, args) =>
        ref.watch(caregiverStoreProvider).whenData((items) =>
            CaregiverMatchRules.rankOnline(items,
                isOnline: (c) => c.isOnline, rating: (c) => c.ratingAvg)));
final wizardScheduleValidProvider =
    Provider.autoDispose.family<bool, BookingWizardArgs>((ref, args) {
  final schedule = ref.watch(
      bookingWizardProvider(args).select((s) => (s.date, s.startMinutes)));
  return ScheduleRules.isValid(schedule.$1, schedule.$2, DateTime.now());
});
