import 'booking_submission_controller.dart';
import 'booking_reconciliation_controller.dart';
import 'riverpod_booking_submission_actions.dart';
import '../../domain/booking_step_rules.dart';
import '../../../catalog/data/models/service_model.dart';
import '../../../caregiver/data/models/caregiver_model.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../../beneficiary/presentation/controllers/beneficiary_controller.dart';
import '../../domain/schedule_rules.dart';
import 'self_recipient_controller.dart';
import 'booking_wizard_state.dart';
import '../../../catalog/presentation/controllers/service_controller.dart';
import '../../../catalog/presentation/controllers/address_controller.dart';
import '../../../caregiver/presentation/controllers/caregiver_controller.dart';
import 'booking_submit_result.dart';

final bookingWizardProvider = AutoDisposeNotifierProvider.family<
    BookingWizardController,
    BookingWizardState,
    BookingWizardArgs>(BookingWizardController.new);

class BookingWizardController
    extends AutoDisposeFamilyNotifier<BookingWizardState, BookingWizardArgs> {
  static const minimumDurationHours = ScheduleRules.minimumDurationHours;
  static const maximumDurationHours = ScheduleRules.maximumDurationHours;
  int _generation = 0;
  late BookingSubmissionController _submission;
  late BookingReconciliationController _reconciliation;
  bool _firstBuild = true, _disposed = false;
  @override
  BookingWizardState build(BookingWizardArgs arg) {
    ref.watch(authStateProvider.select(
        (s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
    final actions = RiverpodBookingSubmissionActions(ref);
    _submission = BookingSubmissionController(actions);
    _reconciliation = BookingReconciliationController(actions.getBookings);
    final initial = _firstBuild;
    _firstBuild = false;
    _disposed = false;
    final generation = ++_generation;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    // Draft bản thân thuộc cả wizard, kể cả lúc nhánh Người thân không vẽ form.
    ref.listen(selfRecipientProvider, (_, __) {});
    ref.listen(bookingRecipientsProvider, (_, next) {
      if (state.initialResolved || arg.beneficiaryId == null) return;
      final items = next.valueOrNull;
      if (items != null) _resolveInitial(items);
    });
    // Resolver chạy sau build của provider; không phát sinh side effect từ UI build.
    Future.microtask(() {
      if (_current(generation) && !state.initialResolved) {
        final items = ref.read(bookingRecipientsProvider).valueOrNull;
        if (items != null) _resolveInitial(items);
      }
    });
    return BookingWizardState(
        serviceId: initial ? arg.serviceId : null,
        beneficiaryId: initial ? arg.beneficiaryId : null,
        step: initial && arg.serviceId != null ? 1 : 0,
        initialResolved: !initial || arg.beneficiaryId == null);
  }

  bool _current(int generation) => !_disposed && _generation == generation;
  void _resolveInitial(List<BeneficiaryModel> items) {
    final profile = items.where((b) => b.id == arg.beneficiaryId).firstOrNull;
    if (profile?.isSelf == true) {
      ref.read(selfRecipientProvider.notifier).acceptExisting(profile!);
    }
    state = state.copyWith(
        initialResolved: true,
        beneficiaryId: profile?.id,
        forSelf: profile?.isSelf ?? false,
        addressId: profile?.defaultAddressId);
  }

  void selectService(String id) => state = state.copyWith(serviceId: id);
  void selectRecipient(BeneficiaryModel profile) => state = state.copyWith(
      beneficiaryId: profile.id, addressId: profile.defaultAddressId);
  void forSelf(bool value) {
    state = state.copyWith(forSelf: value);
    state = state.copyWith(addressId: _recipient?.defaultAddressId);
  }

  void selectLink(BeneficiaryModel profile) {
    ref.read(selfRecipientProvider.notifier).selectLink(profile);
    state = state.copyWith(
        selfDateValid: true, addressId: profile.defaultAddressId);
  }

  void setDateValidity(bool value) =>
      state = state.copyWith(selfDateValid: value);
  void selectDate(DateTime date) =>
      state = state.copyWith(date: date, startMinutes: null, caregiverId: null);
  void selectTime(int minutes) {
    if (state.date == null) return;
    final snapped = ScheduleRules.snap(state.date!, minutes);
    state = state.copyWith(
        date: DateTime(snapped.year, snapped.month, snapped.day),
        startMinutes: snapped.hour * 60 + snapped.minute,
        caregiverId: null);
  }

  void setDuration(int value) => state = state.copyWith(
      duration: value.clamp(minimumDurationHours, maximumDurationHours),
      caregiverId: null);
  void selectAddress(String id) =>
      state = state.copyWith(addressId: id, caregiverId: null);
  void selectCaregiver(String? id) =>
      state = state.copyWith(caregiverId: id, systemMatched: id == null);
  void setSystemMatched(bool value) => state = state.copyWith(
      systemMatched: value, caregiverId: value ? null : state.caregiverId);
  void setConsent(bool value) => state = state.copyWith(consent: value);
  void previous() {
    if (!state.submitting && !state.uncertain && state.step > 0) {
      state = state.copyWith(step: state.step - 1);
    }
  }

  void next() {
    if (state.submitting || state.uncertain || !canContinue) return;
    state = state.copyWith(
        step: (state.step + 1).clamp(0, 5),
        addressId: state.addressId ?? _recipient?.defaultAddressId);
  }

  void chooseCaregiverAgain() =>
      state = state.copyWith(step: 3, caregiverId: null);
  ServiceModel? get _service => ref
      .read(serviceStoreProvider)
      .valueOrNull
      ?.where((s) => s.id == state.serviceId)
      .firstOrNull;
  BeneficiaryModel? get _recipient => state.forSelf
      ? ref.read(selfRecipientProvider).valueOrNull?.profile
      : ref
          .read(bookingRecipientsProvider)
          .valueOrNull
          ?.where((b) => b.id == state.beneficiaryId && !b.isSelf)
          .firstOrNull;
  CaregiverModel? get _caregiver => ref
      .read(caregiverStoreProvider)
      .valueOrNull
      ?.where((c) => c.id == state.caregiverId)
      .firstOrNull;
  bool get canContinue {
    final recipient = state.forSelf
        ? state.selfDateValid &&
            (ref.read(selfRecipientProvider).valueOrNull?.isComplete ?? false)
        : _recipient != null;
    final schedule =
        ScheduleRules.isValid(state.date, state.startMinutes, DateTime.now());
    final address = ref
            .read(addressStoreProvider)
            .valueOrNull
            ?.any((a) => a.id == state.addressId && a.isVerified) ??
        false;
    return BookingStepRules.canContinue(
        step: state.step,
        service: _service != null,
        recipient: recipient,
        schedule: schedule,
        address: address,
        caregiver: state.systemMatched || _caregiver != null,
        consent: state.consent);
  }

  bool get hasChanges =>
      state.forSelf ||
      state.serviceId != arg.serviceId ||
      state.beneficiaryId != arg.beneficiaryId ||
      state.caregiverId != null ||
      state.date != null ||
      state.startMinutes != null ||
      state.addressId != null ||
      state.duration != 2 ||
      state.consent ||
      !state.systemMatched;

  Future<BookingSubmitResult> submit() async {
    if (_disposed || state.submitting || state.uncertain) {
      return const BookingSubmitIgnored();
    }
    if (state.step != 5 ||
        !canContinue ||
        ref.read(authStateProvider).valueOrNull?.userId == null) {
      return const BookingSubmitMessage(
          'Vui lòng điền đầy đủ thông tin trước khi xác nhận.');
    }
    final generation = _generation;
    final snapshot = state;
    final recipient = _recipient!;
    final serviceId = _service!.id;
    final caregiverId = _caregiver?.id;
    state = state.copyWith(submitting: true);
    try {
      final outcome = await _submission.submit(snapshot,
          recipient: recipient,
          serviceId: serviceId,
          caregiverId: caregiverId,
          current: () => _current(generation),
          progress: (label) {
            if (_current(generation)) {
              state = state.copyWith(submitLabel: label);
            }
          });
      if (!_current(generation)) return const BookingSubmitIgnored();
      if (outcome.reviewRecipient) state = state.copyWith(step: 1);
      if (outcome.reloadSelf) ref.read(selfRecipientProvider.notifier).load();
      if (outcome.uncertainDraft != null) {
        state = state.copyWith(uncertainDraft: outcome.uncertainDraft);
      }
      return outcome.result;
    } finally {
      if (_current(generation)) state = state.copyWith(submitting: false);
    }
  }

  Future<BookingSubmitResult> reconcile() async {
    final draft = state.uncertainDraft;
    if (_disposed || draft == null || state.submitting) {
      return const BookingSubmitIgnored();
    }
    final generation = _generation;
    state = state.copyWith(submitting: true);
    try {
      return await _reconciliation.reconcile(draft,
          current: () => _current(generation));
    } finally {
      if (_current(generation)) state = state.copyWith(submitting: false);
    }
  }
}
