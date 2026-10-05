namespace CareSitter.Modules.Support.Application;

public sealed record ReviewResponse(Guid Id, Guid BookingId, Guid CaregiverId,
    Guid CustomerId, int Rating, string? Comment, string? ExperienceTags,
    DateTimeOffset CreatedAt);
