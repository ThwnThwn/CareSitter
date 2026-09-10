namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Ghi nhận mỗi lần một booking của customer thay đổi trạng thái.
/// cursor (IDENTITY) tăng đơn điệu toàn bảng — dùng làm mốc delta sync.
/// booking_version là snapshot SyncVersion tại thời điểm event.
/// </summary>
public sealed class BookingSyncEvent
{
    private BookingSyncEvent() { } // EF

    public BookingSyncEvent(
        Guid customerId,
        Guid bookingId,
        long bookingVersion,
        string eventType)
    {
        CustomerId     = customerId;
        BookingId      = bookingId;
        BookingVersion = bookingVersion;
        EventType      = eventType;
        OccurredAt     = DateTimeOffset.UtcNow;
    }

    /// <summary>IDENTITY PK — gán bởi database, không set từ code.</summary>
    public long Cursor { get; private set; }

    public Guid    CustomerId     { get; private set; }
    public Guid    BookingId      { get; private set; }
    public long    BookingVersion { get; private set; }
    public string  EventType      { get; private set; } = default!;
    public DateTimeOffset OccurredAt { get; private set; }
}

/// <summary>Các loại event được ghi vào booking_sync_events.</summary>
public static class BookingSyncEventTypes
{
    public const string Created            = "CREATED";
    public const string PaymentConfirmed   = "PAYMENT_CONFIRMED";
    public const string CaregiverSelected  = "CAREGIVER_SELECTED";
    public const string CaregiverAccepted  = "CAREGIVER_ACCEPTED";
    public const string CaregiverEnRoute   = "CAREGIVER_EN_ROUTE";
    public const string CheckedIn          = "CHECKED_IN";
    public const string CheckoutRequested  = "CHECKOUT_REQUESTED";
    public const string Completed          = "COMPLETED";
    public const string Cancelled          = "CANCELLED";
    public const string Rescheduled        = "RESCHEDULED";
    public const string CrisisRaised       = "CRISIS_RAISED";
    public const string Disputed           = "DISPUTED";
    public const string MatchingFailed     = "MATCHING_FAILED";
}
