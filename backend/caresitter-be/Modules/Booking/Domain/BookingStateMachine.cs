namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Bang chuyen trang thai booking (BUSINESS_FLOW §3). Thuan domain, khong phu thuoc ha tang
/// -> de unit test. Moi chuyen hop le phai nam trong bang nay.
/// </summary>
public static class BookingStateMachine
{
    private static readonly IReadOnlyDictionary<BookingStatus, BookingStatus[]> Transitions =
        new Dictionary<BookingStatus, BookingStatus[]>
        {
            [BookingStatus.Draft] = new[] { BookingStatus.PendingPayment, BookingStatus.Cancelled },
            [BookingStatus.PendingPayment] = new[] { BookingStatus.Confirmed, BookingStatus.Cancelled },
            [BookingStatus.Confirmed] = new[] { BookingStatus.CaregiverAccepted, BookingStatus.Cancelled },
            [BookingStatus.CaregiverAccepted] = new[] { BookingStatus.CaregiverEnRoute, BookingStatus.Cancelled },
            [BookingStatus.CaregiverEnRoute] = new[] { BookingStatus.InProgress, BookingStatus.Cancelled },
            [BookingStatus.InProgress] = new[]
            {
                BookingStatus.Completed,
                BookingStatus.CheckoutPendingReview,
                BookingStatus.Crisis
            },
            [BookingStatus.CheckoutPendingReview] = new[] { BookingStatus.Completed, BookingStatus.Disputed },
            [BookingStatus.Completed] = new[] { BookingStatus.Disputed },
            [BookingStatus.Crisis] = new[]
            {
                BookingStatus.InProgress,
                BookingStatus.Completed,
                BookingStatus.Cancelled
            },
            [BookingStatus.Disputed] = new[] { BookingStatus.Completed, BookingStatus.Refunded },
            [BookingStatus.Cancelled] = new[] { BookingStatus.Refunded },
            [BookingStatus.Refunded] = Array.Empty<BookingStatus>()
        };

    public static bool CanTransition(BookingStatus from, BookingStatus to) =>
        Transitions.TryGetValue(from, out var allowed) && Array.IndexOf(allowed, to) >= 0;

    public static IReadOnlyCollection<BookingStatus> AllowedFrom(BookingStatus from) =>
        Transitions.TryGetValue(from, out var allowed) ? allowed : Array.Empty<BookingStatus>();
}
