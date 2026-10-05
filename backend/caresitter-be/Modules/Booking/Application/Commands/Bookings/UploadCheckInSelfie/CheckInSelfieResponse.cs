namespace CareSitter.Modules.Booking.Application;

public sealed record CheckInSelfieResponse(Guid MediaId, string Url, DateTimeOffset UploadedAt);
