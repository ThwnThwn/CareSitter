namespace CareSitter.Contracts.Services;

/// <summary>Booking-owned answer for optional support-ticket context.</summary>
public interface IBookingPartyAccess
{
    Task<bool> IsPartyAsync(Guid bookingId, Guid userId, CancellationToken ct = default);
}
