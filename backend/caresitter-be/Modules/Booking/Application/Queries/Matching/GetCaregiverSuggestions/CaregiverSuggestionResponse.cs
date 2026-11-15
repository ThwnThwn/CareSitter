namespace CareSitter.Modules.Booking.Application;

public sealed record CaregiverSuggestionResponse(
    Guid CaregiverId,
    string? DisplayName,
    int Rank,
    decimal Score,
    int? DistanceMeters,
    decimal? TravelTimeMinutes,
    IReadOnlyDictionary<string, decimal> ScoreBreakdown,
    int? YearsOfExperience = null, decimal RatingAverage = 0, int RatingCount = 0,
    string? AvailabilityStatus = null, IReadOnlyList<string>? MatchReasons = null);
