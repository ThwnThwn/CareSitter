using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application.Commands;

internal static class BookingErrors
{
    public const string UnauthenticatedCode = "booking.unauthenticated";
    public const string NotFoundCode = "booking.not_found";
    public const string ForbiddenCode = "booking.forbidden";
    public const string ScheduleMustBeFutureCode = "booking.schedule.must_be_future";
    public const string BeneficiaryScheduleConflictCode = "booking.beneficiary.schedule_conflict";
    public const string CaregiverScheduleConflictCode = "booking.caregiver.schedule_conflict";
    public const string CaregiverNewScheduleConflictCode = "booking.caregiver.new_schedule_conflict";
    public const string CaregiverNotSuggestedCode = "booking.caregiver.not_suggested";
    public const string CaregiverSlotHeldCode = "booking.caregiver.slot_held";
    public const string OfferNotValidCode = "booking.offer.not_valid";
    public const string CaregiverNotEligibleCode = "booking.caregiver.not_eligible";
    public const string AlreadyAcceptedCode = "booking.already_accepted";
    public const string NotAwaitingAcceptanceCode = "booking.not_awaiting_acceptance";
    public const string DeclineReasonTooLongCode = "booking.decline.reason_too_long";
    public const string NotOpenForDeclineCode = "booking.decline.not_open";
    public const string CaregiverMissingCode = "booking.caregiver.missing";
    public const string InvalidGpsCode = "booking.checkin.invalid_gps";
    public const string InvalidGpsAccuracyCode = "booking.checkin.invalid_accuracy";
    public const string AddressLocationMissingCode = "booking.checkin.address_location_missing";
    public const string SelfieRequiredCode = "booking.checkin.selfie_required";
    public const string SelfieTooLargeCode = "booking.checkin.selfie_too_large";
    public const string SelfieInvalidTypeCode = "booking.checkin.selfie_invalid_type";
    public const string SelfieInvalidStateCode = "booking.checkin.selfie_invalid_state";
    public const string PendingTasksCode = "booking.checkout.pending_tasks";
    public const string CompleteInvalidStateCode = "booking.complete.invalid_state";
    public const string OpenDisputeCode = "booking.complete.open_dispute";
    public const string GpsTrackingDisabledCode = "booking.gps_tracking.disabled";
    public const string InvalidStatusCode = "booking.status.invalid";

    public static Error Unauthenticated() =>
        Error.Unauthorized(UnauthenticatedCode, string.Empty);

    public static Error NotFound() => Error.NotFound(NotFoundCode, string.Empty);
    public static Error Forbidden() => Error.Forbidden(ForbiddenCode, string.Empty);

    public static Error ScheduleMustBeFuture() =>
        Error.Validation(ScheduleMustBeFutureCode, "Lịch mới phải ở tương lai.");

    public static Error BeneficiaryScheduleConflict() =>
        Error.Conflict(BeneficiaryScheduleConflictCode,
            "Người được chăm sóc đã có lịch trùng trong khung giờ này.");

    public static Error CaregiverScheduleConflict() =>
        Error.Conflict(CaregiverScheduleConflictCode,
            "Caregiver đã có ca chăm sóc trong khung giờ này.");

    public static Error CaregiverNewScheduleConflict() =>
        Error.Conflict(CaregiverNewScheduleConflictCode,
            "Caregiver đã có ca chăm sóc trong khung giờ mới.");

    public static Error CaregiverNotSuggested() =>
        Error.Conflict(CaregiverNotSuggestedCode,
            "Caregiver không nằm trong danh sách gợi ý phù hợp của ca này.");

    public static Error CaregiverSlotHeld() =>
        Error.Conflict(CaregiverSlotHeldCode,
            "Caregiver đã được giữ chỗ cho booking khác trong cùng khung giờ.");

    public static Error OfferNotValid() =>
        Error.Conflict(OfferNotValidCode, "Ca này không còn offer hợp lệ cho caregiver này.");

    public static Error CaregiverNotEligible() =>
        Error.Conflict(CaregiverNotEligibleCode,
            "Caregiver không nằm trong tập phù hợp của ca này.");

    public static Error AlreadyAccepted() =>
        Error.Conflict(AlreadyAcceptedCode, "Ca này vừa được nhận bởi người chăm sóc khác.");

    public static Error NotAwaitingAcceptance() =>
        Error.Conflict(NotAwaitingAcceptanceCode, "Ca này không còn ở trạng thái chờ nhận.");

    public static Error NotOpenForDecline() =>
        Error.Conflict(NotOpenForDeclineCode, "Ca này không còn mở để từ chối.");

    public static Error CaregiverMissing() =>
        Error.Validation(CaregiverMissingCode, "Booking chưa có caregiver.");

    public static Error AddressLocationMissing() =>
        Error.Validation(AddressLocationMissingCode, "Không tìm thấy tọa độ địa chỉ.");

    public static Error SelfieInvalidState() =>
        Error.Conflict(SelfieInvalidStateCode,
            "Chỉ có thể gửi selfie khi đang di chuyển đến ca chăm sóc.");

    public static Error PendingTasks() =>
        Error.Conflict(PendingTasksCode,
            "Cần hoàn thành hoặc bỏ qua có lý do tất cả công việc trước khi yêu cầu checkout.");

    public static Error CompleteInvalidState() =>
        Error.Conflict(CompleteInvalidStateCode,
            "Chỉ có thể hoàn tất ca từ trạng thái checkout_pending_review.");

    public static Error OpenDispute() =>
        Error.Conflict(OpenDisputeCode,
            "Booking đang có dispute mở, không thể giải ngân tự động.");

    public static Error GpsTrackingDisabled() =>
        Error.Failure(GpsTrackingDisabledCode,
            "Chia sẻ vị trí đang đến hiện chưa được bật. Bạn vẫn có thể xem trạng thái ca và check-in.");

    public static Error InvalidStatus() =>
        Error.Validation(InvalidStatusCode, "Trạng thái booking không hợp lệ.");
}
