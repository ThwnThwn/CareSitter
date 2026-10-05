using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record CareTaskResponse(
    Guid Id, Guid BookingId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, string Status,
    DateTimeOffset? CompletedAt, string[] PhotoUrls, string Source,
    string? SkipReason, Guid? CompletedBy, DateTimeOffset CreatedAt);
