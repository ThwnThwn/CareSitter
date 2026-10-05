using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application.Sync;

public sealed record BookingSyncDeltaResult(
    IReadOnlyList<BookingSyncEvent> Events,
    long NextCursor,
    bool HasMore,
    bool ResetRequired)
{
    public static BookingSyncDeltaResult Reset() => new([], 0, false, true);
}
