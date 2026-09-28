namespace CareSitter.Contracts.Services;

/// <summary>
/// Chay hard filter + soft ranking cho mot booking va quan ly vong doi offer.
/// Contract dat o Shared de Booking va ApiHost khong phu thu truc tiep vao People/Catalog.
/// </summary>
public interface IMatchingService
{
    Task<IReadOnlyList<MatchingCandidate>> GetEligibleCaregiversAsync(
        Guid bookingId, CancellationToken ct = default);

    Task<IReadOnlyList<MatchingCandidate>> GetSuggestedCaregiversAsync(
        Guid bookingId, CancellationToken ct = default);

    Task<IReadOnlyList<Guid>> GetOpenBookingIdsForCaregiverAsync(
        Guid caregiverId, CancellationToken ct = default);

    Task<IReadOnlyList<MatchingCandidate>> OfferTopCandidatesAsync(
        Guid bookingId, CancellationToken ct = default);

    Task<int> ExpandExpiredOffersAsync(
        CancellationToken ct = default);
}

public sealed record MatchingCandidate(
    Guid CaregiverId,
    int Rank,
    decimal Score,
    int? DistanceMeters,
    IReadOnlyDictionary<string, decimal> ScoreBreakdown);

/// <summary>People-owned read boundary used by the Booking matching policy.</summary>
public interface IMatchingCaregiverReader
{
    Task<IReadOnlyList<MatchingCaregiverProfile>> ListAvailableAsync(
        CancellationToken ct = default);
}

/// <summary>Catalog-owned read boundary used by the Booking matching policy.</summary>
public interface IMatchingAddressReader
{
    Task<MatchingAddress?> GetAsync(Guid addressId, CancellationToken ct = default);
}

public sealed record MatchingCaregiverProfile(
    Guid Id,
    string KycStatus,
    string AvailabilityStatus,
    string? Skills,
    string? ServiceCity,
    string? ServiceDistrict,
    Routing.GeoPoint? ServiceCenter,
    int? ServiceRadiusMeters,
    decimal RatingAverage,
    int RatingCount,
    int? YearsOfExperience,
    DateTimeOffset? DeletedAt);

public sealed record MatchingAddress(
    string? District,
    string? City,
    Routing.GeoPoint? Location);
