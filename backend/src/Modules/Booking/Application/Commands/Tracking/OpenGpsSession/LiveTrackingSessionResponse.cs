namespace CareSitter.Modules.Booking.Application;

public sealed record LiveTrackingSessionResponse(
    Guid SessionId, long Version, DateTimeOffset LeaseUntil,
    int SendIntervalSeconds, DateTimeOffset ServerTime);
