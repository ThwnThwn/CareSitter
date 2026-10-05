using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application.Commands;

internal static class SupportErrors
{
    public const string UnauthenticatedCode = "support.unauthenticated";
    public const string NotFoundCode = "support.not_found";
    public const string ForbiddenCode = "support.forbidden";
    public const string DisputeAlreadyExistsCode = "support.dispute.already_exists";
    public const string DisputeBookingNotFoundCode = "support.dispute.booking_not_found";
    public const string DisputeInvalidStateCode = "support.dispute.invalid_state";
    public const string DisputeWindowExpiredCode = "support.dispute.window_expired";
    public const string DisputeCaregiverMissingCode = "support.dispute.caregiver_missing";
    public const string ReviewRequiredIdsCode = "support.review.required_ids";
    public const string ReviewCommentTooLongCode = "support.review.comment_too_long";
    public const string ReviewTagsTooLongCode = "support.review.tags_too_long";
    public const string ReviewBookingNotFoundCode = "support.review.booking_not_found";
    public const string ReviewBookingNotCompletedCode = "support.review.booking_not_completed";
    public const string ReviewCaregiverMismatchCode = "support.review.caregiver_mismatch";
    public const string ReviewAlreadyExistsCode = "support.review.already_exists";
    public const string ReviewConcurrentDuplicateCode = "support.review.concurrent_duplicate";
    public const string InvalidAttachmentsCode = "support.ticket.invalid_attachments";

    public static Error Unauthenticated() =>
        Error.Unauthorized(UnauthenticatedCode, string.Empty);
    public static Error NotFound() => Error.NotFound(NotFoundCode, string.Empty);
    public static Error Forbidden() => Error.Forbidden(ForbiddenCode, string.Empty);
    public static Error DisputeAlreadyExists() => Error.Conflict(
        DisputeAlreadyExistsCode, "Booking nay da co dispute.");
    public static Error DisputeBookingNotFound() => Error.NotFound(
        DisputeBookingNotFoundCode, "Không tìm thấy booking.");
    public static Error DisputeInvalidState() => Error.Conflict(
        DisputeInvalidStateCode,
        "Booking không ở trạng thái cho phép mở hoặc xử lý khiếu nại.");
    public static Error DisputeWindowExpired() => Error.Conflict(
        DisputeWindowExpiredCode, "Booking đã hết thời hạn khiếu nại.");
    public static Error DisputeCaregiverMissing() => Error.Conflict(
        DisputeCaregiverMissingCode, "Booking chưa có caregiver để xử lý tài chính.");
    public static Error ReviewBookingNotFound() => Error.NotFound(
        ReviewBookingNotFoundCode, "Không tìm thấy booking.");
    public static Error ReviewBookingNotCompleted() => Error.Conflict(
        ReviewBookingNotCompletedCode,
        "Chỉ có thể đánh giá sau khi ca chăm sóc hoàn tất.");
    public static Error ReviewCaregiverMismatch() => Error.Validation(
        ReviewCaregiverMismatchCode, "Caregiver không khớp với booking này.");
    public static Error ReviewAlreadyExists() => Error.Conflict(
        ReviewAlreadyExistsCode, "Booking nay da co review.");
    public static Error ReviewConcurrentDuplicate() => Error.Conflict(
        ReviewConcurrentDuplicateCode, "Booking này đã có review.");
}
