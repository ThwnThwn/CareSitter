import '../../data/repositories/booking_repository.dart' show BookingDraft;

typedef BookingWizardArgs = ({String? serviceId, String? beneficiaryId});
const _unchanged = Object();

class BookingWizardState {
  const BookingWizardState(
      {this.step = 0,
      this.forSelf = false,
      this.selfDateValid = true,
      this.serviceId,
      this.beneficiaryId,
      this.caregiverId,
      this.addressId,
      this.date,
      this.startMinutes,
      this.duration = 2,
      this.consent = false,
      this.systemMatched = true,
      this.submitting = false,
      this.uncertainDraft,
      this.initialResolved = false,
      this.submitLabel = 'Đang đặt lịch…'});
  final int step, duration;
  final bool forSelf,
      selfDateValid,
      consent,
      systemMatched,
      submitting,
      initialResolved;
  final String? serviceId, beneficiaryId, caregiverId, addressId;
  final DateTime? date;
  final int? startMinutes;
  final BookingDraft? uncertainDraft;
  final String submitLabel;
  bool get uncertain => uncertainDraft != null;
  BookingWizardState copyWith(
          {int? step,
          int? duration,
          bool? forSelf,
          bool? selfDateValid,
          bool? consent,
          bool? systemMatched,
          bool? submitting,
          bool? initialResolved,
          String? submitLabel,
          Object? serviceId = _unchanged,
          Object? beneficiaryId = _unchanged,
          Object? caregiverId = _unchanged,
          Object? addressId = _unchanged,
          Object? date = _unchanged,
          Object? startMinutes = _unchanged,
          Object? uncertainDraft = _unchanged}) =>
      BookingWizardState(
          step: step ?? this.step,
          duration: duration ?? this.duration,
          forSelf: forSelf ?? this.forSelf,
          selfDateValid: selfDateValid ?? this.selfDateValid,
          consent: consent ?? this.consent,
          systemMatched: systemMatched ?? this.systemMatched,
          submitting: submitting ?? this.submitting,
          initialResolved: initialResolved ?? this.initialResolved,
          submitLabel: submitLabel ?? this.submitLabel,
          serviceId: identical(serviceId, _unchanged)
              ? this.serviceId
              : serviceId as String?,
          beneficiaryId: identical(beneficiaryId, _unchanged)
              ? this.beneficiaryId
              : beneficiaryId as String?,
          caregiverId: identical(caregiverId, _unchanged)
              ? this.caregiverId
              : caregiverId as String?,
          addressId: identical(addressId, _unchanged)
              ? this.addressId
              : addressId as String?,
          date: identical(date, _unchanged) ? this.date : date as DateTime?,
          startMinutes: identical(startMinutes, _unchanged)
              ? this.startMinutes
              : startMinutes as int?,
          uncertainDraft: identical(uncertainDraft, _unchanged)
              ? this.uncertainDraft
              : uncertainDraft as BookingDraft?);
}
