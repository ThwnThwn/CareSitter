namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Tracks one caregiver's response to a booking offer.
/// </summary>
public sealed class BookingAssignment
{
    private BookingAssignment() { } // EF

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid CaregiverId { get; private set; }
    public string AssignmentType { get; private set; } = "PRIMARY";
    public string Status { get; private set; } = "OFFERED";
    public int? Rank { get; private set; }
    public int? DistanceMeters { get; private set; }
    public decimal? Score { get; private set; }
    public string? ScoreBreakdown { get; private set; }
    public DateTimeOffset OfferedAt { get; private set; }
    public DateTimeOffset? RespondedAt { get; private set; }
    public DateTimeOffset? ExpiresAt { get; private set; }

    public static BookingAssignment CreateRejected(Guid bookingId, Guid caregiverId)
    {
        return new BookingAssignment
        {
            Id = Guid.NewGuid(),
            BookingId = bookingId,
            CaregiverId = caregiverId,
            Status = "REJECTED",
            RespondedAt = DateTimeOffset.UtcNow,
            OfferedAt = DateTimeOffset.UtcNow
        };
    }

    public static BookingAssignment CreateOffered(Guid bookingId, Guid caregiverId,
        int rank, int? distanceMeters, decimal score, string scoreBreakdown,
        DateTimeOffset offeredAt, DateTimeOffset expiresAt)
    {
        return new BookingAssignment
        {
            Id = Guid.NewGuid(),
            BookingId = bookingId,
            CaregiverId = caregiverId,
            Status = "OFFERED",
            Rank = rank,
            DistanceMeters = distanceMeters,
            Score = score,
            ScoreBreakdown = scoreBreakdown,
            OfferedAt = offeredAt,
            ExpiresAt = expiresAt
        };
    }

    public void MarkExpired()
    {
        if (Status == "OFFERED")
            Status = "EXPIRED";
    }

    public void Accept()
    {
        Status = "ACCEPTED";
        RespondedAt = DateTimeOffset.UtcNow;
    }

    public void Cancel()
    {
        if (Status == "OFFERED")
            Status = "CANCELLED";
    }

    public void Reject()
    {
        Status = "REJECTED";
        RespondedAt = DateTimeOffset.UtcNow;
    }
}
