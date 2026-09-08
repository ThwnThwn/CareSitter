using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Codec chuyển đổi BookingStatus enum ↔ string cho DB và API.
///
/// Quy ước:
///   - DB (PostgreSQL constraint): UPPER_SNAKE → "CHECKOUT_PENDING_REVIEW"
///   - API response (FE contract): lower_snake → "checkout_pending_review"
///   - FromDatabase(): accept cả UPPER và lower (tương thích dữ liệu cũ/mới)
/// </summary>
internal static class BookingStatusCodec
{
    /// <summary>
    /// Chuyển enum → UPPER_SNAKE_CASE string cho DB storage.
    /// Phải khớp với CHECK constraint trong 04-booking.sql.
    /// </summary>
    public static string ToDatabase(BookingStatus value) => value switch
    {
        BookingStatus.Draft                 => "DRAFT",
        BookingStatus.PendingPayment        => "PENDING_PAYMENT",
        BookingStatus.Confirmed             => "CONFIRMED",
        BookingStatus.CaregiverAccepted     => "CAREGIVER_ACCEPTED",
        BookingStatus.CaregiverEnRoute      => "CAREGIVER_EN_ROUTE",
        BookingStatus.InProgress            => "IN_PROGRESS",
        BookingStatus.CheckoutPendingReview => "CHECKOUT_PENDING_REVIEW",
        BookingStatus.Completed             => "COMPLETED",
        BookingStatus.Crisis                => "CRISIS",
        BookingStatus.Cancelled             => "CANCELLED",
        BookingStatus.Disputed              => "DISPUTED",
        BookingStatus.Refunded              => "REFUNDED",
        _                                   => value.ToString().ToUpperInvariant()
    };

    /// <summary>
    /// Chuyển enum → lower_snake_case string cho API response (FE contract).
    /// FE luôn nhận lower_snake_case.
    /// </summary>
    public static string ToApi(BookingStatus value) => value switch
    {
        BookingStatus.Draft                 => "draft",
        BookingStatus.PendingPayment        => "pending_payment",
        BookingStatus.Confirmed             => "confirmed",
        BookingStatus.CaregiverAccepted     => "caregiver_accepted",
        BookingStatus.CaregiverEnRoute      => "caregiver_en_route",
        BookingStatus.InProgress            => "in_progress",
        BookingStatus.CheckoutPendingReview => "checkout_pending_review",
        BookingStatus.Completed             => "completed",
        BookingStatus.Crisis                => "crisis",
        BookingStatus.Cancelled             => "cancelled",
        BookingStatus.Disputed              => "disputed",
        BookingStatus.Refunded              => "refunded",
        _                                   => value.ToString().ToLowerInvariant()
    };

    /// <summary>
    /// Parse từ chuỗi DB hoặc API (hỗ trợ cả UPPER_SNAKE legacy và lower_snake mới).
    /// Dùng .ToLowerInvariant() trước khi match nên tương thích cả hai.
    /// </summary>
    public static BookingStatus FromDatabase(string value) => value.ToLowerInvariant() switch
    {
        "draft"                   => BookingStatus.Draft,
        "pending_payment"         => BookingStatus.PendingPayment,
        "confirmed"               => BookingStatus.Confirmed,
        "caregiver_accepted"      => BookingStatus.CaregiverAccepted,
        "caregiver_en_route"      => BookingStatus.CaregiverEnRoute,
        "in_progress"             => BookingStatus.InProgress,
        "checkout_pending_review" => BookingStatus.CheckoutPendingReview,
        "completed"               => BookingStatus.Completed,
        "crisis"                  => BookingStatus.Crisis,
        "cancelled"               => BookingStatus.Cancelled,
        "disputed"                => BookingStatus.Disputed,
        "refunded"                => BookingStatus.Refunded,
        _                         => Enum.Parse<BookingStatus>(value, true)
    };
}
