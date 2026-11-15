using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Booking.Application;

public sealed record TimelineEventResponse(
    Guid Id, Guid BookingId, Guid? CaregiverId, Guid? TaskId, string EventType,
    string? Title, string? Note, double? Latitude, double? Longitude,
    double? DistanceToAddressMeters, DateTimeOffset RecordedAt, string Source);
